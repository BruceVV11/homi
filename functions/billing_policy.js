"use strict";

const MAX_TRUSTED_LIVE_VIEWERS = 5;
const HOUSEHOLD_MEMBER_LIMIT = 4;
const DUO_REASSIGNMENT_COOLDOWN_DAYS = 7;

function normalizePlayState(value) {
  switch (String(value || "")) {
    case "SUBSCRIPTION_STATE_ACTIVE":
      return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "grace_period";
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return "on_hold";
    case "SUBSCRIPTION_STATE_PAUSED":
      return "paused";
    case "SUBSCRIPTION_STATE_CANCELED":
      return "canceled";
    case "SUBSCRIPTION_STATE_EXPIRED":
      return "expired";
    case "SUBSCRIPTION_STATE_PENDING":
      return "pending";
    default:
      return "unknown";
  }
}

function grantsPaidAccess(state) {
  return state === "active" || state === "grace_period";
}

function entitlementCapabilities(plan, state) {
  const paid = grantsPaidAccess(state);
  if (!paid) {
    return {
      continuousLocationSender: false,
      sharedHousehold: false,
      maxTrustedLiveViewers: 0,
      householdMemberLimit: 0,
    };
  }

  switch (plan) {
    case "personal":
    case "duo":
      return {
        continuousLocationSender: true,
        sharedHousehold: false,
        maxTrustedLiveViewers: MAX_TRUSTED_LIVE_VIEWERS,
        householdMemberLimit: 0,
      };
    case "household":
      return {
        continuousLocationSender: true,
        sharedHousehold: true,
        maxTrustedLiveViewers: MAX_TRUSTED_LIVE_VIEWERS,
        householdMemberLimit: HOUSEHOLD_MEMBER_LIMIT,
      };
    default:
      return {
        continuousLocationSender: false,
        sharedHousehold: false,
        maxTrustedLiveViewers: 0,
        householdMemberLimit: 0,
      };
  }
}

function configuredCatalog(env) {
  const products = [
    {
      plan: "personal",
      productId: String(env.HOMI_PLAY_PERSONAL_PRODUCT_ID || "").trim(),
      allowedBasePlans: [
        String(env.HOMI_PLAY_PERSONAL_MONTHLY_BASE_PLAN_ID || "").trim(),
      ],
    },
    {
      plan: "duo",
      productId: String(env.HOMI_PLAY_DUO_PRODUCT_ID || "").trim(),
      allowedBasePlans: [
        String(env.HOMI_PLAY_DUO_MONTHLY_BASE_PLAN_ID || "").trim(),
      ],
    },
    {
      plan: "household",
      productId: String(env.HOMI_PLAY_HOUSEHOLD_PRODUCT_ID || "").trim(),
      allowedBasePlans: [
        String(env.HOMI_PLAY_HOUSEHOLD_MONTHLY_BASE_PLAN_ID || "").trim(),
        String(env.HOMI_PLAY_HOUSEHOLD_ANNUAL_BASE_PLAN_ID || "").trim(),
      ],
    },
  ];

  const configured = products.every((item) =>
    item.productId && item.allowedBasePlans.every(Boolean));
  return {configured, products};
}

function productFor(catalog, productId, basePlanId) {
  if (!catalog || !catalog.configured) return null;
  return catalog.products.find((item) =>
    item.productId === productId && item.allowedBasePlans.includes(basePlanId)) || null;
}

module.exports = {
  MAX_TRUSTED_LIVE_VIEWERS,
  HOUSEHOLD_MEMBER_LIMIT,
  DUO_REASSIGNMENT_COOLDOWN_DAYS,
  normalizePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  configuredCatalog,
  productFor,
};
