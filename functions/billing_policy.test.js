"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizePlayState,
  effectivePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  householdRecipientUids,
  projectEntitlementSources,
  canAdoptCanonicalPurchase,
  configuredCatalog,
  productFor,
} = require("./billing_policy");

test("active grace and unexpired canceled states grant paid access", () => {
  assert.equal(normalizePlayState("SUBSCRIPTION_STATE_ACTIVE"), "active");
  assert.equal(
      normalizePlayState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"),
      "grace_period",
  );
  assert.equal(grantsPaidAccess("active"), true);
  assert.equal(grantsPaidAccess("grace_period"), true);
  assert.equal(grantsPaidAccess("canceled"), true);
  assert.equal(grantsPaidAccess("on_hold"), false);
  assert.equal(grantsPaidAccess("expired"), false);
});

test("paid lifecycle state requires a future verified paid-through time", () => {
  const now = Date.parse("2026-09-12T00:00:00Z");
  assert.equal(
      effectivePlayState("active", "2026-09-13T00:00:00Z", now),
      "active",
  );
  assert.equal(
      effectivePlayState("grace_period", "2026-09-13T00:00:00Z", now),
      "grace_period",
  );
  assert.equal(
      effectivePlayState("canceled", "2026-09-13T00:00:00Z", now),
      "canceled",
  );
  assert.equal(effectivePlayState("active", null, now), "expired");
  assert.equal(
      effectivePlayState("canceled", "2026-09-11T00:00:00Z", now),
      "expired",
  );
});

test("privacy exits are not represented as paid capabilities", () => {
  const free = entitlementCapabilities("free", "active");
  const expiredHousehold = entitlementCapabilities("household", "expired", 10);
  assert.deepEqual(free, {
    continuousLocationSender: false,
    sharedTasks: false,
    sharedRoutines: false,
    sharedHousehold: false,
    maxTrustedLiveViewers: 0,
    householdMemberLimit: 0,
  });
  assert.deepEqual(expiredHousehold, free);
});

test("Personal and Duo include shared Tasks and Routines but not Household workspace", () => {
  const personal = entitlementCapabilities("personal", "active");
  const duo = entitlementCapabilities("duo", "active");
  assert.equal(personal.continuousLocationSender, true);
  assert.equal(personal.sharedTasks, true);
  assert.equal(personal.sharedRoutines, true);
  assert.equal(personal.sharedHousehold, false);
  assert.equal(personal.maxTrustedLiveViewers, 3);
  assert.deepEqual(duo, personal);
});

test("Household member tier controls paid member limit", () => {
  const household = entitlementCapabilities("household", "active", 6);
  assert.equal(household.continuousLocationSender, true);
  assert.equal(household.sharedTasks, true);
  assert.equal(household.sharedRoutines, true);
  assert.equal(household.sharedHousehold, true);
  assert.equal(household.maxTrustedLiveViewers, 3);
  assert.equal(household.householdMemberLimit, 6);
});

test("Household coverage always includes the purchaser without exceeding paid capacity", () => {
  const covered = householdRecipientUids(
      ["owner", "member-a", "member-b", "payer", "member-c", "member-d"],
      "payer",
      4,
  );

  assert.deepEqual(covered, ["payer", "owner", "member-a", "member-b"]);
  assert.equal(covered.length, 4);
});

test("multiple subscription sources combine without one purchase deleting another", () => {
  const projected = projectEntitlementSources([
    {
      plan: "personal",
      state: "active",
      validUntil: "2099-01-01T00:00:00Z",
      purchaserUid: "alice",
      sourcePurchaseTokenHash: "personal-token",
      seatRole: "purchaser",
    },
    {
      plan: "household",
      state: "grace_period",
      validUntil: "2099-01-01T00:00:00Z",
      purchaserUid: "bob",
      sourcePurchaseTokenHash: "household-token",
      seatRole: "household_member",
      householdId: "home1",
      householdMemberLimit: 6,
    },
  ]);

  assert.equal(projected.plan, "household");
  assert.equal(projected.state, "grace_period");
  assert.equal(projected.continuousLocationSender, true);
  assert.equal(projected.sharedTasks, true);
  assert.equal(projected.sharedRoutines, true);
  assert.equal(projected.sharedHousehold, true);
  assert.equal(projected.maxTrustedLiveViewers, 3);
  assert.equal(projected.householdMemberLimit, 6);
  assert.equal(projected.sourceCount, 2);
});

