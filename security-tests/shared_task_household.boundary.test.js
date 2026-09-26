const fs = require("node:fs");
const path = require("node:path");
const {before, beforeEach, after, test} = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  deleteDoc,
  Timestamp,
  where,
} = require("firebase/firestore");

let env;

before(async () => {
  const rules = fs.readFileSync(
      path.resolve(__dirname, "../firebase/firestore.rules"),
      "utf8",
  );
  env = await initializeTestEnvironment({
    projectId: "homi-ee80a",
    firestore: {rules},
  });
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

async function seed(pathName, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), pathName), data);
  });
}

async function removeSeed(pathName) {
  await env.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), pathName));
  });
}

async function seedHousehold() {
  await seed("households/home1", {
    name: "Durban Home",
    ownerUid: "alice",
    memberUids: ["alice", "bob"],
    pendingInviteUids: [],
    memberLimit: 4,
    schemaVersion: 1,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await seed("householdMemberships/alice", {
    householdId: "home1",
    role: "owner",
    joinedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await seed("householdMemberships/bob", {
    householdId: "home1",
    role: "member",
    joinedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}

async function seedCanonicalTask() {
  await seed("sharedTasks/task1", {
    householdId: "home1",
    audienceVersion: 1,
    title: "Take bins out",
    notes: null,
    assigneeUid: "bob",
    assigneeName: "Bob",
    createdByUid: "alice",
    createdByName: "Alice",
    memberUids: ["alice", "bob"],
    createdAt: Timestamp.now(),
    dueAt: null,
    completedAt: null,
    completedByName: null,
    completedByUid: null,
    purgeAt: null,
  });
}

test("canonical Household task query requires both Household and recipient constraints", async () => {
  await seedHousehold();
  await seedCanonicalTask();

  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();

  await assertSucceeds(getDoc(doc(bob, "sharedTasks/task1")));
  await assertFails(getDoc(doc(mallory, "sharedTasks/task1")));

  const visible = await assertSucceeds(getDocs(query(
      collection(bob, "sharedTasks"),
      where("householdId", "==", "home1"),
      where("memberUids", "array-contains", "bob"),
  )));
  assert.equal(visible.size, 1);

  // Firestore rules are not filters. Omitting householdId must fail rather than
  // allowing memberUids alone to recreate the pre-0.12 trust boundary.
  await assertFails(getDocs(query(
      collection(bob, "sharedTasks"),
      where("memberUids", "array-contains", "bob"),
  )));

  await assertFails(getDocs(query(
      collection(mallory, "sharedTasks"),
      where("householdId", "==", "home1"),
      where("memberUids", "array-contains", "mallory"),
  )));
});

test("legacy or stale shared Tasks fail closed outside canonical membership", async () => {
  await seedHousehold();
  await seedCanonicalTask();
  await seed("sharedTasks/legacy", {
    title: "Old preference task",
    createdByUid: "alice",
    createdByName: "Alice",
    memberUids: ["alice", "bob"],
    createdAt: Timestamp.now(),
  });

  const bob = env.authenticatedContext("bob").firestore();
  await assertFails(getDoc(doc(bob, "sharedTasks/legacy")));

  await removeSeed("householdMemberships/bob");
  await assertFails(getDoc(doc(bob, "sharedTasks/task1")));
  await assertFails(getDocs(query(
      collection(bob, "sharedTasks"),
      where("householdId", "==", "home1"),
      where("memberUids", "array-contains", "bob"),
  )));
});
