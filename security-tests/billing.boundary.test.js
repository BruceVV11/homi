const fs = require("node:fs");
const path = require("node:path");
const {before, beforeEach, after, test} = require("node:test");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc, deleteDoc} = require("firebase/firestore");

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

test("a user can read only their own server-written Homi Plus entitlement", async () => {
  await seed("entitlements/alice", {
    plan: "household",
    state: "active",
    purchaserUid: "alice",
    continuousLocationSender: true,
    sharedHousehold: true,
    maxTrustedLiveViewers: 5,
    householdMemberLimit: 4,
  });

  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();

  await assertSucceeds(getDoc(doc(alice, "entitlements/alice")));
  await assertFails(getDoc(doc(bob, "entitlements/alice")));
  await assertFails(setDoc(doc(alice, "entitlements/alice"), {plan: "household"}));
  await assertFails(updateDoc(doc(alice, "entitlements/alice"), {state: "active"}));
  await assertFails(deleteDoc(doc(alice, "entitlements/alice")));
});

test("purchase tokens and billing account mappings are never client-readable", async () => {
  await seed("billingPurchases/tokenhash", {
    purchaserUid: "alice",
    purchaseToken: "server-secret-token",
    plan: "personal",
    state: "active",
  });
  await seed("billingAccounts/alice", {
    activePurchaseTokenHash: "tokenhash",
  });
  await seed("billingAccountLinks/account-hash", {uid: "alice"});
  await seed("billingCoverage/tokenhash_alicehash", {
    recipientUid: "alice",
    purchaserUid: "alice",
    sourcePurchaseTokenHash: "tokenhash",
    plan: "personal",
    state: "active",
  });

  const alice = env.authenticatedContext("alice").firestore();
  await assertFails(getDoc(doc(alice, "billingPurchases/tokenhash")));
  await assertFails(getDoc(doc(alice, "billingAccounts/alice")));
  await assertFails(getDoc(doc(alice, "billingAccountLinks/account-hash")));
  await assertFails(getDoc(doc(alice, "billingCoverage/tokenhash_alicehash")));
});
