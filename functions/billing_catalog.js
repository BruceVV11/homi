"use strict";

// Google Play product/base-plan IDs are public durable store identifiers, not
// secrets. Keep the backend/client catalogs source-controlled and identical
// once the products have actually been created and verified in Play Console.
// Blank values deliberately keep all paid purchase verification fail-closed
// during development before that external setup exists.
const CURRENT_PLAY_CATALOG = Object.freeze({
  HOMI_PLAY_PERSONAL_PRODUCT_ID: "",
  HOMI_PLAY_PERSONAL_MONTHLY_BASE_PLAN_ID: "",
  HOMI_PLAY_DUO_PRODUCT_ID: "",
  HOMI_PLAY_DUO_MONTHLY_BASE_PLAN_ID: "",
  HOMI_PLAY_HOUSEHOLD_PRODUCT_ID: "",
  HOMI_PLAY_HOUSEHOLD_MONTHLY_BASE_PLAN_ID: "",
  HOMI_PLAY_HOUSEHOLD_ANNUAL_BASE_PLAN_ID: "",
});

// billing_policy.js deliberately accepts an environment-shaped object so the
// pure policy tests remain independent of Firebase. Seed that shape from this
// source-controlled catalog before billing.js is loaded. This avoids runtime
// drift from shell-only environment variables while keeping the values public
// and reviewable in the exact release SHA.
for (const [key, value] of Object.entries(CURRENT_PLAY_CATALOG)) {
  process.env[key] = value;
}

module.exports = {CURRENT_PLAY_CATALOG};
