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

module.exports = {CURRENT_PLAY_CATALOG};
