const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const MAX_HOUSEHOLD_MEMBERS = 4;

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

function profileName(data) {
  const name = data && typeof data.displayName === "string" ?
    data.displayName.trim() : "";
  return name ? name.slice(0, 80) : "Homi user";
}

function profilePhoto(data) {
  const photo = data && typeof data.photoUrl === "string" ?
    data.photoUrl.trim() : "";
  return photo ? photo.slice(0, 1000) : null;
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

async function requireRateLimit(options, message) {
  if (!await consumeFixedWindowLimit(options)) {
    throw new HttpsError("resource-exhausted", message);
  }
}

function connectionRef(firstUid, secondUid) {
  const ids = [firstUid, secondUid].sort();
  return db.collection("connections").doc(`${ids[0]}_${ids[1]}`);
}

function acceptedConnectionData(snapshot, firstUid, secondUid) {
  if (!snapshot.exists) return false;
  const ids = [firstUid, secondUid].sort();
  const data = snapshot.data();
  return data.status === "accepted" &&
    data.aUid === ids[0] &&
    data.bUid === ids[1];
}

function membershipRef(uid) {
  return db.collection("householdMemberships").doc(uid);
}

function householdRef(householdId) {
  return db.collection("households").doc(householdId);
}

function memberRef(householdId, uid) {
  return householdRef(householdId).collection("members").doc(uid);
}

function inviteRef(householdId, inviteeUid) {
  return db.collection("householdInvites").doc(`${householdId}_${inviteeUid}`);
}

function uniqueUids(values) {
  return [...new Set((Array.isArray(values) ? values : [])
      .filter((value) => typeof value === "string" && value.trim())
      .map((value) => value.trim()))];
}

function householdMembers(data) {
  return uniqueUids(data && data.memberUids);
}

function pendingInvitees(data) {
  return uniqueUids(data && data.pendingInviteUids);
}

async function setRelationshipScope(firstUid, secondUid, scope) {
  const connection = await connectionRef(firstUid, secondUid).get();
  if (!acceptedConnectionData(connection, firstUid, secondUid)) return;
  const batch = db.batch();
  for (const [ownerUid, otherUid] of [
    [firstUid, secondUid],
    [secondUid, firstUid],
  ]) {
    batch.set(
        db.collection("peoplePreferences").doc(ownerUid)
            .collection("people").doc(otherUid),
        {
          scope,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  }
  await batch.commit();
}

async function releaseInviteReservation(document) {
  const data = document.data();
  const householdId = data && data.householdId;
  const inviteeUid = data && data.inviteeUid;
  if (householdId && inviteeUid) {
    await householdRef(householdId).update({
      pendingInviteUids: FieldValue.arrayRemove(inviteeUid),
      updatedAt: FieldValue.serverTimestamp(),
    }).catch((error) => {
      if (!error || error.code !== 5) throw error;
    });
  }
  await document.ref.delete();
}

async function clearOtherIncomingInvites(uid, keepInviteId = null) {
  const snapshot = await db.collection("householdInvites")
      .where("inviteeUid", "==", uid).get();
  for (const document of snapshot.docs) {
    if (document.id === keepInviteId) continue;
    await releaseInviteReservation(document);
  }
}

async function clearInvitesCreatedBy(uid) {
  const snapshot = await db.collection("householdInvites")
      .where("inviterUid", "==", uid).get();
  for (const document of snapshot.docs) {
    await releaseInviteReservation(document);
  }
}

exports.createHousehold = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const name = cleanRequiredString(
          request.data && request.data.name,
          60,
          "Keep the Household name under 60 characters.",
      );
      await requireRateLimit({
        scope: "household_create_day",
        actorUid: auth.uid,
        limit: 10,
        windowMs: DAY_MS,
      }, "Too many Household creation attempts. Try again later.");

      const homeRef = db.collection("households").doc();
      const myMembership = membershipRef(auth.uid);
      const myMember = memberRef(homeRef.id, auth.uid);
      const displayName = displayNameFromAuth(auth);
      const photoUrl = photoUrlFromAuth(auth);

      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(myMembership);
        if (existing.exists) {
          throw new HttpsError(
              "failed-precondition",
              "This account already belongs to a Homi Household.",
          );
        }
        transaction.create(homeRef, {
          name,
          ownerUid: auth.uid,
          memberUids: [auth.uid],
          pendingInviteUids: [],
          memberLimit: MAX_HOUSEHOLD_MEMBERS,
          schemaVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(myMembership, {
          householdId: homeRef.id,
          role: "owner",
          joinedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(myMember, {
          uid: auth.uid,
          role: "owner",
          displayName,
          photoUrl,
          joinedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      await clearOtherIncomingInvites(auth.uid);
      return {created: true, householdId: homeRef.id};
    },
);

exports.renameHousehold = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 15},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const name = cleanRequiredString(
          request.data && request.data.name,
          60,
          "Keep the Household name under 60 characters.",
      );
      await requireRateLimit({
        scope: "household_manage_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household changes. Try again shortly.");

      const myMembership = membershipRef(auth.uid);
      const membership = await myMembership.get();
      if (!membership.exists || membership.data().role !== "owner") {
        throw new HttpsError(
            "permission-denied",
            "Only the Household owner can change its name.",
        );
      }
      const householdId = membership.data().householdId;
      const home = householdRef(householdId);
      const snapshot = await home.get();
      if (!snapshot.exists || snapshot.data().ownerUid !== auth.uid) {
        throw new HttpsError(
            "failed-precondition",
            "That Household is unavailable.",
        );
      }
      await home.update({name, updatedAt: FieldValue.serverTimestamp()});

      const invites = await db.collection("householdInvites")
          .where("householdId", "==", householdId).get();
      const batch = db.batch();
      let changed = 0;
      for (const document of invites.docs) {
        batch.set(document.ref, {
          householdName: name,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        changed += 1;
      }
      if (changed > 0) await batch.commit();
      return {saved: true};
    },
);

exports.inviteHouseholdMember = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const inviteeUid = cleanRequiredString(
          request.data && request.data.inviteeUid,
          128,
          "Choose a trusted person.",
      );
      if (inviteeUid === auth.uid) {
        throw new HttpsError("invalid-argument", "Choose another person.");
      }
      await requireRateLimit({
        scope: "household_invite_day",
        actorUid: auth.uid,
        limit: 30,
        windowMs: DAY_MS,
      }, "Too many Household invitations. Try again later.");

      const ownerMembershipRef = membershipRef(auth.uid);
      const targetMembershipRef = membershipRef(inviteeUid);
      const connection = connectionRef(auth.uid, inviteeUid);
      const targetUserRef = db.collection("users").doc(inviteeUid);

      let resultHouseholdId = "";
      await db.runTransaction(async (transaction) => {
        const ownerMembership = await transaction.get(ownerMembershipRef);
        if (!ownerMembership.exists || ownerMembership.data().role !== "owner") {
          throw new HttpsError(
              "permission-denied",
              "Only the Household owner can invite members.",
          );
        }
        const householdId = ownerMembership.data().householdId;
        resultHouseholdId = householdId;
        const home = householdRef(householdId);
        const invitation = inviteRef(householdId, inviteeUid);
        const [homeSnapshot, targetMembership, connectionSnapshot, targetUser,
          existingInvite] = await Promise.all([
          transaction.get(home),
          transaction.get(targetMembershipRef),
          transaction.get(connection),
          transaction.get(targetUserRef),
          transaction.get(invitation),
        ]);
        if (!homeSnapshot.exists || homeSnapshot.data().ownerUid !== auth.uid) {
          throw new HttpsError(
              "failed-precondition",
              "That Household is unavailable.",
          );
        }
        if (targetMembership.exists) {
          throw new HttpsError(
              "failed-precondition",
              "That person already belongs to a Homi Household.",
          );
        }
        if (!acceptedConnectionData(connectionSnapshot, auth.uid, inviteeUid)) {
          throw new HttpsError(
              "failed-precondition",
              "Connect with this person in People before adding them to your Household.",
          );
        }
        if (!targetUser.exists) {
          throw new HttpsError("not-found", "That Homi account is unavailable.");
        }
        const data = homeSnapshot.data();
        const members = householdMembers(data);
        const pending = pendingInvitees(data);
        if (members.includes(inviteeUid)) {
          throw new HttpsError(
              "already-exists",
              "That person is already in this Household.",
          );
        }
        if (existingInvite.exists || pending.includes(inviteeUid)) {
          throw new HttpsError(
              "already-exists",
              "That person already has a Household invite.",
          );
        }
        if (members.length + pending.length >= MAX_HOUSEHOLD_MEMBERS) {
          throw new HttpsError(
              "failed-precondition",
              "Homi Household currently supports up to four members, including pending invites.",
          );
        }

        const nextPending = [...pending, inviteeUid];
        transaction.update(home, {
          pendingInviteUids: nextPending,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(invitation, {
          householdId,
          householdName: data.name || "Homi Household",
          inviterUid: auth.uid,
          inviterName: displayNameFromAuth(auth),
          inviteeUid,
          inviteeName: profileName(targetUser.data()),
          inviteePhotoUrl: profilePhoto(targetUser.data()),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      return {sent: true, householdId: resultHouseholdId};
    },
);

exports.respondHouseholdInvite = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 25},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const invitationId = cleanRequiredString(
          request.data && request.data.inviteId,
          300,
          "Choose a valid Household invitation.",
      );
      const action = request.data && request.data.action;
      if (action !== "accept" && action !== "decline") {
        throw new HttpsError("invalid-argument", "Choose accept or decline.");
      }
      await requireRateLimit({
        scope: "household_invite_response_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household invitation changes. Try again shortly.");

      const invitation = db.collection("householdInvites").doc(invitationId);
      let inviterUid = null;
      await db.runTransaction(async (transaction) => {
        const inviteSnapshot = await transaction.get(invitation);
        if (!inviteSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "That Household invitation is no longer available.",
          );
        }
        const invite = inviteSnapshot.data();
        if (invite.inviteeUid !== auth.uid) {
          throw new HttpsError(
              "permission-denied",
              "Only the invited person can respond to this Household invitation.",
          );
        }
        const householdId = invite.householdId;
        inviterUid = invite.inviterUid;
        const home = householdRef(householdId);
        const [homeSnapshot, myMembership, connectionSnapshot] =
          await Promise.all([
            transaction.get(home),
            transaction.get(membershipRef(auth.uid)),
            transaction.get(connectionRef(invite.inviterUid, auth.uid)),
          ]);

        if (action === "decline") {
          if (homeSnapshot.exists) {
            transaction.update(home, {
              pendingInviteUids: pendingInvitees(homeSnapshot.data())
                  .filter((uid) => uid !== auth.uid),
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
          transaction.delete(invitation);
          return;
        }

        if (myMembership.exists) {
          throw new HttpsError(
              "failed-precondition",
              "This account already belongs to a Homi Household.",
          );
        }
        if (!homeSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "That Household is no longer available.",
          );
        }
        if (!acceptedConnectionData(
          connectionSnapshot,
          invite.inviterUid,
          auth.uid,
        )) {
          throw new HttpsError(
              "failed-precondition",
              "Reconnect with the Household owner in People before accepting this invite.",
          );
        }
        const data = homeSnapshot.data();
        const members = householdMembers(data);
        if (members.length >= MAX_HOUSEHOLD_MEMBERS) {
          throw new HttpsError(
              "failed-precondition",
              "That Household is already full.",
          );
        }
        if (!pendingInvitees(data).includes(auth.uid)) {
          throw new HttpsError(
              "not-found",
              "That Household invitation is no longer active.",
          );
        }
        const nextMembers = [...members, auth.uid];
        transaction.update(home, {
          memberUids: nextMembers,
          pendingInviteUids: pendingInvitees(data)
              .filter((uid) => uid !== auth.uid),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(membershipRef(auth.uid), {
          householdId,
          role: "member",
          joinedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(memberRef(householdId, auth.uid), {
          uid: auth.uid,
          role: "member",
          displayName: displayNameFromAuth(auth),
          photoUrl: photoUrlFromAuth(auth),
          joinedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.delete(invitation);
      });

      if (action === "accept") {
        await clearOtherIncomingInvites(auth.uid);
        if (inviterUid) {
          await setRelationshipScope(inviterUid, auth.uid, "household");
        }
      }
      return {saved: true, accepted: action === "accept"};
    },
);

exports.cancelHouseholdInvite = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const invitationId = cleanRequiredString(
          request.data && request.data.inviteId,
          300,
          "Choose a valid Household invitation.",
      );
      await requireRateLimit({
        scope: "household_manage_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household changes. Try again shortly.");

      const invitation = db.collection("householdInvites").doc(invitationId);
      await db.runTransaction(async (transaction) => {
        const inviteSnapshot = await transaction.get(invitation);
        if (!inviteSnapshot.exists) return;
        const invite = inviteSnapshot.data();
        const home = householdRef(invite.householdId);
        const [ownerMembership, homeSnapshot] = await Promise.all([
          transaction.get(membershipRef(auth.uid)),
          transaction.get(home),
        ]);
        if (!ownerMembership.exists ||
            ownerMembership.data().householdId !== invite.householdId ||
            ownerMembership.data().role !== "owner" ||
            !homeSnapshot.exists ||
            homeSnapshot.data().ownerUid !== auth.uid) {
          throw new HttpsError(
              "permission-denied",
              "Only the Household owner can cancel this invitation.",
          );
        }
        transaction.update(home, {
          pendingInviteUids: pendingInvitees(homeSnapshot.data())
              .filter((uid) => uid !== invite.inviteeUid),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.delete(invitation);
      });
      return {cancelled: true};
    },
);

exports.removeHouseholdMember = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const memberUid = cleanRequiredString(
          request.data && request.data.memberUid,
          128,
          "Choose a Household member.",
      );
      if (memberUid === auth.uid) {
        throw new HttpsError(
            "invalid-argument",
            "Use Leave Household for your own membership.",
        );
      }
      await requireRateLimit({
        scope: "household_manage_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household changes. Try again shortly.");

      let householdId = "";
      await db.runTransaction(async (transaction) => {
        const ownerMembership = await transaction.get(membershipRef(auth.uid));
        if (!ownerMembership.exists || ownerMembership.data().role !== "owner") {
          throw new HttpsError(
              "permission-denied",
              "Only the Household owner can remove members.",
          );
        }
        householdId = ownerMembership.data().householdId;
        const home = householdRef(householdId);
        const [homeSnapshot, targetMembership] = await Promise.all([
          transaction.get(home),
          transaction.get(membershipRef(memberUid)),
        ]);
        if (!homeSnapshot.exists || homeSnapshot.data().ownerUid !== auth.uid) {
          throw new HttpsError(
              "failed-precondition",
              "That Household is unavailable.",
          );
        }
        if (!targetMembership.exists ||
            targetMembership.data().householdId !== householdId) {
          throw new HttpsError(
              "not-found",
              "That person is no longer in this Household.",
          );
        }
        if (targetMembership.data().role === "owner") {
          throw new HttpsError(
              "failed-precondition",
              "Transfer ownership before removing the owner.",
          );
        }
        transaction.update(home, {
          memberUids: householdMembers(homeSnapshot.data())
              .filter((uid) => uid !== memberUid),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.delete(membershipRef(memberUid));
        transaction.delete(memberRef(householdId, memberUid));
      });
      await setRelationshipScope(auth.uid, memberUid, "friend");
      return {removed: true, householdId};
    },
);

exports.leaveHousehold = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      await requireRateLimit({
        scope: "household_manage_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household changes. Try again shortly.");

      let ownerUid = null;
      await db.runTransaction(async (transaction) => {
        const myMembership = await transaction.get(membershipRef(auth.uid));
        if (!myMembership.exists) {
          throw new HttpsError(
              "not-found",
              "This account is not in a Homi Household.",
          );
        }
        const householdId = myMembership.data().householdId;
        const home = householdRef(householdId);
        const homeSnapshot = await transaction.get(home);
        if (!homeSnapshot.exists) {
          transaction.delete(membershipRef(auth.uid));
          return;
        }
        ownerUid = homeSnapshot.data().ownerUid;
        if (ownerUid === auth.uid) {
          throw new HttpsError(
              "failed-precondition",
              "Transfer Household ownership before leaving. If you are the only member, delete the Household instead.",
          );
        }
        transaction.update(home, {
          memberUids: householdMembers(homeSnapshot.data())
              .filter((uid) => uid !== auth.uid),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.delete(membershipRef(auth.uid));
        transaction.delete(memberRef(householdId, auth.uid));
      });
      if (ownerUid) {
        await setRelationshipScope(ownerUid, auth.uid, "friend");
      }
      return {left: true};
    },
);

exports.transferHouseholdOwnership = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 20},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      const nextOwnerUid = cleanRequiredString(
          request.data && request.data.memberUid,
          128,
          "Choose a Household member.",
      );
      if (nextOwnerUid === auth.uid) {
        throw new HttpsError(
            "invalid-argument",
            "Choose another Household member.",
        );
      }
      await requireRateLimit({
        scope: "household_manage_hour",
        actorUid: auth.uid,
        limit: 60,
        windowMs: HOUR_MS,
      }, "Too many Household changes. Try again shortly.");

      await db.runTransaction(async (transaction) => {
        const ownerMembership = await transaction.get(membershipRef(auth.uid));
        if (!ownerMembership.exists || ownerMembership.data().role !== "owner") {
          throw new HttpsError(
              "permission-denied",
              "Only the Household owner can transfer ownership.",
          );
        }
        const householdId = ownerMembership.data().householdId;
        const home = householdRef(householdId);
        const [homeSnapshot, targetMembership] = await Promise.all([
          transaction.get(home),
          transaction.get(membershipRef(nextOwnerUid)),
        ]);
        if (!homeSnapshot.exists || homeSnapshot.data().ownerUid !== auth.uid) {
          throw new HttpsError(
              "failed-precondition",
              "That Household is unavailable.",
          );
        }
        if (!targetMembership.exists ||
            targetMembership.data().householdId !== householdId) {
          throw new HttpsError(
              "failed-precondition",
              "Choose someone already in this Household.",
          );
        }
        transaction.update(home, {
          ownerUid: nextOwnerUid,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(membershipRef(auth.uid), {
          role: "member",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(memberRef(householdId, auth.uid), {
          role: "member",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(membershipRef(nextOwnerUid), {
          role: "owner",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(memberRef(householdId, nextOwnerUid), {
          role: "owner",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return {transferred: true, ownerUid: nextOwnerUid};
    },
);

exports.deleteHousehold = onCall(
    {enforceAppCheck: true, maxInstances: 3, timeoutSeconds: 25},
    async (request) => {
      const auth = requireVerifiedCloudAccount(request);
      await requireRateLimit({
        scope: "household_delete_day",
        actorUid: auth.uid,
        limit: 10,
        windowMs: DAY_MS,
      }, "Too many Household deletion attempts. Try again later.");

      let householdId = "";
      await db.runTransaction(async (transaction) => {
        const ownerMembership = await transaction.get(membershipRef(auth.uid));
        if (!ownerMembership.exists || ownerMembership.data().role !== "owner") {
          throw new HttpsError(
              "permission-denied",
              "Only the Household owner can delete it.",
          );
        }
        householdId = ownerMembership.data().householdId;
        const home = householdRef(householdId);
        const homeSnapshot = await transaction.get(home);
        if (!homeSnapshot.exists) {
          transaction.delete(membershipRef(auth.uid));
          return;
        }
        const members = householdMembers(homeSnapshot.data());
        if (members.length > 1) {
          throw new HttpsError(
              "failed-precondition",
              "Remove the other Household members or transfer ownership before deleting this Household.",
          );
        }
        transaction.delete(memberRef(householdId, auth.uid));
        transaction.delete(membershipRef(auth.uid));
        transaction.delete(home);
      });

      const invitations = await db.collection("householdInvites")
          .where("householdId", "==", householdId).get();
      if (invitations.docs.length > 0) {
        const batch = db.batch();
        invitations.docs.forEach((document) => batch.delete(document.ref));
        await batch.commit();
      }
      return {deleted: true};
    },
);

async function cleanupDeletedUserHousehold(uid) {
  const myMembership = membershipRef(uid);
  let oldOwnerUid = null;
  await db.runTransaction(async (transaction) => {
    const membership = await transaction.get(myMembership);
    if (!membership.exists) return;
    const householdId = membership.data().householdId;
    const home = householdRef(householdId);
    const homeSnapshot = await transaction.get(home);
    if (!homeSnapshot.exists) {
      transaction.delete(myMembership);
      return;
    }

    const data = homeSnapshot.data();
    oldOwnerUid = data.ownerUid;
    const remaining = householdMembers(data)
        .filter((memberUid) => memberUid !== uid);
    transaction.delete(myMembership);
    transaction.delete(memberRef(householdId, uid));

    if (remaining.length === 0) {
      transaction.delete(home);
      return;
    }

    const update = {
      memberUids: remaining,
      pendingInviteUids: pendingInvitees(data)
          .filter((inviteeUid) => inviteeUid !== uid),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (data.ownerUid === uid) {
      const nextOwnerUid = remaining[0];
      update.ownerUid = nextOwnerUid;
      transaction.set(membershipRef(nextOwnerUid), {
        role: "owner",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(memberRef(householdId, nextOwnerUid), {
        role: "owner",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    transaction.update(home, update);
  });

  await clearOtherIncomingInvites(uid);
  await clearInvitesCreatedBy(uid);
  if (oldOwnerUid && oldOwnerUid !== uid) {
    await setRelationshipScope(oldOwnerUid, uid, "friend");
  }
}

exports.onHomiUserHouseholdDeleted = onDocumentDeleted(
    "users/{uid}",
    async (event) => {
      const uid = event.params.uid;
      try {
        await cleanupDeletedUserHousehold(uid);
      } catch (error) {
        logger.error("Homi Household account-deletion cleanup failed", {
          uid,
          error: error && error.message,
        });
      }
    },
);
