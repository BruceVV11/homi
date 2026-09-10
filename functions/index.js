const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

setGlobalOptions({
  region: "africa-south1",
  maxInstances: 5,
});

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const HEART_COOLDOWN_MS = MINUTE_MS;
const MAX_NOTIFICATION_DEVICES_PER_USER = 12;

async function consumeFixedWindowLimit({scope, actorUid, limit, windowMs}) {
  if (!actorUid) return false;
  const ref = db.collection("serverRateLimits").doc(`${scope}_${actorUid}`);
  const now = Date.now();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const storedStart = Number(data.windowStartMs || 0);
    const storedCount = Number(data.count || 0);
    const expired = !storedStart || now - storedStart >= windowMs;
    const windowStartMs = expired ? now : storedStart;
    const count = expired ? 0 : storedCount;
    if (count >= limit) return false;
    transaction.set(
        ref,
        {
          scope,
          actorUid,
          windowStartMs,
          count: count + 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
    return true;
  });
}

function channelForCategory(category) {
  switch (category) {
    case "household":
    case "supply":
    case "maintenance":
      return "homi_attention";
    case "task":
    case "routine":
      return "homi_tasks";
    case "people":
    case "heart":
    case "connection":
      return "homi_people";
    case "service":
    case "security":
      return "homi_service";
    default:
      return "homi_updates";
  }
}

function topicForCategory(category) {
  switch (category) {
    case "service":
      return "homi_service";
    case "security":
      return "homi_security";
    default:
      return "homi_updates";
  }
}

function deviceAllowsCategory(data, category) {
  if (data.notificationsEnabled !== true || !data.pushToken) return false;
  switch (category) {
    case "household":
    case "supply":
    case "maintenance":
      return data.householdAttention !== false;
    case "task":
    case "routine":
      return data.tasksAndRoutines !== false;
    case "people":
    case "heart":
    case "connection":
      return data.peopleNotifications !== false;
    case "service":
    case "security":
      return data.serviceNotices !== false;
    case "update":
    case "product":
      return data.homiUpdates === true;
    default:
      return false;
  }
}

async function userDeviceDocs(uid) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("devices")
      .where("notificationsEnabled", "==", true)
      .limit(MAX_NOTIFICATION_DEVICES_PER_USER)
      .get();
  return snapshot.docs;
}

async function sendToDeviceDocs({
  deviceDocs,
  title,
  body,
  category,
  route = "overview",
  priority = "normal",
  extraData = {},
}) {
  const eligible = deviceDocs
      .map((doc) => ({doc, data: doc.data()}))
      .filter(({data}) => deviceAllowsCategory(data, category));

  let successCount = 0;
  let failureCount = 0;

  for (let start = 0; start < eligible.length; start += 500) {
    const group = eligible.slice(start, start + 500);
    const tokens = group.map(({data}) => data.pushToken);
    if (tokens.length === 0) continue;

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        category,
        route,
        ...Object.fromEntries(
            Object.entries(extraData).map(([key, value]) => [key, String(value)]),
        ),
      },
      android: {
        priority: priority === "important" ? "high" : "normal",
        notification: {
          channelId: channelForCategory(category),
          icon: "homi_notification",
        },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    const cleanup = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error && result.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        cleanup.push(
            group[index].doc.ref.set(
                {
                  pushToken: FieldValue.delete(),
                  notificationsEnabled: false,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                {merge: true},
            ),
        );
      }
    });
    await Promise.all(cleanup);
  }

  return {successCount, failureCount, eligibleCount: eligible.length};
}

async function sendToUser(uid, payload) {
  return sendToDeviceDocs({
    deviceDocs: await userDeviceDocs(uid),
    ...payload,
  });
}

async function sendBroadcast({title, body, category, route, priority}) {
  const messageId = await messaging.send({
    topic: topicForCategory(category),
    notification: {title, body},
    data: {category, route},
    android: {
      priority: priority === "important" ? "high" : "normal",
      notification: {
        channelId: channelForCategory(category),
        icon: "homi_notification",
      },
    },
  });
  return messageId;
}

async function acceptedConnection(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  const snapshot = await db
      .collection("connections")
      .doc(`${ids[0]}_${ids[1]}`)
      .get();
  if (!snapshot.exists) return null;
  const data = snapshot.data();
  if (
    data.status !== "accepted" ||
    data.aUid !== ids[0] ||
    data.bUid !== ids[1]
  ) {
    return null;
  }
  return data;
}

async function displayNameFor(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  const name = snapshot.data() && snapshot.data().displayName;
  return typeof name === "string" && name.trim() ? name.trim() : "Someone";
}

