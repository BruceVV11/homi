const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;

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

function cleanRequiredString(value, maxLength, message) {
  const result = String(value || "").trim();
  if (!result || result.length > maxLength) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}

function connectionRef(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  return db.collection("connections").doc(`${ids[0]}_${ids[1]}`);
}

async function acceptedConnection(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  const snapshot = await connectionRef(firstUid, secondUid).get();
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

async function shareCanonicalHousehold(firstUid, secondUid) {
  const [first, second] = await Promise.all([
    db.collection("householdMemberships").doc(firstUid).get(),
    db.collection("householdMemberships").doc(secondUid).get(),
  ]);
  if (!first.exists || !second.exists) return false;
  const firstHouseholdId = first.data().householdId;
  const secondHouseholdId = second.data().householdId;
  return typeof firstHouseholdId === "string" &&
    firstHouseholdId.length > 0 &&
    firstHouseholdId === secondHouseholdId;
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
}

// Keep the historic callable name so deployed clients do not change. The
// relationship label remains user-editable, but Household scope is now derived
// exclusively from canonical Household membership and can no longer be
// manufactured from the People edit sheet.
exports.setTrustedPersonPreference = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 30},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const otherUid = cleanRequiredString(
          request.data && request.data.otherUid,
          128,
          "Choose a trusted person.",
      );
      const relationship = cleanRequiredString(
          request.data && request.data.relationship,
          40,
          "Keep the relationship label under 40 characters.",
      );
      if (otherUid === auth.uid) {
        throw new HttpsError("invalid-argument", "Choose another person.");
      }
      if (!await acceptedConnection(auth.uid, otherUid)) {
        throw new HttpsError(
            "permission-denied",
            "This person is not an accepted trusted connection.",
        );
      }
      if (!await consumeFixedWindowLimit({
        scope: "trusted_person_preference_hour",
        actorUid: auth.uid,
        limit: 120,
        windowMs: HOUR_MS,
      })) {
        throw new HttpsError(
            "resource-exhausted",
            "Too many relationship changes. Try again shortly.",
        );
      }

      const household = await shareCanonicalHousehold(auth.uid, otherUid);
      const scope = household ? "household" : "friend";
      if (!household) {
        await detachMemberFromCreatorTasks(auth.uid, otherUid);
      }

      await db.collection("peoplePreferences").doc(auth.uid)
          .collection("people").doc(otherUid).set({
            relationship,
            scope,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});

      return {saved: true, scope};
    },
);
