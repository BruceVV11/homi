"use strict";

const MAX_TRUSTED_LIVE_VIEWERS = 3;
const HOUSEHOLD_INCLUDED_MEMBER_LIMIT = 4;
const HOUSEHOLD_MAXIMUM_MEMBER_LIMIT = 10;
const DUO_REASSIGNMENT_COOLDOWN_DAYS = 7;

const PLAN_PRIORITY = Object.freeze({
  free: 0,
  personal: 1,
  duo: 2,
  household: 3,
});

const STATE_PRIORITY = Object.freeze({
  unknown: 0,
  expired: 1,
  paused: 2,
  on_hold: 3,
  pending: 4,
  canceled: 5,
  grace_period: 6,
  active: 7,
});

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

function timestampMillis(value) {
  if (value == null) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value.toMillis === "function") return value.toMillis();
  return null;
}

function effectivePlayState(state, validUntil, nowMs = Date.now()) {
  if (
    state === "active" ||
    state === "grace_period" ||
    state === "canceled"
  ) {
    const expiryMs = timestampMillis(validUntil);
    return expiryMs != null && expiryMs > nowMs ? state : "expired";
  }
  return state;
}

function grantsPaidAccess(state) {
  return state === "active" ||
    state === "grace_period" ||
    state === "canceled";
}

function normalizedHouseholdLimit(value) {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric)) return HOUSEHOLD_INCLUDED_MEMBER_LIMIT;
  return Math.max(
      HOUSEHOLD_INCLUDED_MEMBER_LIMIT,
      Math.min(HOUSEHOLD_MAXIMUM_MEMBER_LIMIT, Math.trunc(numeric)),
  );
}

function householdRecipientUids(memberUids, purchaserUid, householdMemberLimit) {
  const members = [...new Set(
      (Array.isArray(memberUids) ? memberUids : [])
          .filter((value) => typeof value === "string")
          .map((value) => value.trim())
          .filter(Boolean),
  )];
  const purchaser = String(purchaserUid || "").trim();
  if (!purchaser || !members.includes(purchaser)) return [];

  const limit = normalizedHouseholdLimit(householdMemberLimit);
  return [
    purchaser,
    ...members.filter((uid) => uid !== purchaser),
  ].slice(0, limit);
}

function entitlementCapabilities(plan, state, householdMemberLimit = 0) {
  const paid = grantsPaidAccess(state);
  if (!paid) {
    return {
      continuousLocationSender: false,
      sharedTasks: false,
      sharedRoutines: false,
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
        sharedTasks: true,
        sharedRoutines: true,
        sharedHousehold: false,
        maxTrustedLiveViewers: MAX_TRUSTED_LIVE_VIEWERS,
        householdMemberLimit: 0,
      };
    case "household":
      return {
        continuousLocationSender: true,
        sharedTasks: true,
        sharedRoutines: true,
        sharedHousehold: true,
        maxTrustedLiveViewers: MAX_TRUSTED_LIVE_VIEWERS,
        householdMemberLimit: normalizedHouseholdLimit(householdMemberLimit),
      };
    default:
      return {
        continuousLocationSender: false,
        sharedTasks: false,
        sharedRoutines: false,
        sharedHousehold: false,
        maxTrustedLiveViewers: 0,
        householdMemberLimit: 0,
      };
  }
}

function _sourcePriority(source) {
  return (PLAN_PRIORITY[source.plan] || 0) * 100 +
    (STATE_PRIORITY[source.state] || 0);
}

function projectEntitlementSources(rawSources, nowMs = Date.now()) {
  const sources = Array.isArray(rawSources) ?
    rawSources
        .filter((source) => source && typeof source === "object")
        .map((source) => ({
          ...source,
          state: effectivePlayState(source.state, source.validUntil, nowMs),
        })) : [];
  if (sources.length === 0) return null;

  const paidSources = sources.filter((source) => grantsPaidAccess(source.state));
  const eligible = paidSources.length > 0 ? paidSources :
    sources.filter((source) => source.seatRole === "purchaser");
  if (eligible.length === 0) return null;

  const strongest = [...eligible].sort((a, b) =>
    _sourcePriority(b) - _sourcePriority(a))[0];
  const capabilities = paidSources.length === 0 ?
    entitlementCapabilities("free", "free") :
    paidSources.reduce((result, source) => {
      const current = entitlementCapabilities(
          source.plan,
          source.state,
          source.householdMemberLimit,
      );
      return {
        continuousLocationSender:
          result.continuousLocationSender || current.continuousLocationSender,
        sharedTasks: result.sharedTasks || current.sharedTasks,
        sharedRoutines: result.sharedRoutines || current.sharedRoutines,
        sharedHousehold: result.sharedHousehold || current.sharedHousehold,
        maxTrustedLiveViewers: Math.max(
            result.maxTrustedLiveViewers,
            current.maxTrustedLiveViewers,
        ),
        householdMemberLimit: Math.max(
            result.householdMemberLimit,
            current.householdMemberLimit,
        ),
      };
    }, entitlementCapabilities("free", "free"));

  return {
    plan: strongest.plan || "free",
    state: strongest.state || "unknown",
    purchaserUid: strongest.purchaserUid || null,
    sourcePurchaseTokenHash: strongest.sourcePurchaseTokenHash || null,
    seatRole: strongest.seatRole || null,
    householdId: strongest.householdId || null,
    duoSeatAssigneeUid: strongest.duoSeatAssigneeUid || null,
    validUntil: strongest.validUntil || null,
    sourceCount: sources.length,
    ...capabilities,
  };
}

