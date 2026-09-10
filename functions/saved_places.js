const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const MAX_VIEWERS = 10;

function requireVerifiedCloudAccount(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  const provider = request.auth.token && request.auth.token.firebase &&
    request.auth.token.firebase.sign_in_provider;
  if (provider === "password" && request.auth.token.email_verified !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Verify your email before using Homi sharing features.",
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

async function consumeLimit({scope, actorUid, limit, windowMs}) {
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

function parseKind(value) {
  const kind = String(value || "").trim().toLowerCase();
  if (kind !== "home" && kind !== "work") {
    throw new HttpsError("invalid-argument", "Choose Home or Work.");
  }
  return kind;
}

function parseCoordinate(value, min, max, label) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max) {
    throw new HttpsError("invalid-argument", `Choose a valid ${label}.`);
  }
  return number;
}

function cleanAddress(value) {
  const address = String(value || "").trim();
  if (!address || address.length > 300) {
    throw new HttpsError(
        "invalid-argument",
        "Choose a valid saved-place address.",
    );
  }
  return address;
}

function requestedViewers(value, ownerUid) {
  if (!Array.isArray(value)) {
    throw new HttpsError(
        "invalid-argument",
        "Choose who may see this saved place.",
    );
  }
  const viewers = [...new Set(value
      .map((uid) => String(uid || "").trim())
      .filter((uid) => uid && uid !== ownerUid))];
  if (viewers.length > MAX_VIEWERS) {
    throw new HttpsError(
        "invalid-argument",
        "Choose no more than 10 people for one saved place.",
    );
  }
  return viewers;
}

exports.setSharedArrivalPlace = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const ownerUid = auth.uid;
      const kind = parseKind(request.data && request.data.kind);
      const ref = db.collection("sharedPlaces").doc(ownerUid)
          .collection("places").doc(kind);

      const hourAllowed = await consumeLimit({
        scope: "shared_place_hour",
        actorUid: ownerUid,
        limit: 120,
        windowMs: HOUR_MS,
      });
      if (!hourAllowed) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many saved-place changes. Try again shortly.",
        );
      }
      const dayAllowed = await consumeLimit({
        scope: "shared_place_day",
        actorUid: ownerUid,
        limit: 400,
        windowMs: DAY_MS,
      });
      if (!dayAllowed) {
        throw new HttpsError(
            "resource-exhausted",
            "You have reached today's saved-place change limit.",
        );
      }

      if (request.data && request.data.clear === true) {
        await ref.delete();
        return {saved: true, shared: false, viewerCount: 0};
      }

      const latitude = parseCoordinate(
          request.data && request.data.latitude, -90, 90, "latitude",
      );
      const longitude = parseCoordinate(
          request.data && request.data.longitude, -180, 180, "longitude",
      );
      const address = cleanAddress(request.data && request.data.address);
      const requested = requestedViewers(
          request.data && request.data.viewerUids, ownerUid,
      );

      const checks = await Promise.all(requested.map(async (uid) => ({
        uid,
        accepted: await acceptedConnection(ownerUid, uid),
      })));
      const viewerUids = checks
          .filter((item) => item.accepted)
          .map((item) => item.uid)
          .sort();

      if (viewerUids.length === 0) {
        await ref.delete();
        return {saved: true, shared: false, viewerCount: 0};
      }

      await ref.set({
        ownerUid,
        kind,
        latitude,
        longitude,
        address,
        viewerUids,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        saved: true,
        shared: true,
        viewerCount: viewerUids.length,
      };
    },
);

// Known Home/Work documents are bounded, so account cleanup does not need a
// recursive collection scan. This trigger is a privacy backstop when the Homi
// user document is removed by account deletion or administrative cleanup.
exports.onHomiUserSharedPlacesDeleted = onDocumentDeleted(
    "users/{uid}",
    async (event) => {
      const uid = event.params.uid;
      try {
        const parent = db.collection("sharedPlaces").doc(uid)
            .collection("places");
        const batch = db.batch();
        batch.delete(parent.doc("home"));
        batch.delete(parent.doc("work"));
        await batch.commit();
      } catch (error) {
        logger.error("Homi shared-place cleanup failed", {
          uid,
          error: error && error.message,
        });
      }
    },
);
