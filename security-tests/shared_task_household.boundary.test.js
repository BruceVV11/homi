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

async function seedHousehold(memberUids = ["alice", "bob"]) {
  await seed("households/home1", {
    name: "Durban Home",
    ownerUid: "alice",
    memberUids,
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
  await seed("households/home1/sharedTasks/task1", {
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

test("canonical Household task query requires Household path and recipient audience", async () => {
  await seedHousehold();
  await seedCanonicalTask();

  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();

  await assertSucceeds(getDoc(
      doc(bob, "households/home1/sharedTasks/task1"),
  ));
  await assertFails(getDoc(
      doc(mallory, "households/home1/sharedTasks/task1"),
  ));

  const visible = await assertSucceeds(getDocs(query(
      collection(bob, "households/home1/sharedTasks"),
      where("memberUids", "array-contains", "bob"),
  )));
  assert.equal(visible.size, 1);

  // Firestore rules are not filters. The nested Household path supplies the
  // canonical scope, while the exact recipient constraint is still required.
  await assertFails(getDocs(
      collection(bob, "households/home1/sharedTasks"),
  ));

  await assertFails(getDocs(query(
      collection(mallory, "households/home1/sharedTasks"),
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

  // A stale membership pointer alone is insufficient if the canonical
  // Household parent has already removed this user.
  await seedHousehold(["alice"]);
  await assertFails(getDoc(doc(bob, "households/home1/sharedTasks/task1")));
  await assertFails(getDocs(query(
      collection(bob, "households/home1/sharedTasks"),
      where("memberUids", "array-contains", "bob"),
  )));

  // Restore the parent list, then prove the inverse stale state also fails:
  // parent membership alone is insufficient after the pointer is removed.
  await seedHousehold();
  await removeSeed("householdMemberships/bob");
  await assertFails(getDoc(doc(bob, "households/home1/sharedTasks/task1")));
  await assertFails(getDocs(query(
      collection(bob, "households/home1/sharedTasks"),
      where("memberUids", "array-contains", "bob"),
  )));
});
