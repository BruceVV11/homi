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

async function acceptedConnection(a = "alice", b = "bob") {
  const ids = [a, b].sort();
  const aUid = ids[0];
  const bUid = ids[1];
  await seed(`connections/${aUid}_${bUid}`, {
    memberUids: ids,
    initiatorUid: a,
    recipientUid: b,
    status: "accepted",
    aUid,
    aName: aUid === "alice" ? "Alice" : "Homi user",
    aPhotoUrl: null,
    bUid,
    bName: bUid === "bob" ? "Bob" : "Homi user",
    bPhotoUrl: null,
    createdAt: Timestamp.now(),
    acceptedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
}

function validLocation() {
  return {
    latitude: -29.86,
    longitude: 31.02,
    accuracyMeters: 12,
    batteryPercent: 80,
    isCharging: false,
    updatedAt: serverTimestamp(),
    source: "foreground_refresh",
  };
}

test("owner location write is allowed but foreign write and delete are denied", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  await assertSucceeds(setDoc(doc(alice, "locations/alice"), validLocation()));
  await assertFails(setDoc(doc(bob, "locations/alice"), validLocation()));
  await assertFails(deleteDoc(doc(alice, "locations/alice")));
});

test("location update minimum interval blocks rapid repeat writes", async () => {
  await seed("locations/alice", {
    latitude: -29.86,
    longitude: 31.02,
    accuracyMeters: 12,
    batteryPercent: 80,
    isCharging: false,
    updatedAt: Timestamp.fromMillis(Date.now() - 60 * 1000),
    source: "continuous_foreground_service",
  });
  const alice = env.authenticatedContext("alice").firestore();
  await assertSucceeds(updateDoc(doc(alice, "locations/alice"), {
    ...validLocation(),
    latitude: -29.861,
  }));
  await assertFails(updateDoc(doc(alice, "locations/alice"), {
    ...validLocation(),
    latitude: -29.862,
  }));
});

test("trusted location read requires accepted connection and active share", async () => {
  const bob = env.authenticatedContext("bob").firestore();
  await seed("locations/alice", {
    latitude: -29.86,
    longitude: 31.02,
    accuracyMeters: 12,
    batteryPercent: 80,
    isCharging: false,
    updatedAt: Timestamp.now(),
    source: "continuous_foreground_service",
  });
  await assertFails(getDoc(doc(bob, "locations/alice")));
  await acceptedConnection();
  await seed("locationShares/alice/viewers/bob", {
    ownerUid: "alice",
    viewerUid: "bob",
    active: true,
    updatedAt: Timestamp.now(),
  });
  await assertSucceeds(getDoc(doc(bob, "locations/alice")));
});

test("identity and Homi code mutations cannot be performed by clients", async () => {
  const alice = env.authenticatedContext("alice").firestore();
  await seed("users/alice", {
    homiCode: "ABC234",
    displayName: "Alice",
    photoUrl: null,
    updatedAt: Timestamp.now(),
  });
  await assertSucceeds(getDoc(doc(alice, "users/alice")));
  await assertFails(updateDoc(doc(alice, "users/alice"), {
    displayName: "Changed directly",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(alice, "homiCodes/ABC234")));
  await assertFails(setDoc(doc(alice, "homiCodes/ABC234"), {
    uid: "alice",
    displayName: "Alice",
    updatedAt: serverTimestamp(),
  }));
});

test("connection mutations are server-only while members can read", async () => {
  await acceptedConnection();
  const alice = env.authenticatedContext("alice").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();
  await assertSucceeds(getDoc(doc(alice, "connections/alice_bob")));
  await assertFails(getDoc(doc(mallory, "connections/alice_bob")));
  await assertFails(deleteDoc(doc(alice, "connections/alice_bob")));
  await assertFails(updateDoc(doc(alice, "connections/alice_bob"), {
    status: "pending",
    updatedAt: serverTimestamp(),
  }));
});

test("connection participant queries remain usable without exposing other users", async () => {
  await acceptedConnection("alice", "bob");
  await acceptedConnection("alice", "charlie");
  await acceptedConnection("bob", "charlie");
  const alice = env.authenticatedContext("alice").firestore();
  const asA = await assertSucceeds(getDocs(query(
      collection(alice, "connections"),
      where("aUid", "==", "alice"),
  )));
  assert.equal(asA.size, 2);
  await assertFails(getDocs(collection(alice, "connections")));
});

test("preference and location-share mutations are server-only", async () => {
  await acceptedConnection();
  await seed("peoplePreferences/alice/people/bob", {
    relationship: "Partner",
    scope: "household",
    updatedAt: Timestamp.now(),
  });
  await seed("locationShares/alice/viewers/bob", {
    ownerUid: "alice",
    viewerUid: "bob",
    active: true,
    updatedAt: Timestamp.now(),
  });
  const alice = env.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(alice, "peoplePreferences/alice/people/bob")));
  await assertSucceeds(getDoc(doc(alice, "locationShares/alice/viewers/bob")));
  await assertFails(updateDoc(doc(alice, "peoplePreferences/alice/people/bob"), {
    scope: "friend",
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(alice, "locationShares/alice/viewers/bob"), {
    active: false,
    updatedAt: serverTimestamp(),
  }));
});

test("shared tasks are member-readable but client mutations are blocked", async () => {
  await seed("sharedTasks/task1", {
    title: "Feed the dogs",
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
  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();
  await assertSucceeds(getDoc(doc(bob, "sharedTasks/task1")));
  await assertFails(getDoc(doc(mallory, "sharedTasks/task1")));
  await assertFails(updateDoc(doc(bob, "sharedTasks/task1"), {
    completedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(bob, "sharedTasks/task1")));
});

test("shared task membership query remains usable and unfiltered list is denied", async () => {
  await seed("sharedTasks/task1", {
    title: "Feed the dogs",
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
  await seed("sharedTasks/task2", {
    title: "Private other household task",
    notes: null,
    assigneeUid: "mallory",
    assigneeName: "Mallory",
    createdByUid: "charlie",
    createdByName: "Charlie",
    memberUids: ["charlie", "mallory"],
    createdAt: Timestamp.now(),
    dueAt: null,
    completedAt: null,
    completedByName: null,
    completedByUid: null,
    purgeAt: null,
  });
  const bob = env.authenticatedContext("bob").firestore();
  const visible = await assertSucceeds(getDocs(query(
      collection(bob, "sharedTasks"),
      where("memberUids", "array-contains", "bob"),
  )));
  assert.equal(visible.size, 1);
  await assertFails(getDocs(collection(bob, "sharedTasks")));
});

test("developer campaign creation and admin mutation are server-only", async () => {
  await seed("developerAdmins/alice", {active: true, role: "developer"});
  await seed("notificationCampaigns/c1", {
    title: "Test",
    body: "Test body",
    category: "update",
    route: "overview",
    audience: "self",
    priority: "normal",
    createdByUid: "alice",
    status: "sent",
    createdAt: Timestamp.now(),
  });
  const alice = env.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(alice, "developerAdmins/alice")));
  await assertSucceeds(getDoc(doc(alice, "notificationCampaigns/c1")));
  await assertFails(setDoc(doc(alice, "developerAdmins/bob"), {active: true}));
  await assertFails(setDoc(doc(alice, "notificationCampaigns/forged"), {
    title: "Forged",
    body: "Client path",
    category: "security",
    route: "overview",
    audience: "all",
    priority: "important",
    createdByUid: "alice",
    status: "queued",
    createdAt: serverTimestamp(),
  }));
});

test("push device records are owner-readable but registration/removal are server-only", async () => {
  await seed("users/alice/devices/device1", {
    pushToken: "token",
    platform: "android",
    notificationsEnabled: true,
    householdAttention: true,
    tasksAndRoutines: true,
    peopleNotifications: true,
    homiUpdates: false,
    serviceNotices: true,
    updatedAt: Timestamp.now(),
  });
  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  await assertSucceeds(getDoc(doc(alice, "users/alice/devices/device1")));
  await assertFails(getDoc(doc(bob, "users/alice/devices/device1")));
  await assertFails(setDoc(doc(alice, "users/alice/devices/device2"), {
    pushToken: "forged",
    platform: "android",
    notificationsEnabled: true,
    householdAttention: true,
    tasksAndRoutines: true,
    peopleNotifications: true,
    homiUpdates: false,
    serviceNotices: true,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(alice, "users/alice/devices/device1")));
});

test("server-only rate-limit records remain inaccessible", async () => {
  await seed("serverRateLimits/test_alice", {
    scope: "test",
    actorUid: "alice",
    windowStartMs: Date.now(),
    count: 1,
  });
  const alice = env.authenticatedContext("alice").firestore();
  await assertFails(getDoc(doc(alice, "serverRateLimits/test_alice")));
  await assertFails(setDoc(doc(alice, "serverRateLimits/forged"), {
    actorUid: "alice",
    count: 0,
  }));
});
