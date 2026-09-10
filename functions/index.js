const {randomInt} = require("node:crypto");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

setGlobalOptions({
  region: "africa-south1",
  maxInstances: 5,
  minInstances: 0,
  memory: "256MiB",
  timeoutSeconds: 60,
  serviceAccount: "homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com",
});

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;
const HEART_COOLDOWN_MS = MINUTE_MS;
const MAX_NOTIFICATION_DEVICES_PER_USER = 12;
const MAX_CONNECTIONS_PER_USER = 30;
const MAX_HOUSEHOLD_MEMBERS_PER_TASK = 20;
const COMPLETED_TASK_RETENTION_MS = 48 * HOUR_MS;
const RECENT_AUTH_MAX_AGE_SECONDS = 15 * 60;
const HOMI_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const HOMI_CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;

function requireAuthenticated(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return request.auth;
}

function requireVerifiedCloudAccount(request) {
  const auth = requireAuthenticated(request);
  const provider = auth.token && auth.token.firebase &&
    auth.token.firebase.sign_in_provider;
  if (provider === "password" && auth.token.email_verified !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Verify your email before using Homi sharing features.",
    );
  }
  return auth;
}

function requireRecentAuthentication(request) {
  const auth = requireAuthenticated(request);
  const authTime = Number(auth.token && auth.token.auth_time || 0);
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!authTime || nowSeconds - authTime > RECENT_AUTH_MAX_AGE_SECONDS) {
    throw new HttpsError(
        "failed-precondition",
        "Confirm your sign-in again before deleting your Homi account.",
    );
  }
  return auth;
}

function cleanRequiredString(value, maxLength, message) {
  const result = String(value || "").trim();
  if (!result || result.length > maxLength) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}

function cleanOptionalString(value, maxLength, message) {
  if (value == null) return null;
  const result = String(value).trim();
  if (!result) return null;
  if (result.length > maxLength) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}

function displayNameFromAuth(auth) {
  const token = auth.token || {};
  const named = typeof token.name === "string" ? token.name.trim() : "";
  if (named) return named.slice(0, 80);
  const email = typeof token.email === "string" ? token.email.trim() : "";
  if (email.includes("@")) return email.split("@")[0].slice(0, 80);
  return "Homi user";
}

function photoUrlFromAuth(auth) {
  const picture = auth.token && typeof auth.token.picture === "string" ?
    auth.token.picture.trim() : "";
  return picture ? picture.slice(0, 1000) : null;
}

function normalizeHomiCode(value) {
  return String(value || "").trim().toUpperCase().replace(/\s+/g, "");
}

function generateHomiCode() {
  let code = "";
  for (let index = 0; index < 6; index += 1) {
    code += HOMI_CODE_ALPHABET[randomInt(HOMI_CODE_ALPHABET.length)];
  }
  return code;
}

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

async function requireRateLimit(options, message) {
  if (!await consumeFixedWindowLimit(options)) {
    throw new HttpsError("resource-exhausted", message);
  }
}

