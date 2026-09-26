const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const PROJECT_ID = "homi-ee80a";
const BATCH_SIZE = 200;
const LEGACY_AUDIENCE_VERSION = 0;
const CANONICAL_AUDIENCE_VERSION = 1;
const apply = process.argv.includes("--apply");
const assertStable = process.argv.includes("--assert-stable");

if (apply && assertStable) {
  throw new Error("Choose either --apply or --assert-stable, not both.");
}

initializeApp({projectId: PROJECT_ID});
const db = getFirestore();

function cleanUids(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value
      .filter((uid) => typeof uid === "string" && uid.trim())
      .map((uid) => uid.trim()))].sort();
}

const membershipCache = new Map();
const householdCache = new Map();

async function membershipFor(uid) {
  if (membershipCache.has(uid)) return membershipCache.get(uid);
  const snapshot = await db.collection("householdMemberships").doc(uid).get();
  const data = snapshot.exists ? snapshot.data() : null;
  membershipCache.set(uid, data);
  return data;
}

async function householdFor(householdId) {
  if (householdCache.has(householdId)) return householdCache.get(householdId);
  const snapshot = await db.collection("households").doc(householdId).get();
  const data = snapshot.exists ? snapshot.data() : null;
  householdCache.set(householdId, data);
  return data;
}

function safeAudience(originalMembers, canonicalMembers, audienceVersion) {
  if (audienceVersion === CANONICAL_AUDIENCE_VERSION) {
    return [...canonicalMembers];
  }
  const canonicalSet = new Set(canonicalMembers);
  return originalMembers.filter((uid) => canonicalSet.has(uid));
}

async function planMigration(document) {
  const data = document.data();
  const originalMembers = cleanUids(data.memberUids);
  const storedHouseholdId = typeof data.householdId === "string" ?
    data.householdId.trim() : "";

  let householdId = storedHouseholdId;
  let household = null;
  let audienceVersion = Number(data.audienceVersion) ===
    CANONICAL_AUDIENCE_VERSION ?
      CANONICAL_AUDIENCE_VERSION : LEGACY_AUDIENCE_VERSION;

  if (householdId) {
    household = await householdFor(householdId);
    if (!household) return {status: "failClosedMissingHousehold"};
  } else {
    const creatorUid = typeof data.createdByUid === "string" ?
      data.createdByUid.trim() : "";
    if (!creatorUid) return {status: "failClosedNoCreator"};

    const membership = await membershipFor(creatorUid);
    householdId = membership && typeof membership.householdId === "string" ?
      membership.householdId.trim() : "";
    if (!householdId) return {status: "failClosedNoHousehold"};

    household = await householdFor(householdId);
    if (!household) return {status: "failClosedMissingHousehold"};

    const canonicalMembers = cleanUids(household.memberUids);
    if (!canonicalMembers.includes(creatorUid)) {
      return {status: "failClosedInvalidMembership"};
    }

    // Pre-0.12 root Tasks always become frozen legacy audiences.
    audienceVersion = LEGACY_AUDIENCE_VERSION;
  }

  const canonicalMembers = cleanUids(household.memberUids);
  let memberUids = safeAudience(
      originalMembers,
      canonicalMembers,
      audienceVersion,
  );

  if (!storedHouseholdId) {
    const creatorUid = typeof data.createdByUid === "string" ?
      data.createdByUid.trim() : "";
    if (!memberUids.includes(creatorUid)) memberUids.push(creatorUid);
    memberUids.sort();
  }

  if (memberUids.length === 0) {
    return {status: "failClosedNoSafeAudience"};
  }

  const destination = db.collection("households")
      .doc(householdId)
      .collection("sharedTasks")
      .doc(document.id);
  const destinationSnapshot = await destination.get();
  if (destinationSnapshot.exists) {
    return {status: "destinationConflict"};
  }

  const migrated = {
    ...data,
    householdId,
    audienceVersion,
    memberUids,
    topLevelMigratedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (audienceVersion === LEGACY_AUDIENCE_VERSION) {
    migrated.legacyAudienceMigratedAt = FieldValue.serverTimestamp();
  }

  if (migrated.assigneeUid && !memberUids.includes(migrated.assigneeUid)) {
    migrated.assigneeUid = null;
    migrated.assigneeName = "Unassigned";
  }
  if (migrated.completedByUid &&
      !memberUids.includes(migrated.completedByUid)) {
    migrated.completedByUid = null;
    migrated.completedByName = "Former Household member";
  }

  return {
    status: "migrate",
    source: document.ref,
    destination,
    data: migrated,
  };
}

async function main() {
  const snapshot = await db.collection("sharedTasks").get();
  const counts = {
    totalRootTasks: snapshot.size,
    migrate: 0,
    failClosedNoCreator: 0,
    failClosedNoHousehold: 0,
    failClosedMissingHousehold: 0,
    failClosedInvalidMembership: 0,
    failClosedNoSafeAudience: 0,
    destinationConflict: 0,
  };
  const migrations = [];

  for (const document of snapshot.docs) {
    const plan = await planMigration(document);
    counts[plan.status] = (counts[plan.status] || 0) + 1;
    if (plan.status === "migrate") migrations.push(plan);
  }

  const mode = assertStable ? "ASSERT-STABLE" : apply ? "APPLY" : "DRY-RUN";
  console.log(`Homi root shared-task migration mode: ${mode}`);
  console.log(`Root shared tasks: ${counts.totalRootTasks}`);
  console.log(`Safe root tasks to move: ${counts.migrate}`);
  console.log(`Fail-closed without creator identity: ${counts.failClosedNoCreator}`);
  console.log(`Fail-closed without canonical Household: ${counts.failClosedNoHousehold}`);
  console.log(`Fail-closed with missing Household: ${counts.failClosedMissingHousehold}`);
  console.log(`Fail-closed with inconsistent Household membership: ${counts.failClosedInvalidMembership}`);
  console.log(`Fail-closed without a safe current audience: ${counts.failClosedNoSafeAudience}`);
  console.log(`Destination conflicts: ${counts.destinationConflict}`);

  if (counts.destinationConflict > 0) {
    throw new Error(
        `Migration found ${counts.destinationConflict} nested destination conflict(s); refusing to overwrite them.`,
    );
  }

  if (assertStable) {
    if (migrations.length > 0) {
      throw new Error(
          `Migration is not stable: ${migrations.length} safely movable root task(s) remain.`,
      );
    }
    console.log("Root shared-task migration is stable.");
    return;
  }

  if (!apply || migrations.length === 0) return;

  for (let start = 0; start < migrations.length; start += BATCH_SIZE) {
    const batch = db.batch();
    migrations.slice(start, start + BATCH_SIZE).forEach((migration) => {
      batch.set(migration.destination, migration.data);
      batch.delete(migration.source);
    });
    await batch.commit();
  }

  console.log(`Moved safe root shared tasks into Household subcollections: ${migrations.length}`);
}

main().catch((error) => {
  console.error("Homi root shared-task migration failed:", error && error.message);
  process.exitCode = 1;
});
