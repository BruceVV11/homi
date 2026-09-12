"use strict";

const MAX_TRUSTED_LIVE_VIEWERS = 5;
const HOUSEHOLD_MEMBER_LIMIT = 4;
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
  // Paid capability requires both a Play state that can grant access and a
  // verified paid-through timestamp still in the future. This prevents a stale
  // ACTIVE/GRACE/CANCELED record from outliving its known Play term if RTDN is
  // delayed, and it fails closed when the paid-through boundary is missing.
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
      const current = entitlementCapabilities(source.plan, source.state);
      return {
        continuousLocationSender:
          result.continuousLocationSender || current.continuousLocationSender,
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
  // Once Homi has marked a token as superseded, replaying that old token may
  // refresh historical state but must never make it canonical again.
  if (incomingSupersededByTokenHash) return false;

  if (!currentTokenHash || currentTokenHash === incomingTokenHash) return true;

  // Play issues a new token for an in-app upgrade/downgrade/resubscribe before
  // expiry and links it to the replaced purchase. Require that linkage while
  // the currently canonical purchase is still entitled so an unrelated second
  // subscription cannot silently displace it.
  if (linkedTokenHash && linkedTokenHash === currentTokenHash) return true;

  // A dangling account pointer is an integrity problem, not permission to let a
  // new unlinked token take over. Fail closed until the server state is repaired.
  if (!currentPurchaseKnown) return false;

  const currentEffectiveState = effectivePlayState(
      currentState,
      currentValidUntil,
      nowMs,
  );
  return !grantsPaidAccess(currentEffectiveState);
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
  effectivePlayState,
  grantsPaidAccess,
  entitlementCapabilities,
  projectEntitlementSources,
  canAdoptCanonicalPurchase,
  configuredCatalog,
  productFor,
};