async function claimHomiCode({uid, code, displayName, photoUrl}) {
  const codeRef = db.collection("homiCodes").doc(code);
  const userRef = db.collection("users").doc(uid);
  return db.runTransaction(async (transaction) => {
    const codeSnapshot = await transaction.get(codeRef);
    if (codeSnapshot.exists && codeSnapshot.data().uid !== uid) return false;
    transaction.set(codeRef, {
      uid,
      displayName,
      photoUrl,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(userRef, {
      homiCode: code,
      displayName,
      photoUrl,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function ensureIdentityForAuth(auth) {
  const uid = auth.uid;
  const displayName = displayNameFromAuth(auth);
  const photoUrl = photoUrlFromAuth(auth);
  const userRef = db.collection("users").doc(uid);
  const userSnapshot = await userRef.get();
  const currentCode = normalizeHomiCode(
      userSnapshot.exists && userSnapshot.data().homiCode,
  );

  if (HOMI_CODE_PATTERN.test(currentCode)) {
    if (await claimHomiCode({uid, code: currentCode, displayName, photoUrl})) {
      return {code: currentCode, uid, displayName, photoUrl};
    }
  }

  for (let attempt = 0; attempt < 16; attempt += 1) {
    const code = generateHomiCode();
    if (await claimHomiCode({uid, code, displayName, photoUrl})) {
      return {code, uid, displayName, photoUrl};
    }
  }
  throw new HttpsError(
      "unavailable",
      "Homi could not create a connection code. Try again shortly.",
  );
}

async function connectionCountFor(uid) {
  const [asA, asB] = await Promise.all([
    db.collection("connections").where("aUid", "==", uid)
        .limit(MAX_CONNECTIONS_PER_USER + 1).get(),
    db.collection("connections").where("bUid", "==", uid)
        .limit(MAX_CONNECTIONS_PER_USER + 1).get(),
  ]);
  const ids = new Set();
  asA.docs.forEach((doc) => ids.add(doc.id));
  asB.docs.forEach((doc) => ids.add(doc.id));
  return ids.size;
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

async function householdPreference(ownerUid, otherUid) {
  const snapshot = await db
      .collection("peoplePreferences")
      .doc(ownerUid)
      .collection("people")
      .doc(otherUid)
      .get();
  return snapshot.exists && snapshot.data().scope === "household";
}

async function displayNameFor(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  const name = snapshot.data() && snapshot.data().displayName;
  return typeof name === "string" && name.trim() ? name.trim() : "Someone";
}

async function canAccessSharedTask(uid, data) {
  if (!data || !Array.isArray(data.memberUids) || !data.memberUids.includes(uid)) {
    return false;
  }
  if (data.createdByUid === uid) return true;
  if (!data.createdByUid) return false;
  return Boolean(await acceptedConnection(data.createdByUid, uid)) &&
    await householdPreference(data.createdByUid, uid);
}

async function detachMemberFromCreatorTasks(creatorUid, memberUid) {
  const snapshot = await db.collection("sharedTasks")
      .where("createdByUid", "==", creatorUid).get();
  const affected = snapshot.docs.filter((document) => {
    const members = document.data().memberUids;
    return Array.isArray(members) && members.includes(memberUid);
  });

  for (let start = 0; start < affected.length; start += 400) {
    const batch = db.batch();
    affected.slice(start, start + 400).forEach((document) => {
      const data = document.data();
      const members = data.memberUids.filter((uid) => uid !== memberUid);
      const update = {
        memberUids: members,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (data.assigneeUid === memberUid) {
        update.assigneeUid = null;
        update.assigneeName = "Unassigned";
      }
      if (data.completedByUid === memberUid) {
        update.completedByUid = null;
        update.completedByName = "Former Homi user";
      }
      batch.update(document.ref, update);
    });
    await batch.commit();
  }
  return affected.length;
}

async function cleanupConnectionMetadata(firstUid, secondUid) {
  const refs = [
    db.collection("locationShares").doc(firstUid)
        .collection("viewers").doc(secondUid),
    db.collection("locationShares").doc(secondUid)
        .collection("viewers").doc(firstUid),
    db.collection("peoplePreferences").doc(firstUid)
        .collection("people").doc(secondUid),
    db.collection("peoplePreferences").doc(secondUid)
        .collection("people").doc(firstUid),
    db.collection("heartCooldowns").doc(`${firstUid}_${secondUid}`),
    db.collection("heartCooldowns").doc(`${secondUid}_${firstUid}`),
  ];
  const batch = db.batch();
  refs.forEach((ref) => batch.delete(ref));
  await batch.commit();
}

async function cleanupConnectionState(firstUid, secondUid) {
  await detachMemberFromCreatorTasks(firstUid, secondUid);
  await detachMemberFromCreatorTasks(secondUid, firstUid);
  await cleanupConnectionMetadata(firstUid, secondUid);
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
  const effectivePriority = category === "update" ? "normal" : priority;
  const messageId = await messaging.send({
    topic: topicForCategory(category),
    notification: {title, body},
    data: {category, route},
    android: {
      priority: effectivePriority === "important" ? "high" : "normal",
      notification: {
        channelId: channelForCategory(category),
        icon: "homi_notification",
      },
    },
  });
  return messageId;
}

async function isDeveloperAdmin(uid) {
  const snapshot = await db.collection("developerAdmins").doc(uid).get();
  return snapshot.exists && snapshot.data().active === true;
}

async function deleteCloudDataForUid(uid, {deleteUserDocument = true} = {}) {
  const userRef = db.collection("users").doc(uid);
  const userSnapshot = await userRef.get();
  const homiCode = normalizeHomiCode(
      userSnapshot.exists && userSnapshot.data().homiCode,
  );

  const [asA, asB, ownPreferences, ownShares, devices, sharedTasks,
    sentHearts, receivedHearts, campaigns, rateLimits, codeDocs] =
    await Promise.all([
      db.collection("connections").where("aUid", "==", uid).get(),
      db.collection("connections").where("bUid", "==", uid).get(),
      db.collection("peoplePreferences").doc(uid).collection("people").get(),
      db.collection("locationShares").doc(uid).collection("viewers").get(),
      userRef.collection("devices").get(),
      db.collection("sharedTasks").where("memberUids", "array-contains", uid).get(),
      db.collection("heartCooldowns").where("senderUid", "==", uid).get(),
      db.collection("heartCooldowns").where("recipientUid", "==", uid).get(),
      db.collection("notificationCampaigns").where("createdByUid", "==", uid).get(),
      db.collection("serverRateLimits").where("actorUid", "==", uid).get(),
      db.collection("homiCodes").where("uid", "==", uid).get(),
    ]);

  const connections = new Map();
  [...asA.docs, ...asB.docs].forEach((document) => {
    connections.set(document.id, document);
  });

  let sharedTasksRemoved = 0;
  let sharedTasksDetached = 0;
  for (const document of sharedTasks.docs) {
    const data = document.data();
    if (data.createdByUid === uid) {
      await document.ref.delete();
      sharedTasksRemoved += 1;
      continue;
    }
    const members = Array.isArray(data.memberUids) ?
      data.memberUids.filter((memberUid) => memberUid !== uid) : [];
    const update = {
      memberUids: members,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (data.assigneeUid === uid) {
      update.assigneeUid = null;
      update.assigneeName = "Unassigned";
    }
    if (data.completedByUid === uid) {
      update.completedByUid = null;
      update.completedByName = "Former Homi user";
    }
    try {
      await document.ref.update(update);
      sharedTasksDetached += 1;
    } catch (error) {
      if (!error || error.code !== 5) throw error;
    }
  }

  const refs = new Map();
  for (const connection of connections.values()) {
    const data = connection.data();
    const otherUid = data.aUid === uid ? data.bUid : data.aUid;
    if (otherUid) {
      const related = [
        db.collection("locationShares").doc(otherUid)
            .collection("viewers").doc(uid),
        db.collection("peoplePreferences").doc(otherUid)
            .collection("people").doc(uid),
      ];
      related.forEach((ref) => refs.set(ref.path, ref));
    }
    refs.set(connection.ref.path, connection.ref);
  }
  ownPreferences.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  ownShares.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  devices.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  sentHearts.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  receivedHearts.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  campaigns.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  rateLimits.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  codeDocs.docs.forEach((doc) => refs.set(doc.ref.path, doc.ref));
  refs.set(db.collection("locations").doc(uid).path,
      db.collection("locations").doc(uid));
  refs.set(db.collection("developerAdmins").doc(uid).path,
      db.collection("developerAdmins").doc(uid));
  if (HOMI_CODE_PATTERN.test(homiCode)) {
    refs.set(db.collection("homiCodes").doc(homiCode).path,
        db.collection("homiCodes").doc(homiCode));
  }
  if (deleteUserDocument) refs.set(userRef.path, userRef);

  const documents = [...refs.values()];
  for (let start = 0; start < documents.length; start += 400) {
    const batch = db.batch();
    documents.slice(start, start + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  return {
    connectionsRemoved: connections.size,
    sharedTasksRemoved,
    sharedTasksDetached,
  };
}

exports.ensureHomiIdentity = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      await requireRateLimit({
        scope: "identity_hour",
        actorUid: auth.uid,
        limit: 120,
        windowMs: HOUR_MS,
      }, "Too many identity refreshes. Try again shortly.");
      return ensureIdentityForAuth(auth);
    },
);

exports.connectWithHomiCode = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const uid = auth.uid;
      const code = normalizeHomiCode(request.data && request.data.code);
      if (!HOMI_CODE_PATTERN.test(code)) {
        throw new HttpsError("invalid-argument", "Enter a valid 6-character Homi code.");
      }
      await requireRateLimit({
        scope: "connect_lookup_hour",
        actorUid: uid,
        limit: 30,
        windowMs: HOUR_MS,
      }, "Too many connection attempts. Wait a while and try again.");
      await requireRateLimit({
        scope: "connect_lookup_day",
        actorUid: uid,
        limit: 100,
        windowMs: DAY_MS,
      }, "You have reached today's connection-attempt limit.");

      if (await connectionCountFor(uid) >= MAX_CONNECTIONS_PER_USER) {
        throw new HttpsError(
            "resource-exhausted",
            "Homi supports up to 30 trusted connections on one account.",
        );
      }

      const own = await ensureIdentityForAuth(auth);
      if (own.code === code) {
        throw new HttpsError("invalid-argument", "That is your own Homi code.");
      }

      const targetCode = await db.collection("homiCodes").doc(code).get();
      if (!targetCode.exists) {
        throw new HttpsError("not-found", "That Homi code could not be found.");
      }
      const target = targetCode.data();
      const targetUid = typeof target.uid === "string" ? target.uid : "";
      if (!targetUid || targetUid === uid) {
        throw new HttpsError("not-found", "That Homi code is not available.");
      }
      const targetUser = await db.collection("users").doc(targetUid).get();
      if (!targetUser.exists || normalizeHomiCode(targetUser.data().homiCode) !== code) {
        throw new HttpsError("not-found", "That Homi code is not available.");
      }
      if (await connectionCountFor(targetUid) >= MAX_CONNECTIONS_PER_USER) {
        throw new HttpsError(
            "failed-precondition",
            "That person cannot accept another trusted connection right now.",
        );
      }

      const ids = [uid, targetUid].sort();
      const connectionId = `${ids[0]}_${ids[1]}`;
      const connectionRef = db.collection("connections").doc(connectionId);
      const existing = await connectionRef.get();
      if (existing.exists) {
        throw new HttpsError(
            "already-exists",
            existing.data().status === "accepted" ?
              "You are already connected to this person." :
              "There is already a connection request for this person.",
        );
      }

      const targetName = cleanRequiredString(
          targetUser.data().displayName || target.displayName || "Homi user",
          80,
          "That Homi profile is not available.",
      );
      const targetPhoto = cleanOptionalString(
          targetUser.data().photoUrl || target.photoUrl,
          1000,
          "That Homi profile image is not available.",
      );
      const aIsCurrent = ids[0] === uid;
      await connectionRef.create({
        memberUids: ids,
        initiatorUid: uid,
        recipientUid: targetUid,
        status: "pending",
        aUid: ids[0],
        aName: aIsCurrent ? own.displayName : targetName,
        aPhotoUrl: aIsCurrent ? own.photoUrl : targetPhoto,
        bUid: ids[1],
        bName: aIsCurrent ? targetName : own.displayName,
        bPhotoUrl: aIsCurrent ? targetPhoto : own.photoUrl,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {connectionId};
    },
);

exports.acceptTrustedConnection = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const connectionId = cleanRequiredString(
          request.data && request.data.connectionId,
          256,
          "Choose a valid connection request.",
      );
      await requireRateLimit({
        scope: "connection_accept_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many connection changes. Try again shortly.");

      const ref = db.collection("connections").doc(connectionId);
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "That connection request is no longer available.");
        }
        const data = snapshot.data();
        if (data.status !== "pending" || data.recipientUid !== auth.uid) {
          throw new HttpsError("permission-denied", "Only the invited person can accept this request.");
        }
        transaction.update(ref, {
          status: "accepted",
          acceptedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return {accepted: true};
    },
);

exports.removeTrustedConnection = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 30},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const connectionId = cleanRequiredString(
          request.data && request.data.connectionId,
          256,
          "Choose a valid trusted connection.",
      );
      await requireRateLimit({
        scope: "connection_remove_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many connection changes. Try again shortly.");

      const ref = db.collection("connections").doc(connectionId);
      const snapshot = await ref.get();
      if (!snapshot.exists) return {removed: true};
      const data = snapshot.data();
      if (data.aUid !== auth.uid && data.bUid !== auth.uid) {
        throw new HttpsError("permission-denied", "That connection does not belong to your account.");
      }
      const firstUid = data.aUid;
      const secondUid = data.bUid;
      if (!firstUid || !secondUid) {
        throw new HttpsError("failed-precondition", "That connection record is incomplete.");
      }

      await cleanupConnectionState(firstUid, secondUid);
      await ref.delete();
      return {removed: true};
    },
);

exports.setTrustedPersonPreference = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 30},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const otherUid = cleanRequiredString(
          request.data && request.data.otherUid,
          128,
          "Choose a trusted person.",
      );
      if (otherUid === auth.uid) {
        throw new HttpsError("invalid-argument", "Choose another person.");
      }
      const relationship = cleanRequiredString(
          request.data && request.data.relationship,
          40,
          "Keep the relationship label under 40 characters.",
      );
      const scope = request.data && request.data.scope === "household" ?
        "household" : "friend";
      if (!await acceptedConnection(auth.uid, otherUid)) {
        throw new HttpsError("permission-denied", "This person is not an accepted trusted connection.");
      }
      await requireRateLimit({
        scope: "preference_hour",
        actorUid: auth.uid,
        limit: 120,
        windowMs: HOUR_MS,
      }, "Too many relationship changes. Try again shortly.");

      if (scope === "friend") {
        await detachMemberFromCreatorTasks(auth.uid, otherUid);
      }
      await db.collection("peoplePreferences").doc(auth.uid)
          .collection("people").doc(otherUid).set({
            relationship,
            scope,
            updatedAt: FieldValue.serverTimestamp(),
          });
      return {saved: true};
    },
);

exports.setLocationShare = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const viewerUid = cleanRequiredString(
          request.data && request.data.viewerUid,
          128,
          "Choose a trusted person.",
      );
      const active = request.data && request.data.active;
      if (typeof active !== "boolean" || viewerUid === auth.uid) {
        throw new HttpsError("invalid-argument", "Choose a valid location-sharing setting.");
      }
      if (!await acceptedConnection(auth.uid, viewerUid)) {
        throw new HttpsError("permission-denied", "Location can only be shared with an accepted trusted person.");
      }
      await requireRateLimit({
        scope: "location_share_hour",
        actorUid: auth.uid,
        limit: 120,
        windowMs: HOUR_MS,
      }, "Too many sharing changes. Try again shortly.");
      await db.collection("locationShares").doc(auth.uid)
          .collection("viewers").doc(viewerUid).set({
            ownerUid: auth.uid,
            viewerUid,
            active,
            updatedAt: FieldValue.serverTimestamp(),
          });
      return {saved: true, active};
    },
);

exports.createSharedTask = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 30},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const creatorUid = auth.uid;
      const title = cleanRequiredString(
          request.data && request.data.title,
          120,
          "Give the task a short name under 120 characters.",
      );
      const notes = cleanOptionalString(
          request.data && request.data.notes,
          1000,
          "Keep task notes under 1000 characters.",
      );
      const assigneeUid = request.data && request.data.assigneeUid ?
        cleanRequiredString(request.data.assigneeUid, 128, "Choose a valid assignee.") : null;
      if (assigneeUid === creatorUid) {
        throw new HttpsError(
            "invalid-argument",
            "Tasks assigned to you stay private. Save this one as a personal task instead.",
        );
      }

      let dueAt = null;
      if (request.data && request.data.dueAtMs != null) {
        const dueAtMs = Number(request.data.dueAtMs);
        if (!Number.isFinite(dueAtMs) || dueAtMs < 0) {
          throw new HttpsError("invalid-argument", "Choose a valid task due time.");
        }
        dueAt = Timestamp.fromMillis(Math.trunc(dueAtMs));
      }

      await requireRateLimit({
        scope: "shared_task_action_hour",
        actorUid: creatorUid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many household tasks were added in a short time. Try again later.");
      await requireRateLimit({
        scope: "shared_task_action_day",
        actorUid: creatorUid,
        limit: 300,
        windowMs: DAY_MS,
      }, "You have reached today's shared-task limit.");

      const preferenceSnapshot = await db.collection("peoplePreferences")
          .doc(creatorUid).collection("people")
          .where("scope", "==", "household")
          .limit(MAX_HOUSEHOLD_MEMBERS_PER_TASK - 1)
          .get();
      const candidates = preferenceSnapshot.docs.map((doc) => doc.id);
      const checks = await Promise.all(candidates.map(async (uid) => ({
        uid,
        accepted: Boolean(await acceptedConnection(creatorUid, uid)),
      })));
      const members = [creatorUid, ...checks
          .filter((item) => item.accepted)
          .map((item) => item.uid)];
      const memberUids = [...new Set(members)].sort();
      if (memberUids.length < 2) {
        throw new HttpsError(
            "failed-precondition",
            "Add at least one Household person in People before sharing a household task.",
        );
      }
      if (assigneeUid && !memberUids.includes(assigneeUid)) {
        throw new HttpsError(
            "failed-precondition",
            "Mark this person as Household in People before assigning household tasks to them.",
        );
      }

      const creatorName = displayNameFromAuth(auth);
      const assigneeName = assigneeUid ? await displayNameFor(assigneeUid) : null;
      const ref = db.collection("sharedTasks").doc();
      await ref.create({
        title,
        notes,
        assigneeUid,
        assigneeName,
        createdByUid: creatorUid,
        createdByName: creatorName,
        memberUids,
        createdAt: FieldValue.serverTimestamp(),
        dueAt,
        completedAt: null,
        completedByName: null,
        completedByUid: null,
        purgeAt: null,
      });
      return {taskId: ref.id};
    },
);

exports.toggleSharedTask = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const taskId = cleanRequiredString(
          request.data && request.data.taskId,
          256,
          "Choose a valid household task.",
      );
      await requireRateLimit({
        scope: "shared_task_toggle_hour",
        actorUid: auth.uid,
        limit: 180,
        windowMs: HOUR_MS,
      }, "Too many task changes. Try again shortly.");

      const ref = db.collection("sharedTasks").doc(taskId);
      const snapshot = await ref.get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "That household task is no longer available.");
      }
      const data = snapshot.data();
      if (!await canAccessSharedTask(auth.uid, data)) {
        throw new HttpsError("permission-denied", "That household task is not available to your account.");
      }

      if (data.completedAt) {
        if (data.createdByUid !== auth.uid && data.completedByUid !== auth.uid) {
          throw new HttpsError(
              "permission-denied",
              "Only the person who completed this task or its creator can reopen it.",
          );
        }
        await ref.update({
          completedAt: null,
          completedByName: null,
          completedByUid: null,
          purgeAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {completed: false};
      }

      const now = Date.now();
      await ref.update({
        completedAt: FieldValue.serverTimestamp(),
        completedByName: displayNameFromAuth(auth),
        completedByUid: auth.uid,
        purgeAt: Timestamp.fromMillis(now + COMPLETED_TASK_RETENTION_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {completed: true};
    },
);

exports.removeSharedTask = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const taskId = cleanRequiredString(
          request.data && request.data.taskId,
          256,
          "Choose a valid household task.",
      );
      await requireRateLimit({
        scope: "shared_task_remove_hour",
        actorUid: auth.uid,
        limit: 120,
        windowMs: HOUR_MS,
      }, "Too many task removals. Try again shortly.");

      const ref = db.collection("sharedTasks").doc(taskId);
      const snapshot = await ref.get();
      if (!snapshot.exists) return {removed: true};
      const data = snapshot.data();
      if (!await canAccessSharedTask(auth.uid, data)) {
        throw new HttpsError("permission-denied", "That household task is not available to your account.");
      }
      const purgeAtMs = data.purgeAt && typeof data.purgeAt.toMillis === "function" ?
        data.purgeAt.toMillis() : 0;
      if (data.createdByUid !== auth.uid && (!purgeAtMs || purgeAtMs > Date.now())) {
        throw new HttpsError(
            "permission-denied",
            "Only the person who created this task can remove it before its completed-history period ends.",
        );
      }
      await ref.delete();
      return {removed: true};
    },
);

exports.queueDeveloperNotification = onCall(
    {enforceAppCheck: true, maxInstances: 2, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      if (!await isDeveloperAdmin(auth.uid)) {
        throw new HttpsError("permission-denied", "This account does not have developer notification access.");
      }
      await requireRateLimit({
        scope: "developer_queue_hour",
        actorUid: auth.uid,
        limit: 40,
        windowMs: HOUR_MS,
      }, "Developer notification queue limit reached. Try again later.");

      const title = cleanRequiredString(
          request.data && request.data.title,
          80,
          "Keep the notification title under 80 characters.",
      );
      const body = cleanRequiredString(
          request.data && request.data.body,
          280,
          "Keep the notification message under 280 characters.",
      );
      const allowedCategories = new Set(["update", "service", "security"]);
      const allowedRoutes = new Set([
        "overview", "tasks", "routines", "home", "supplies", "people", "account",
      ]);
      const category = request.data && allowedCategories.has(request.data.category) ?
        request.data.category : "update";
      const route = request.data && allowedRoutes.has(request.data.route) ?
        request.data.route : "overview";
      const audience = request.data && request.data.audience === "all" ? "all" : "self";
      const requestedPriority = request.data && request.data.priority === "important" ?
        "important" : "normal";
      const priority = category === "update" ? "normal" : requestedPriority;

      const ref = db.collection("notificationCampaigns").doc();
      await ref.create({
        title,
        body,
        category,
        route,
        audience,
        priority,
        createdByUid: auth.uid,
        status: "queued",
        createdAt: FieldValue.serverTimestamp(),
      });
      return {campaignId: ref.id};
    },
);

exports.deleteHomiAccountData = onCall(
    {enforceAppCheck: true, maxInstances: 2, timeoutSeconds: 60},
    async (request) => {
      const auth = requireRecentAuthentication(request);
      await requireRateLimit({
        scope: "account_delete_hour",
        actorUid: auth.uid,
        limit: 5,
        windowMs: HOUR_MS,
      }, "Too many account deletion attempts. Wait and try again.");
      return deleteCloudDataForUid(auth.uid);
    },
);

exports.sendHeart = onCall(
    {
      enforceAppCheck: true,
      maxInstances: 3,
      timeoutSeconds: 15,
    },
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const senderUid = auth.uid;
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

      await requireRateLimit({
        scope: "heart_day",
        actorUid: senderUid,
        limit: 40,
        windowMs: DAY_MS,
      }, "You have sent plenty of hearts today. Try again later.");

      const senderName = displayNameFromAuth(auth);
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

// Backstop cleanup protects privacy if a connection is removed administratively
// instead of through removeTrustedConnection. Normal app removal already cleans
// this state before deleting the connection, so repeating the cleanup is safe.
exports.onConnectionDeleted = onDocumentDeleted(
    "connections/{connectionId}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data || !data.aUid || !data.bUid) return;
      try {
        await cleanupConnectionState(data.aUid, data.bUid);
      } catch (error) {
        logger.error("Homi connection cleanup failed", {
          connectionId: event.params.connectionId,
          error: error && error.message,
        });
      }
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
        if (!creatorUid || !await isDeveloperAdmin(creatorUid)) {
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
        const requestedPriority = data.priority === "important" ? "important" : "normal";
        const priority = category === "update" ? "normal" : requestedPriority;
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
        logger.error("Homi notification campaign failed", {
          campaignId: event.params.campaignId,
          error: error && error.message,
        });
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

// Backstop for administrative/manual user-document deletion. Normal account
// deletion uses the recent-auth + App Check protected callable above.
exports.onHomiUserDocumentDeleted = onDocumentDeleted(
    "users/{uid}",
    async (event) => {
      try {
        await deleteCloudDataForUid(event.params.uid, {deleteUserDocument: false});
      } catch (error) {
        logger.error("Homi user cleanup backstop failed", {
          uid: event.params.uid,
          error: error && error.message,
        });
      }
    },
);
