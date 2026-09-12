const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const PROJECT_ID = "homi-ee80a";
const BATCH_SIZE = 400;
const LEGACY_AUDIENCE_VERSION = 0;
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
      .map((uid) => uid.trim()))];
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

async function planMigration(document) {
  const data = document.data();
  if (typeof data.householdId === "string" && data.householdId.trim()) {
    return {status: "alreadyCanonical"};
  }

  const creatorUid = typeof data.createdByUid === "string" ?
    data.createdByUid.trim() : "";
  if (!creatorUid) return {status: "failClosedNoCreator"};

  const membership = await membershipFor(creatorUid);
  const householdId = membership && typeof membership.householdId === "string" ?
    membership.householdId.trim() : "";
  if (!householdId) return {status: "failClosedNoHousehold"};

  const household = await householdFor(householdId);
  const canonicalMembers = cleanUids(household && household.memberUids);
  if (!canonicalMembers.includes(creatorUid)) {
    return {status: "failClosedInvalidMembership"};
  }

  const canonicalSet = new Set(canonicalMembers);
  const originalMembers = cleanUids(data.memberUids);
  const safeMembers = originalMembers.filter((uid) => canonicalSet.has(uid));
  if (!safeMembers.includes(creatorUid)) safeMembers.push(creatorUid);
  safeMembers.sort();

  const update = {
    householdId,
    audienceVersion: LEGACY_AUDIENCE_VERSION,
    memberUids: safeMembers,
    legacyAudienceMigratedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (data.assigneeUid && !safeMembers.includes(data.assigneeUid)) {
    update.assigneeUid = null;
    update.assigneeName = "Unassigned";
  }
  if (data.completedByUid && !safeMembers.includes(data.completedByUid)) {
    update.completedByUid = null;
    update.completedByName = "Former Household member";
  }

  return {status: "migrate", update};
}

async function main() {
  const snapshot = await db.collection("sharedTasks").get();
  const counts = {
    total: snapshot.size,
    alreadyCanonical: 0,
    migrate: 0,
    failClosedNoCreator: 0,
    failClosedNoHousehold: 0,
    failClosedInvalidMembership: 0,
  };
  const migrations = [];

  for (const document of snapshot.docs) {
    const plan = await planMigration(document);
    counts[plan.status] = (counts[plan.status] || 0) + 1;
    if (plan.status === "migrate") {
      migrations.push({ref: document.ref, update: plan.update});
    }
  }

  const mode = assertStable ? "ASSERT-STABLE" : apply ? "APPLY" : "DRY-RUN";
  console.log(`Homi legacy shared-task migration mode: ${mode}`);
  console.log(`Total shared tasks: ${counts.total}`);
  console.log(`Already canonical: ${counts.alreadyCanonical}`);
  console.log(`Safe legacy tasks to migrate: ${counts.migrate}`);
  console.log(`Fail-closed without creator identity: ${counts.failClosedNoCreator}`);
  console.log(`Fail-closed without canonical Household: ${counts.failClosedNoHousehold}`);
  console.log(`Fail-closed with inconsistent Household membership: ${counts.failClosedInvalidMembership}`);

  if (assertStable) {
    if (migrations.length > 0) {
      throw new Error(
          `Migration is not stable: ${migrations.length} safely migratable legacy task(s) remain.`,
      );
    }
    console.log("Legacy shared-task migration is stable.");
    return;
  }

  if (!apply || migrations.length === 0) return;

  for (let start = 0; start < migrations.length; start += BATCH_SIZE) {
    const batch = db.batch();
    migrations.slice(start, start + BATCH_SIZE).forEach((migration) => {
      batch.update(migration.ref, migration.update);
    });
    await batch.commit();
  }

  console.log(`Applied safe legacy shared-task migrations: ${migrations.length}`);
}

main().catch((error) => {
  console.error("Homi legacy shared-task migration failed:", error && error.message);
  process.exitCode = 1;
});
