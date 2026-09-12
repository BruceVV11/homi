const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");

const db = getFirestore();
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const COMPLETED_TASK_RETENTION_MS = 48 * HOUR_MS;
const CANONICAL_AUDIENCE_VERSION = 1;

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

async function displayNameFor(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  const name = snapshot.data() && snapshot.data().displayName;
  return typeof name === "string" && name.trim() ? name.trim() : "Someone";
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

async function canonicalHouseholdFor(uid) {
  const membership = await db.collection("householdMemberships").doc(uid).get();
  if (!membership.exists) return null;
  const householdId = membership.data().householdId;
  if (typeof householdId !== "string" || !householdId) return null;
  const household = await db.collection("households").doc(householdId).get();
  if (!household.exists) return null;
  const memberUids = household.data().memberUids;
  if (!Array.isArray(memberUids) || !memberUids.includes(uid)) return null;
  return {
    id: householdId,
    data: household.data(),
    memberUids: [...new Set(memberUids
        .filter((value) => typeof value === "string" && value.trim())
        .map((value) => value.trim()))],
  };
}

async function sharedTaskAccessContext(uid, data) {
  if (!data || !Array.isArray(data.memberUids) || !data.memberUids.includes(uid)) {
    return null;
  }
  const storedHouseholdId = typeof data.householdId === "string" ?
    data.householdId.trim() : "";
  if (!storedHouseholdId) return null;

  // A shared Task belongs to the canonical Household, not permanently to the
  // account that happened to create it. This keeps a Task usable by its safe
  // remaining audience after the creator leaves while still requiring the
  // acting account to be a current canonical member of that exact Household.
  const actorHousehold = await canonicalHouseholdFor(uid);
  if (!actorHousehold || actorHousehold.id !== storedHouseholdId) return null;
  return actorHousehold;
}

// Keep the historic callable names so existing app clients continue to work.
// The security boundary changes from a user-editable People preference to the
// canonical Shared Household created in 0.11.
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
        cleanRequiredString(
            request.data.assigneeUid,
            128,
            "Choose a valid assignee.",
        ) : null;
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
          throw new HttpsError(
              "invalid-argument",
              "Choose a valid task due time.",
          );
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

      const household = await canonicalHouseholdFor(creatorUid);
      if (!household) {
        throw new HttpsError(
            "failed-precondition",
            "Create or join a Shared Household before sharing a household task.",
        );
      }
      const memberUids = household.memberUids.sort();
      if (memberUids.length < 2) {
        throw new HttpsError(
            "failed-precondition",
            "Add at least one person to your Shared Household before sharing a household task.",
        );
      }
      if (assigneeUid && !memberUids.includes(assigneeUid)) {
        throw new HttpsError(
            "failed-precondition",
            "That person must join your Shared Household before a household task can be assigned to them.",
        );
      }

      const creatorName = displayNameFromAuth(auth);
      const assigneeName = assigneeUid ? await displayNameFor(assigneeUid) : null;
      const ref = db.collection("sharedTasks").doc();
      await ref.create({
        householdId: household.id,
        audienceVersion: CANONICAL_AUDIENCE_VERSION,
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
        throw new HttpsError(
            "not-found",
            "That household task is no longer available.",
        );
      }
      const data = snapshot.data();
      const household = await sharedTaskAccessContext(auth.uid, data);
      if (!household) {
        throw new HttpsError(
            "permission-denied",
            "That household task is not available to your account.",
        );
      }
      const isHouseholdOwner = household.data.ownerUid === auth.uid;

      if (data.completedAt) {
        if (data.createdByUid !== auth.uid &&
            data.completedByUid !== auth.uid &&
            !isHouseholdOwner) {
          throw new HttpsError(
              "permission-denied",
              "Only the person who completed this task, its creator, or the Household owner can reopen it.",
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
      const household = await sharedTaskAccessContext(auth.uid, data);
      if (!household) {
        throw new HttpsError(
            "permission-denied",
            "That household task is not available to your account.",
        );
      }
      const isHouseholdOwner = household.data.ownerUid === auth.uid;
      const purgeAtMs = data.purgeAt &&
          typeof data.purgeAt.toMillis === "function" ?
        data.purgeAt.toMillis() : 0;
      if (data.createdByUid !== auth.uid &&
          !isHouseholdOwner &&
          (!purgeAtMs || purgeAtMs > Date.now())) {
        throw new HttpsError(
            "permission-denied",
            "Only the person who created this task or the Household owner can remove it before its completed-history period ends.",
        );
      }
      await ref.delete();
      return {removed: true};
    },
);