exports.sendHeart = onCall(
    {
      enforceAppCheck: true,
      maxInstances: 3,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in to send a heart.");
      }
      const senderUid = request.auth.uid;
      const recipientUid = String(
          request.data && request.data.recipientUid || "",
      ).trim();
      if (!recipientUid || recipientUid === senderUid) {
        throw new HttpsError("invalid-argument", "Choose a connected person.");
      }

      const connection = await acceptedConnection(senderUid, recipientUid);
      if (!connection) {
        throw new HttpsError(
            "permission-denied",
            "Hearts can only be sent to an accepted trusted person.",
        );
      }

      const cooldownRef = db
          .collection("heartCooldowns")
          .doc(`${senderUid}_${recipientUid}`);
      const now = Date.now();
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(cooldownRef);
        const last = snapshot.data() && snapshot.data().sentAt;
        const lastMillis = last && typeof last.toMillis === "function" ?
          last.toMillis() : 0;
        if (lastMillis && now - lastMillis < HEART_COOLDOWN_MS) {
          throw new HttpsError(
              "resource-exhausted",
              "Give it a moment before sending another heart.",
          );
        }
        transaction.set(
            cooldownRef,
            {
              senderUid,
              recipientUid,
              sentAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
      });

      const withinDailyLimit = await consumeFixedWindowLimit({
        scope: "heart_day",
        actorUid: senderUid,
        limit: 40,
        windowMs: DAY_MS,
      });
      if (!withinDailyLimit) {
        throw new HttpsError(
            "resource-exhausted",
            "You have sent plenty of hearts today. Try again later.",
        );
      }

      const senderName = await displayNameFor(senderUid);
      const result = await sendToUser(recipientUid, {
        title: `${senderName} is thinking about you!`,
        body: "A little check-in from someone you trust on Homi.",
        category: "heart",
        route: "people",
        priority: "important",
        extraData: {senderUid},
      });

      return {
        accepted: true,
        deliveredDevices: result.successCount,
      };
    },
);

exports.onConnectionRequestCreated = onDocumentCreated(
    "connections/{connectionId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data || data.status !== "pending") return;
      const initiatorUid = data.initiatorUid;
      const recipientUid = data.recipientUid;
      if (!initiatorUid || !recipientUid) return;
      const allowed = await consumeFixedWindowLimit({
        scope: "connection_push_hour",
        actorUid: initiatorUid,
        limit: 20,
        windowMs: HOUR_MS,
      });
      if (!allowed) {
        logger.warn("Suppressed excessive connection-request notification", {
          initiatorUid,
        });
        return;
      }
      const initiatorName = data.aUid === initiatorUid ? data.aName : data.bName;
      await sendToUser(recipientUid, {
        title: "New Homi connection request",
        body: `${initiatorName || "Someone"} wants to connect with you.`,
        category: "connection",
        route: "people",
        priority: "important",
      });
    },
);

exports.onConnectionAccepted = onDocumentUpdated(
    "connections/{connectionId}",
    async (event) => {
      const before = event.data && event.data.before.data();
      const after = event.data && event.data.after.data();
      if (!before || !after) return;
      if (before.status === "accepted" || after.status !== "accepted") return;
      const initiatorUid = after.initiatorUid;
      const recipientUid = after.recipientUid;
      if (!initiatorUid || !recipientUid) return;
      const recipientName = after.aUid === recipientUid ? after.aName : after.bName;
      await sendToUser(initiatorUid, {
        title: "Homi connection accepted",
        body: `${recipientName || "Your trusted person"} accepted your connection.`,
        category: "connection",
        route: "people",
        priority: "normal",
      });
    },
);

exports.onSharedTaskCreated = onDocumentCreated(
    "sharedTasks/{taskId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;
      const creatorUid = data.createdByUid;
      const creatorName = data.createdByName || "Someone at home";
      const members = Array.isArray(data.memberUids) ? data.memberUids : [];
      const assigneeUid = data.assigneeUid;
      if (!creatorUid) return;
      const allowed = await consumeFixedWindowLimit({
        scope: "task_create_push_hour",
        actorUid: creatorUid,
        limit: 60,
        windowMs: HOUR_MS,
      });
      if (!allowed) {
        logger.warn("Suppressed excessive shared-task creation notifications", {
          creatorUid,
        });
        return;
      }
      const recipients = assigneeUid && assigneeUid !== creatorUid ?
        [assigneeUid] : members.filter((uid) => uid !== creatorUid);

      await Promise.all(
          [...new Set(recipients)].map((uid) => sendToUser(uid, {
            title: assigneeUid ? "A task was assigned to you" : "New household task",
            body: `${creatorName} added a household task.`,
            category: "task",
            route: "tasks",
            priority: "important",
            extraData: {taskId: event.params.taskId},
          })),
      );
    },
);

