const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

const db = getFirestore();
const messaging = getMessaging();

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const MAX_RECIPIENTS = 10;
const MAX_NOTIFICATION_DEVICES_PER_USER = 12;

function requireVerifiedAccount(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to send arrival check-ins.");
  }
  const provider = request.auth.token && request.auth.token.firebase &&
    request.auth.token.firebase.sign_in_provider;
  if (provider === "password" && request.auth.token.email_verified !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Verify your email before using arrival check-ins.",
    );
  }
  return request.auth;
}

async function acceptedConnection(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  const snapshot = await db.collection("connections")
      .doc(`${ids[0]}_${ids[1]}`).get();
  if (!snapshot.exists) return false;
  const data = snapshot.data();
  return data.status === "accepted" &&
    data.aUid === ids[0] &&
    data.bUid === ids[1];
}

async function consumeFixedWindowLimit({scope, actorUid, limit, windowMs}) {
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
    transaction.set(ref, {
      scope,
      actorUid,
      windowStartMs,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function requireRateLimit(options, message) {
  if (!await consumeFixedWindowLimit(options)) {
    throw new HttpsError("resource-exhausted", message);
  }
}

async function displayNameFor(uid, auth) {
  const tokenName = auth.token && typeof auth.token.name === "string" ?
    auth.token.name.trim() : "";
  if (tokenName) return tokenName.slice(0, 80);
  const snapshot = await db.collection("users").doc(uid).get();
  const saved = snapshot.data() && snapshot.data().displayName;
  if (typeof saved === "string" && saved.trim()) return saved.trim().slice(0, 80);
  return "Someone you trust";
}

function deviceAllowsPeople(data) {
  return data &&
    data.notificationsEnabled === true &&
    data.peopleNotifications !== false &&
    typeof data.pushToken === "string" &&
    data.pushToken.length > 0;
}

async function sendToUser(uid, payload) {
  const snapshot = await db.collection("users").doc(uid)
      .collection("devices")
      .where("notificationsEnabled", "==", true)
      .limit(MAX_NOTIFICATION_DEVICES_PER_USER)
      .get();
  const eligible = snapshot.docs
      .map((doc) => ({doc, data: doc.data()}))
      .filter(({data}) => deviceAllowsPeople(data));

  let successCount = 0;
  let failureCount = 0;
  for (let start = 0; start < eligible.length; start += 500) {
    const group = eligible.slice(start, start + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: group.map(({data}) => data.pushToken),
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        category: "people",
        route: "people",
        checkInPlace: payload.place,
      },
      android: {
        priority: "normal",
        notification: {
          channelId: "homi_people",
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
        cleanup.push(group[index].doc.ref.set({
          pushToken: FieldValue.delete(),
          notificationsEnabled: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}));
      }
    });
    await Promise.all(cleanup);
  }
  return {successCount, failureCount};
}

exports.sendArrivalCheckIn = onCall(
    {
      enforceAppCheck: true,
      maxInstances: 3,
      timeoutSeconds: 20,
    },
    async (request) => {
      const auth = requireVerifiedAccount(request);
      const place = request.data && request.data.place;
      if (place !== "home" && place !== "work") {
        throw new HttpsError("invalid-argument", "Choose Home or Work.");
      }

      const requested = request.data && request.data.recipientUids;
      if (!Array.isArray(requested)) {
        throw new HttpsError("invalid-argument", "Choose who receives the check-in.");
      }
      const recipients = [...new Set(
          requested
              .filter((uid) => typeof uid === "string")
              .map((uid) => uid.trim())
              .filter((uid) => uid && uid !== auth.uid),
      )];
      if (recipients.length === 0 || recipients.length > MAX_RECIPIENTS) {
        throw new HttpsError(
            "invalid-argument",
            `Choose between 1 and ${MAX_RECIPIENTS} trusted people.`,
        );
      }

      await requireRateLimit({
        scope: "arrival_checkin_hour",
        actorUid: auth.uid,
        limit: 20,
        windowMs: HOUR_MS,
      }, "Too many arrival check-ins were sent in a short time.");
      await requireRateLimit({
        scope: "arrival_checkin_day",
        actorUid: auth.uid,
        limit: 60,
        windowMs: DAY_MS,
      }, "Today's arrival check-in limit has been reached.");

      const connectionChecks = await Promise.all(
          recipients.map(async (uid) => ({
            uid,
            accepted: await acceptedConnection(auth.uid, uid),
          })),
      );
      const invalid = connectionChecks.find((item) => !item.accepted);
      if (invalid) {
        throw new HttpsError(
            "permission-denied",
            "Arrival check-ins can only be sent to accepted trusted people.",
        );
      }

      const senderName = await displayNameFor(auth.uid, auth);
      const locationText = place === "home" ? "home" : "at work";
      const title = `${senderName} arrived ${locationText}`;
      const body = "Homi check-in from someone you trust.";
      const results = await Promise.all(
          recipients.map((uid) => sendToUser(uid, {
            title,
            body,
            place,
          })),
      );

      return {
        accepted: true,
        recipientCount: recipients.length,
        deliveredDevices: results.reduce(
            (sum, result) => sum + result.successCount,
            0,
        ),
      };
    },
);
