"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizePlayState,
  effectivePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  projectEntitlementSources,
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

test("canceled state becomes expired when its paid term is already over", () => {
  const now = Date.parse("2026-09-12T00:00:00Z");
  assert.equal(
      effectivePlayState("canceled", "2026-09-13T00:00:00Z", now),
      "canceled",
  );
  assert.equal(
      effectivePlayState("canceled", "2026-09-11T00:00:00Z", now),
      "expired",
  );
});

test("privacy exits are not represented as paid capabilities", () => {
  const free = entitlementCapabilities("free", "active");
  const expiredHousehold = entitlementCapabilities("household", "expired");
  assert.deepEqual(free, {
    continuousLocationSender: false,
    sharedHousehold: false,
    maxTrustedLiveViewers: 0,
    householdMemberLimit: 0,
  });
  assert.deepEqual(expiredHousehold, free);
});

test("Personal and Duo grant sender capability without shared Household", () => {
  const personal = entitlementCapabilities("personal", "active");
  const duo = entitlementCapabilities("duo", "active");
  assert.equal(personal.continuousLocationSender, true);
  assert.equal(personal.sharedHousehold, false);
  assert.equal(personal.maxTrustedLiveViewers, 5);
  assert.deepEqual(duo, personal);
});

test("Household grants four-member shared capability", () => {
  const household = entitlementCapabilities("household", "active");
  assert.equal(household.continuousLocationSender, true);
  assert.equal(household.sharedHousehold, true);
  assert.equal(household.maxTrustedLiveViewers, 5);
  assert.equal(household.householdMemberLimit, 4);
});

test("multiple subscription sources combine without one purchase deleting another", () => {
  const projected = projectEntitlementSources([
    {
      plan: "personal",
      state: "active",
      purchaserUid: "alice",
      sourcePurchaseTokenHash: "personal-token",
      seatRole: "purchaser",
    },
    {
      plan: "household",
      state: "grace_period",
      purchaserUid: "bob",
      sourcePurchaseTokenHash: "household-token",
      seatRole: "household_member",
      householdId: "home1",
    },
  ]);

  assert.equal(projected.plan, "household");
  assert.equal(projected.state, "grace_period");
  assert.equal(projected.continuousLocationSender, true);
  assert.equal(projected.sharedHousehold, true);
  assert.equal(projected.maxTrustedLiveViewers, 5);
  assert.equal(projected.householdMemberLimit, 4);
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
    },
    {
      plan: "personal",
      state: "active",
      purchaserUid: "alice",
      sourcePurchaseTokenHash: "active-personal",
      seatRole: "purchaser",
    },
  ]);

  assert.equal(projected.plan, "personal");
  assert.equal(projected.state, "active");
  assert.equal(projected.continuousLocationSender, true);
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
  assert.equal(projected.sharedHousehold, false);
});

test("billing catalog fails closed until every durable Play id exists", () => {
  assert.equal(configuredCatalog({}).configured, false);
  const catalog = configuredCatalog({
    HOMI_PLAY_PERSONAL_PRODUCT_ID: "personal",
    HOMI_PLAY_PERSONAL_MONTHLY_BASE_PLAN_ID: "monthly",
    HOMI_PLAY_DUO_PRODUCT_ID: "duo",
    HOMI_PLAY_DUO_MONTHLY_BASE_PLAN_ID: "monthly",
    HOMI_PLAY_HOUSEHOLD_PRODUCT_ID: "household",
    HOMI_PLAY_HOUSEHOLD_MONTHLY_BASE_PLAN_ID: "monthly",
    HOMI_PLAY_HOUSEHOLD_ANNUAL_BASE_PLAN_ID: "annual",
  });
  assert.equal(catalog.configured, true);
  assert.equal(productFor(catalog, "household", "annual").plan, "household");
  assert.equal(productFor(catalog, "duo", "annual"), null);
});
