const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;
const MAX_DEVICE_RECORDS_PER_USER = 12;

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to register this device.");
  }
  return request.auth;
}

function requiredString(value, maxLength, message) {
  const result = String(value || "").trim();
  if (!result || result.length > maxLength) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}

function requiredBool(value, message) {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", message);
  }
  return value;
}

async function consumeDeviceLimit(uid) {
  const ref = db.collection("serverRateLimits").doc(`device_registration_hour_${uid}`);
  const now = Date.now();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const start = Number(data.windowStartMs || 0);
    const count = Number(data.count || 0);
    const expired = !start || now - start >= HOUR_MS;
    const nextStart = expired ? now : start;
    const nextCount = expired ? 0 : count;
    if (nextCount >= 60) return false;
    transaction.set(ref, {
      scope: "device_registration_hour",
      actorUid: uid,
      windowStartMs: nextStart,
      count: nextCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

exports.registerNotificationDevice = onCall(
    {enforceAppCheck: true, maxInstances: 2, timeoutSeconds: 15},
    async (request) => {
      const auth = requireAuth(request);
      if (!await consumeDeviceLimit(auth.uid)) {
        throw new HttpsError(
            "resource-exhausted",
            "This device has refreshed notification registration too often. Try again later.",
        );
      }

      const data = request.data || {};
      const deviceId = requiredString(
          data.deviceId,
          128,
          "The Homi installation identifier is invalid.",
      );
      const pushToken = requiredString(
          data.pushToken,
          4096,
          "The notification delivery token is invalid.",
      );
      const platform = requiredString(data.platform, 32, "The device platform is invalid.");
      if (platform !== "android") {
        throw new HttpsError("failed-precondition", "This Homi build supports Android registration.");
      }

      const ref = db.collection("users").doc(auth.uid)
          .collection("devices").doc(deviceId);
      const existing = await ref.get();
      if (!existing.exists) {
        const count = await db.collection("users").doc(auth.uid)
            .collection("devices")
            .limit(MAX_DEVICE_RECORDS_PER_USER + 1)
            .get();
        if (count.size >= MAX_DEVICE_RECORDS_PER_USER) {
          throw new HttpsError(
              "resource-exhausted",
              "This Homi account already has the maximum number of registered devices.",
          );
        }
      }

      await ref.set({
        pushToken,
        platform,
        notificationsEnabled: true,
        householdAttention: requiredBool(
            data.householdAttention,
            "Household notification preference is invalid.",
        ),
        tasksAndRoutines: requiredBool(
            data.tasksAndRoutines,
            "Task notification preference is invalid.",
        ),
        peopleNotifications: requiredBool(
            data.peopleNotifications,
            "People notification preference is invalid.",
        ),
        homiUpdates: requiredBool(
            data.homiUpdates,
            "Homi update preference is invalid.",
        ),
        serviceNotices: requiredBool(
            data.serviceNotices,
            "Service notification preference is invalid.",
        ),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {registered: true};
    },
);

exports.removeNotificationDevice = onCall(
    {enforceAppCheck: true, maxInstances: 2, timeoutSeconds: 15},
    async (request) => {
      const auth = requireAuth(request);
      const deviceId = requiredString(
          request.data && request.data.deviceId,
          128,
          "The Homi installation identifier is invalid.",
      );
      if (!await consumeDeviceLimit(auth.uid)) {
        throw new HttpsError(
            "resource-exhausted",
            "This device has changed notification registration too often. Try again later.",
        );
      }
      await db.collection("users").doc(auth.uid)
          .collection("devices").doc(deviceId).delete();
      return {removed: true};
    },
);
