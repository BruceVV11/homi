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
  updateDoc,
  deleteDoc,
  serverTimestamp,
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

async function seedHousehold() {
  await seed("households/home1", {
    name: "Durban Home",
    ownerUid: "alice",
    memberUids: ["alice", "bob"],
    pendingInviteUids: ["charlie"],
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
  await seed("households/home1/members/alice", {
    uid: "alice",
    role: "owner",
    displayName: "Alice",
    photoUrl: null,
    joinedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await seed("households/home1/members/bob", {
    uid: "bob",
    role: "member",
    displayName: "Bob",
    photoUrl: null,
    joinedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}

async function seedInvite() {
  await seed("householdInvites/home1_charlie", {
    householdId: "home1",
    householdName: "Durban Home",
    inviterUid: "alice",
    inviterName: "Alice",
    inviteeUid: "charlie",
    inviteeName: "Charlie",
    inviteePhotoUrl: null,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}

test("members can query their Household without exposing non-members", async () => {
  await seedHousehold();
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();

  await assertSucceeds(getDoc(doc(alice, "households/home1")));
  await assertSucceeds(getDoc(doc(bob, "households/home1")));
  await assertFails(getDoc(doc(mallory, "households/home1")));

  const visible = await assertSucceeds(getDocs(query(
      collection(bob, "households"),
      where("memberUids", "array-contains", "bob"),
  )));
  assert.equal(visible.size, 1);

  await assertFails(getDocs(collection(bob, "households")));

  const outsiderVisible = await assertSucceeds(getDocs(query(
      collection(mallory, "households"),
      where("memberUids", "array-contains", "mallory"),
  )));
  assert.equal(outsiderVisible.size, 0);

  await assertFails(getDocs(query(
      collection(mallory, "households"),
      where("memberUids", "array-contains", "bob"),
  )));
});

test("membership documents are self-readable and server-only", async () => {
  await seedHousehold();
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();

  await assertSucceeds(getDoc(doc(alice, "householdMemberships/alice")));
  await assertFails(getDoc(doc(alice, "householdMemberships/bob")));
  await assertFails(getDocs(collection(alice, "householdMemberships")));
  await assertFails(updateDoc(doc(alice, "householdMemberships/alice"), {
    role: "member",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(alice, "householdMemberships/forged"), {
    householdId: "home1",
    role: "owner",
    joinedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test("Household member directory is visible only to current members", async () => {
  await seedHousehold();
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();

  const members = await assertSucceeds(getDocs(
      collection(bob, "households/home1/members"),
  ));
  assert.equal(members.size, 2);
  await assertSucceeds(getDoc(doc(alice, "households/home1/members/bob")));
  await assertFails(getDoc(doc(mallory, "households/home1/members/bob")));
  await assertFails(updateDoc(doc(alice, "households/home1/members/bob"), {
    role: "owner",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(alice, "households/home1/members/bob")));
});

test("invitee and current owner can query Household invitations", async () => {
  await seedHousehold();
  await seedInvite();
  const alice = env.authenticatedContext("alice").firestore();
  const charlie = env.authenticatedContext("charlie").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();

  const incoming = await assertSucceeds(getDocs(query(
      collection(charlie, "householdInvites"),
      where("inviteeUid", "==", "charlie"),
  )));
  assert.equal(incoming.size, 1);

  const outgoing = await assertSucceeds(getDocs(query(
      collection(alice, "householdInvites"),
      where("inviterUid", "==", "alice"),
  )));
  assert.equal(outgoing.size, 1);

  await assertFails(getDoc(doc(mallory, "householdInvites/home1_charlie")));
  await assertFails(getDocs(collection(alice, "householdInvites")));
});

test("Household identity and invitation mutations remain server-only", async () => {
  await seedHousehold();
  await seedInvite();
  const alice = env.authenticatedContext("alice").firestore();
  const charlie = env.authenticatedContext("charlie").firestore();

  await assertFails(updateDoc(doc(alice, "households/home1"), {
    name: "Forged",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(alice, "households/home1")));
  await assertFails(setDoc(doc(alice, "households/forged"), {
    name: "Forged",
    ownerUid: "alice",
    memberUids: ["alice"],
    pendingInviteUids: [],
    memberLimit: 4,
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(
      doc(charlie, "householdInvites/home1_charlie"),
      {inviteeName: "Forged", updatedAt: serverTimestamp()},
  ));
  await assertFails(deleteDoc(
      doc(charlie, "householdInvites/home1_charlie"),
  ));
});