test("inactive coverage cannot override a separate active subscription", () => {
  const projected = projectEntitlementSources([
    {
      plan: "household",
      state: "expired",
      purchaserUid: "bob",
      sourcePurchaseTokenHash: "expired-household",
      seatRole: "household_member",
      householdMemberLimit: 10,
    },
    {
      plan: "personal",
      state: "active",
      validUntil: "2099-01-01T00:00:00Z",
      purchaserUid: "alice",
      sourcePurchaseTokenHash: "active-personal",
      seatRole: "purchaser",
    },
  ]);

  assert.equal(projected.plan, "personal");
  assert.equal(projected.state, "active");
  assert.equal(projected.continuousLocationSender, true);
  assert.equal(projected.sharedTasks, true);
  assert.equal(projected.sharedHousehold, false);
});

test("an expired purchaser still receives status without paid capability", () => {
  const projected = projectEntitlementSources([
    {
      plan: "duo",
      state: "expired",
      purchaserUid: "alice",
      sourcePurchaseTokenHash: "expired-duo",
      seatRole: "purchaser",
    },
  ]);

  assert.equal(projected.plan, "duo");
  assert.equal(projected.state, "expired");
  assert.equal(projected.continuousLocationSender, false);
  assert.equal(projected.sharedTasks, false);
  assert.equal(projected.sharedHousehold, false);
});

test("active canonical purchase requires Play linkage before another token can replace it", () => {
  const now = Date.parse("2026-09-12T00:00:00Z");
  const common = {
    currentTokenHash: "old-token",
    incomingTokenHash: "new-token",
    currentPurchaseKnown: true,
    currentState: "active",
    currentValidUntil: "2026-10-12T00:00:00Z",
    incomingSupersededByTokenHash: null,
    nowMs: now,
  };

  assert.equal(
      canAdoptCanonicalPurchase({...common, linkedTokenHash: "old-token"}),
      true,
  );
  assert.equal(
      canAdoptCanonicalPurchase({...common, linkedTokenHash: null}),
      false,
  );
  assert.equal(
      canAdoptCanonicalPurchase({...common, linkedTokenHash: "different-token"}),
      false,
  );
});

test("expired canonical purchase can be replaced but superseded token cannot return", () => {
  const now = Date.parse("2026-09-12T00:00:00Z");
  assert.equal(
      canAdoptCanonicalPurchase({
        currentTokenHash: "old-token",
        incomingTokenHash: "new-token",
        linkedTokenHash: null,
        currentPurchaseKnown: true,
        currentState: "canceled",
        currentValidUntil: "2026-09-11T00:00:00Z",
        incomingSupersededByTokenHash: null,
        nowMs: now,
      }),
      true,
  );
  assert.equal(
      canAdoptCanonicalPurchase({
        currentTokenHash: "new-token",
        incomingTokenHash: "old-token",
        linkedTokenHash: null,
        currentPurchaseKnown: true,
        currentState: "active",
        currentValidUntil: "2026-10-12T00:00:00Z",
        incomingSupersededByTokenHash: "new-token",
        nowMs: now,
      }),
      false,
  );
  assert.equal(
      canAdoptCanonicalPurchase({
        currentTokenHash: "dangling-token",
        incomingTokenHash: "new-token",
        linkedTokenHash: null,
        currentPurchaseKnown: false,
        currentState: null,
        currentValidUntil: null,
        incomingSupersededByTokenHash: null,
        nowMs: now,
      }),
      false,
  );
});

test("billing catalog supports annual plans and household seat tiers but fails closed when incomplete", () => {
  assert.equal(configuredCatalog({}).configured, false);

  const env = {
    HOMI_PLAY_PERSONAL_PRODUCT_ID: "personal",
    HOMI_PLAY_PERSONAL_MONTHLY_BASE_PLAN_ID: "monthly",
    HOMI_PLAY_PERSONAL_ANNUAL_BASE_PLAN_ID: "annual",
    HOMI_PLAY_DUO_PRODUCT_ID: "duo",
    HOMI_PLAY_DUO_MONTHLY_BASE_PLAN_ID: "monthly",
    HOMI_PLAY_DUO_ANNUAL_BASE_PLAN_ID: "annual",
  };
  for (let members = 4; members <= 10; members += 1) {
    env[`HOMI_PLAY_HOUSEHOLD_${members}_PRODUCT_ID`] = `household_${members}`;
    env[`HOMI_PLAY_HOUSEHOLD_${members}_MONTHLY_BASE_PLAN_ID`] = "monthly";
    env[`HOMI_PLAY_HOUSEHOLD_${members}_ANNUAL_BASE_PLAN_ID`] = "annual";
  }

  const catalog = configuredCatalog(env);
  assert.equal(catalog.configured, true);
  assert.equal(productFor(catalog, "duo", "annual").plan, "duo");
  const six = productFor(catalog, "household_6", "monthly");
  assert.equal(six.plan, "household");
  assert.equal(six.householdMemberLimit, 6);
  assert.equal(six.cadence, "monthly");
});