exports.onSharedTaskUpdated = onDocumentUpdated(
    "sharedTasks/{taskId}",
    async (event) => {
      const before = event.data && event.data.before.data();
      const after = event.data && event.data.after.data();
      if (!before || !after) return;
      if (before.completedAt || !after.completedAt) return;
      const creatorUid = after.createdByUid;
      const completedByUid = after.completedByUid;
      if (!creatorUid || !completedByUid || creatorUid === completedByUid) return;
      const allowed = await consumeFixedWindowLimit({
        scope: "task_complete_push_hour",
        actorUid: completedByUid,
        limit: 120,
        windowMs: HOUR_MS,
      });
      if (!allowed) {
        logger.warn("Suppressed excessive shared-task completion notifications", {
          completedByUid,
        });
        return;
      }
      const completedByName = after.completedByName || "Someone at home";
      await sendToUser(creatorUid, {
        title: "Household task completed",
        body: `${completedByName} completed a household task.`,
        category: "task",
        route: "tasks",
        priority: "normal",
        extraData: {taskId: event.params.taskId},
      });
    },
);

exports.onNotificationCampaignCreated = onDocumentCreated(
    "notificationCampaigns/{campaignId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const data = snapshot.data();
      const campaignRef = snapshot.ref;
      const creatorUid = data.createdByUid;

      try {
        const admin = creatorUid ?
          await db.collection("developerAdmins").doc(creatorUid).get() : null;
        if (!admin || !admin.exists || admin.data().active !== true) {
          throw new Error("Campaign creator is not an active developer admin.");
        }

        const allowedCategories = new Set(["update", "service", "security"]);
        const allowedRoutes = new Set([
          "overview",
          "tasks",
          "routines",
          "home",
          "supplies",
          "people",
          "account",
        ]);
        const category = allowedCategories.has(data.category) ?
          data.category : "update";
        const route = allowedRoutes.has(data.route) ? data.route : "overview";
        const audience = data.audience === "self" ? "self" : "all";
        const priority = data.priority === "important" ? "important" : "normal";
        const title = String(data.title || "").trim();
        const body = String(data.body || "").trim();
        if (!title || !body || title.length > 80 || body.length > 280) {
          throw new Error("Campaign title/body did not pass validation.");
        }

        const withinHourlyLimit = await consumeFixedWindowLimit({
          scope: audience === "all" ? "developer_broadcast_hour" : "developer_self_hour",
          actorUid: creatorUid,
          limit: audience === "all" ? 6 : 30,
          windowMs: HOUR_MS,
        });
        if (!withinHourlyLimit) {
          throw new Error("Developer notification hourly rate limit reached.");
        }
        if (audience === "all") {
          const withinDailyLimit = await consumeFixedWindowLimit({
            scope: "developer_broadcast_day",
            actorUid: creatorUid,
            limit: 20,
            windowMs: DAY_MS,
          });
          if (!withinDailyLimit) {
            throw new Error("Developer broadcast daily rate limit reached.");
          }
        }

        await campaignRef.set(
            {status: "sending", startedAt: FieldValue.serverTimestamp()},
            {merge: true},
        );

        if (audience === "self") {
          const result = await sendToUser(creatorUid, {
            title,
            body,
            category,
            route,
            priority,
            extraData: {campaignId: event.params.campaignId},
          });
          await campaignRef.set(
              {
                status: "sent",
                deliveryMode: "direct",
                sentAt: FieldValue.serverTimestamp(),
                eligibleCount: result.eligibleCount,
                sentCount: result.successCount,
                failureCount: result.failureCount,
              },
              {merge: true},
          );
        } else {
          const messageId = await sendBroadcast({
            title,
            body,
            category,
            route,
            priority,
          });
          await campaignRef.set(
              {
                status: "sent",
                deliveryMode: "topic",
                sentAt: FieldValue.serverTimestamp(),
                fcmMessageId: messageId,
              },
              {merge: true},
          );
        }
      } catch (error) {
        logger.error("Homi notification campaign failed", error);
        await campaignRef.set(
            {
              status: "failed",
              failedAt: FieldValue.serverTimestamp(),
              errorCode: "delivery-failed",
            },
            {merge: true},
        );
      }
    },
);

// Account deletion removes server-only notification metadata that the client
// cannot read/write by design. The user's device subcollection is removed by
// the account deletion service before the user document is deleted.
exports.onHomiUserDocumentDeleted = onDocumentDeleted(
    "users/{uid}",
    async (event) => {
      const uid = event.params.uid;
      const [sentHearts, receivedHearts, campaigns, rateLimits, developerAdmin] =
        await Promise.all([
          db.collection("heartCooldowns").where("senderUid", "==", uid).get(),
          db.collection("heartCooldowns").where("recipientUid", "==", uid).get(),
          db.collection("notificationCampaigns")
              .where("createdByUid", "==", uid).get(),
          db.collection("serverRateLimits").where("actorUid", "==", uid).get(),
          db.collection("developerAdmins").doc(uid).get(),
        ]);

      const refs = new Map();
      sentHearts.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
      receivedHearts.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
      campaigns.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
      rateLimits.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
      if (developerAdmin.exists) {
        refs.set(developerAdmin.ref.path, developerAdmin.ref);
      }

      const documents = [...refs.values()];
      for (let start = 0; start < documents.length; start += 450) {
        const batch = db.batch();
        documents.slice(start, start + 450).forEach((ref) => batch.delete(ref));
        await batch.commit();
      }
    },
);
