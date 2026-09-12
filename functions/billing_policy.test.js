"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  configuredCatalog,
  productFor,
} = require("./billing_policy");

test("only active and grace-period Play states grant paid access", () => {
  assert.equal(normalizePlayState("SUBSCRIPTION_STATE_ACTIVE"), "active");
  assert.equal(
      normalizePlayState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"),
      "grace_period",
  );
  assert.equal(grantsPaidAccess("active"), true);
  assert.equal(grantsPaidAccess("grace_period"), true);
  assert.equal(grantsPaidAccess("on_hold"), false);
  assert.equal(grantsPaidAccess("expired"), false);
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
