const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;
const MAX_ACTIVE_LIVE_VIEWERS = 5;

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

function cleanViewerUid(value) {
  const result = String(value || "").trim();
  if (!result || result.length > 128) {
    throw new HttpsError("invalid-argument", "Choose a trusted person.");
  }
  return result;
}

async function acceptedConnection(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  const snapshot = await db
      .collection("connections")
      .doc(`${ids[0]}_${ids[1]}`)
      .get();
  if (!snapshot.exists) return false;
  const data = snapshot.data();
  return data.status === "accepted" &&
    data.aUid === ids[0] &&
    data.bUid === ids[1];
}

async function consumeLocationShareLimit(actorUid) {
  const ref = db.collection("serverRateLimits")
      .doc(`location_share_hour_${actorUid}`);
  const now = Date.now();
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.exists ? snapshot.data() : {};
    const storedStart = Number(data.windowStartMs || 0);
    const storedCount = Number(data.count || 0);
    const expired = !storedStart || now - storedStart >= HOUR_MS;
    const count = expired ? 0 : storedCount;
    if (count >= 120) return false;
    transaction.set(ref, {
      scope: "location_share_hour",
      actorUid,
      windowStartMs: expired ? now : storedStart,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

/**
 * Location-share authorization boundary with a hard cost cap.
 *
 * Deactivation is deliberately available even after a relationship is gone and
 * is not blocked by the activation rate limiter. Enabling a new viewer requires
 * an accepted connection and enforces no more than five active viewers for one
 * sender. This cap is independent from the future paid-plan entitlement check;
 * it protects the current beta backend before Play billing is activated.
 */
exports.setLocationShare = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const viewerUid = cleanViewerUid(request.data && request.data.viewerUid);
      const active = request.data && request.data.active;
      if (typeof active !== "boolean" || viewerUid === auth.uid) {
        throw new HttpsError(
            "invalid-argument",
            "Choose a valid location-sharing setting.",
        );
      }

      const viewerRef = db.collection("locationShares").doc(auth.uid)
          .collection("viewers").doc(viewerUid);

      if (!active) {
        const existing = await viewerRef.get();
        if (existing.exists) {
          await viewerRef.set({
            ownerUid: auth.uid,
            viewerUid,
            active: false,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        return {saved: true, active: false};
      }

      if (!await acceptedConnection(auth.uid, viewerUid)) {
        throw new HttpsError(
            "permission-denied",
            "Location can only be shared with an accepted trusted person.",
        );
      }

      if (!await consumeLocationShareLimit(auth.uid)) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many sharing changes. Try again shortly.",
        );
      }

      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(viewerRef);
        if (current.exists && current.data().active === true) {
          transaction.set(viewerRef, {
            ownerUid: auth.uid,
            viewerUid,
            active: true,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return;
        }

        const activeQuery = db.collection("locationShares").doc(auth.uid)
            .collection("viewers")
            .where("active", "==", true)
            .limit(MAX_ACTIVE_LIVE_VIEWERS);
        const activeViewers = await transaction.get(activeQuery);
        if (activeViewers.size >= MAX_ACTIVE_LIVE_VIEWERS) {
          throw new HttpsError(
              "failed-precondition",
              "Live location can be shared with up to five trusted people at a time.",
          );
        }

        transaction.set(viewerRef, {
          ownerUid: auth.uid,
          viewerUid,
          active: true,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });

      return {
        saved: true,
        active: true,
        maxActiveViewers: MAX_ACTIVE_LIVE_VIEWERS,
      };
    },
);
