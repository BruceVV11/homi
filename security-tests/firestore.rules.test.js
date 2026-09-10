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
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
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

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

async function seed(pathName, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), pathName), data);
  });
}

async function seedAcceptedConnection(aUid = "alice", bUid = "bob") {
  const ids = [aUid, bUid].sort();
  await seed(`connections/${ids[0]}_${ids[1]}`, {
    memberUids: ids,
    initiatorUid: ids[0],
    recipientUid: ids[1],
    status: "accepted",
    aUid: ids[0],
    aName: "Alice",
    aPhotoUrl: null,
    bUid: ids[1],
    bName: "Bob",
    bPhotoUrl: null,
    createdAt: Timestamp.now(),
    acceptedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}

test("location is private unless an active accepted share exists", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  const anonymous = env.unauthenticatedContext().firestore();

  const location = {
    latitude: -29.86,
    longitude: 31.02,
    accuracyMeters: 15.5,
    batteryPercent: 72,
    isCharging: false,
    updatedAt: serverTimestamp(),
    source: "foreground_refresh",
  };

  await assertSucceeds(setDoc(doc(alice, "locations/alice"), location));
  await assertFails(getDoc(doc(anonymous, "locations/alice")));
  await assertFails(getDoc(doc(bob, "locations/alice")));

  await seedAcceptedConnection();
  await seed("locationShares/alice/viewers/bob", {
    ownerUid: "alice",
    viewerUid: "bob",
    active: true,
    updatedAt: Timestamp.now(),
  });

  await assertSucceeds(getDoc(doc(bob, "locations/alice")));
});

test("location rejects unexpected fields and invalid bounds", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const base = {
    latitude: -29.86,
    longitude: 31.02,
    accuracyMeters: 12,
    batteryPercent: 80,
    isCharging: true,
    updatedAt: serverTimestamp(),
    source: "continuous_start",
  };

  await assertFails(setDoc(doc(alice, "locations/alice"), {
    ...base,
    hiddenHistory: ["not allowed"],
  }));
  await assertFails(setDoc(doc(alice, "locations/alice"), {
    ...base,
    latitude: 123,
  }));
});

test("connection create requires the deterministic participant document", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const payload = {
    memberUids: ["alice", "bob"],
    initiatorUid: "alice",
    recipientUid: "bob",
    status: "pending",
    aUid: "alice",
    aName: "Alice",
    aPhotoUrl: null,
    bUid: "bob",
    bName: "Bob",
    bPhotoUrl: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  await assertSucceeds(setDoc(doc(alice, "connections/alice_bob"), payload));
  await assertFails(setDoc(doc(alice, "connections/random_duplicate"), payload));
});

test("only the invited recipient can accept and only acceptance fields change", async () => {
  await seed("connections/alice_bob", {
    memberUids: ["alice", "bob"],
    initiatorUid: "alice",
    recipientUid: "bob",
    status: "pending",
    aUid: "alice",
    aName: "Alice",
    aPhotoUrl: null,
    bUid: "bob",
    bName: "Bob",
    bPhotoUrl: null,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });

  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();

  await assertFails(updateDoc(doc(alice, "connections/alice_bob"), {
    status: "accepted",
    acceptedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(bob, "connections/alice_bob"), {
    status: "accepted",
    acceptedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test("shared task completion cannot impersonate another member", async () => {
  const now = Timestamp.now();
  await seed("sharedTasks/task1", {
    title: "Feed the dogs",
    notes: null,
    assigneeUid: "bob",
    assigneeName: "Bob",
    createdByUid: "alice",
    createdByName: "Alice",
    memberUids: ["alice", "bob"],
    createdAt: now,
    dueAt: null,
    completedAt: null,
    completedByName: null,
    completedByUid: null,
    purgeAt: null,
  });

  const bob = env.authenticatedContext("bob").firestore();
  const purgeAt = Timestamp.fromMillis(Date.now() + 48 * 60 * 60 * 1000);

  await assertFails(updateDoc(doc(bob, "sharedTasks/task1"), {
    completedAt: serverTimestamp(),
    completedByName: "Alice",
    completedByUid: "alice",
    purgeAt,
    updatedAt: serverTimestamp(),
  }));

  await assertSucceeds(updateDoc(doc(bob, "sharedTasks/task1"), {
    completedAt: serverTimestamp(),
    completedByName: "Bob",
    completedByUid: "bob",
    purgeAt,
    updatedAt: serverTimestamp(),
  }));
});

test("active shared task cannot be deleted by a non-creator member", async () => {
  await seed("sharedTasks/task1", {
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

  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  await assertFails(deleteDoc(doc(bob, "sharedTasks/task1")));
  await assertSucceeds(deleteDoc(doc(alice, "sharedTasks/task1")));
});

test("developer campaigns require server-provisioned admin and exact schema", async () => {
  await seed("developerAdmins/alice", {active: true, role: "developer"});
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  const payload = {
    title: "Homi test",
    body: "A controlled test notice.",
    category: "update",
    route: "overview",
    audience: "self",
    priority: "normal",
    createdByUid: "alice",
    status: "queued",
    createdAt: serverTimestamp(),
  };

  await assertSucceeds(
      setDoc(doc(alice, "notificationCampaigns/valid"), payload),
  );
  await assertFails(
      setDoc(doc(bob, "notificationCampaigns/not-admin"), {
        ...payload,
        createdByUid: "bob",
      }),
  );
  await assertFails(
      setDoc(doc(alice, "notificationCampaigns/extra-field"), {
        ...payload,
        arbitraryAdminField: true,
      }),
  );
});

test("server rate limits cannot be read or written by clients", async () => {
  await seed("serverRateLimits/heart_day_alice", {
    scope: "heart_day",
    actorUid: "alice",
    windowStartMs: Date.now(),
    count: 1,
  });
  const alice = env.authenticatedContext("alice").firestore();
  await assertFails(getDoc(doc(alice, "serverRateLimits/heart_day_alice")));
  await assertFails(setDoc(doc(alice, "serverRateLimits/fake"), {
    actorUid: "alice",
    count: 0,
  }));
});

test("device registration rejects arbitrary client fields", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const valid = {
    pushToken: "token",
    platform: "android",
    notificationsEnabled: true,
    householdAttention: true,
    tasksAndRoutines: true,
    peopleNotifications: true,
    homiUpdates: false,
    serviceNotices: true,
    updatedAt: serverTimestamp(),
  };

  await assertSucceeds(setDoc(doc(alice, "users/alice/devices/device1"), valid));
  await assertFails(setDoc(doc(alice, "users/alice/devices/device2"), {
    ...valid,
    admin: true,
  }));
  const saved = await assertSucceeds(
      getDoc(doc(alice, "users/alice/devices/device1")),
  );
  assert.equal(saved.data().notificationsEnabled, true);
});