function canAdoptCanonicalPurchase({
  currentTokenHash,
  incomingTokenHash,
  linkedTokenHash,
  currentPurchaseKnown,
  currentState,
  currentValidUntil,
  incomingSupersededByTokenHash,
  nowMs = Date.now(),
}) {
  if (incomingSupersededByTokenHash) return false;
  if (!currentTokenHash || currentTokenHash === incomingTokenHash) return true;
  if (linkedTokenHash && linkedTokenHash === currentTokenHash) return true;
  if (!currentPurchaseKnown) return false;

  const currentEffectiveState = effectivePlayState(
      currentState,
      currentValidUntil,
      nowMs,
  );
  return !grantsPaidAccess(currentEffectiveState);
}

function configuredCatalog(env) {
  const singleProduct = (plan, prefix) => ({
    plan,
    productId: String(env[`${prefix}_PRODUCT_ID`] || "").trim(),
    basePlans: [
      {
        cadence: "monthly",
        basePlanId: String(env[`${prefix}_MONTHLY_BASE_PLAN_ID`] || "").trim(),
        householdMemberLimit: 0,
      },
      {
        cadence: "annual",
        basePlanId: String(env[`${prefix}_ANNUAL_BASE_PLAN_ID`] || "").trim(),
        householdMemberLimit: 0,
      },
    ],
  });

  const products = [
    singleProduct("personal", "HOMI_PLAY_PERSONAL"),
    singleProduct("duo", "HOMI_PLAY_DUO"),
  ];

  for (
    let members = HOUSEHOLD_INCLUDED_MEMBER_LIMIT;
    members <= HOUSEHOLD_MAXIMUM_MEMBER_LIMIT;
    members += 1
  ) {
    const prefix = `HOMI_PLAY_HOUSEHOLD_${members}`;
    products.push({
      plan: "household",
      productId: String(env[`${prefix}_PRODUCT_ID`] || "").trim(),
      basePlans: [
        {
          cadence: "monthly",
          basePlanId: String(env[`${prefix}_MONTHLY_BASE_PLAN_ID`] || "").trim(),
          householdMemberLimit: members,
        },
        {
          cadence: "annual",
          basePlanId: String(env[`${prefix}_ANNUAL_BASE_PLAN_ID`] || "").trim(),
          householdMemberLimit: members,
        },
      ],
    });
  }

  const configured = products.every((item) =>
    item.productId && item.basePlans.every((basePlan) => basePlan.basePlanId));
  return {configured, products};
}

function productFor(catalog, productId, basePlanId) {
  if (!catalog || !catalog.configured) return null;
  const product = catalog.products.find((item) => item.productId === productId);
  if (!product) return null;
  const basePlan = product.basePlans.find((item) => item.basePlanId === basePlanId);
  if (!basePlan) return null;
  return {
    plan: product.plan,
    productId: product.productId,
    cadence: basePlan.cadence,
    householdMemberLimit: basePlan.householdMemberLimit || 0,
  };
}

module.exports = {
  MAX_TRUSTED_LIVE_VIEWERS,
  HOUSEHOLD_INCLUDED_MEMBER_LIMIT,
  HOUSEHOLD_MAXIMUM_MEMBER_LIMIT,
  DUO_REASSIGNMENT_COOLDOWN_DAYS,
  normalizePlayState,
  effectivePlayState,
  grantsPaidAccess,
  normalizedHouseholdLimit,
  householdRecipientUids,
  entitlementCapabilities,
  projectEntitlementSources,
  canAdoptCanonicalPurchase,
  configuredCatalog,
  productFor,
};
