const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const db = getFirestore();
const messaging = getMessaging();
const HOUR_MS = 60 * 60 * 1000;
const MAX_NOTIFICATION_DEVICES_PER_USER = 12;

async function consumeFixedWindowLimit({scope, actorUid, limit, windowMs}) {
  const ref = db.collection("serverRateLimits").doc(`${scope}_${actorUid}`);
  const now = Date.now();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const storedStart = Number(data.windowStartMs || 0);
    const storedCount = Number(data.count || 0);
    const expired = !storedStart || now - storedStart >= windowMs;
    const count = expired ? 0 : storedCount;
    if (count >= limit) return false;
    transaction.set(ref, {
      scope,
      actorUid,
      windowStartMs: expired ? now : storedStart,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function userDeviceDocs(uid) {
  const snapshot = await db.collection("users")
      .doc(uid)
      .collection("devices")
      .where("notificationsEnabled", "==", true)
      .limit(MAX_NOTIFICATION_DEVICES_PER_USER)
      .get();
  return snapshot.docs;
}

async function sendTaskNotification(uid, {
  title,
  body,
  priority = "normal",
  taskId,
}) {
  const deviceDocs = await userDeviceDocs(uid);
  const eligible = deviceDocs
      .map((document) => ({document, data: document.data()}))
      .filter(({data}) =>
        data.notificationsEnabled === true &&
        Boolean(data.pushToken) &&
        data.tasksAndRoutines !== false,
      );

  for (let start = 0; start < eligible.length; start += 500) {
    const group = eligible.slice(start, start + 500);
    const tokens = group.map(({data}) => data.pushToken);
    if (tokens.length === 0) continue;

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        category: "task",
        route: "tasks",
        taskId: String(taskId),
      },
      android: {
        priority: priority === "important" ? "high" : "normal",
        notification: {
          channelId: "homi_tasks",
          icon: "homi_notification",
        },
      },
    });

    const cleanup = [];
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error && result.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        cleanup.push(group[index].document.ref.set({
          pushToken: FieldValue.delete(),
          notificationsEnabled: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}));
      }
    });
    await Promise.all(cleanup);
  }
}

function isHouseholdTask(data, householdId) {
  const audienceVersion = Number(data && data.audienceVersion);
  return Boolean(
      data &&
      data.householdId === householdId &&
      (audienceVersion === 0 || audienceVersion === 1),
  );
}

function isNewCanonicalTask(data, householdId) {
  return isHouseholdTask(data, householdId) &&
    Number(data.audienceVersion) === 1 &&
    !data.topLevelMigratedAt;
}

exports.onHouseholdSharedTaskCreated = onDocumentCreated(
    "households/{householdId}/sharedTasks/{taskId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!isNewCanonicalTask(data, event.params.householdId)) return;

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
          householdId: event.params.householdId,
        });
        return;
      }

      const recipients = assigneeUid && assigneeUid !== creatorUid ?
        [assigneeUid] : members.filter((uid) => uid !== creatorUid);

      await Promise.all([...new Set(recipients)].map((uid) =>
        sendTaskNotification(uid, {
          title: assigneeUid ?
            "A task was assigned to you" :
            "New household task",
          body: `${creatorName} added a household task.`,
          priority: "important",
          taskId: event.params.taskId,
        }),
      ));
    },
);

exports.onHouseholdSharedTaskUpdated = onDocumentUpdated(
    "households/{householdId}/sharedTasks/{taskId}",
    async (event) => {
      const before = event.data && event.data.before.data();
      const after = event.data && event.data.after.data();
      if (!before || !isHouseholdTask(after, event.params.householdId)) {
        return;
      }
      if (before.completedAt || !after.completedAt) return;

      const creatorUid = after.createdByUid;
      const completedByUid = after.completedByUid;
      if (!creatorUid || !completedByUid || creatorUid === completedByUid) {
        return;
      }

      const allowed = await consumeFixedWindowLimit({
        scope: "task_complete_push_hour",
        actorUid: completedByUid,
        limit: 120,
        windowMs: HOUR_MS,
      });
      if (!allowed) {
        logger.warn("Suppressed excessive shared-task completion notifications", {
          completedByUid,
          householdId: event.params.householdId,
        });
        return;
      }

      await sendTaskNotification(creatorUid, {
        title: "Household task completed",
        body: `${after.completedByName || "Someone at home"} completed a household task.`,
        priority: "normal",
        taskId: event.params.taskId,
      });
    },
);
