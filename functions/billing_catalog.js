"use strict";

// Google Play product/base-plan IDs are public durable store identifiers, not
// secrets. Keep backend/client catalogs source-controlled and identical once
// the permanent products have actually been created and verified in Play.
const CURRENT_PLAY_CATALOG = Object.freeze({
  HOMI_PLAY_PERSONAL_PRODUCT_ID: "homi_plus_personal",
  HOMI_PLAY_PERSONAL_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_PERSONAL_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_DUO_PRODUCT_ID: "homi_plus_duo",
  HOMI_PLAY_DUO_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_DUO_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_4_PRODUCT_ID: "homi_plus_household_4",
  HOMI_PLAY_HOUSEHOLD_4_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_4_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_5_PRODUCT_ID: "homi_plus_household_5",
  HOMI_PLAY_HOUSEHOLD_5_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_5_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_6_PRODUCT_ID: "homi_plus_household_6",
  HOMI_PLAY_HOUSEHOLD_6_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_6_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_7_PRODUCT_ID: "homi_plus_household_7",
  HOMI_PLAY_HOUSEHOLD_7_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_7_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_8_PRODUCT_ID: "homi_plus_household_8",
  HOMI_PLAY_HOUSEHOLD_8_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_8_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_9_PRODUCT_ID: "homi_plus_household_9",
  HOMI_PLAY_HOUSEHOLD_9_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_9_ANNUAL_BASE_PLAN_ID: "annual",
  HOMI_PLAY_HOUSEHOLD_10_PRODUCT_ID: "homi_plus_household_10",
  HOMI_PLAY_HOUSEHOLD_10_MONTHLY_BASE_PLAN_ID: "monthly",
  HOMI_PLAY_HOUSEHOLD_10_ANNUAL_BASE_PLAN_ID: "annual",
});

for (const [key, value] of Object.entries(CURRENT_PLAY_CATALOG)) {
  process.env[key] = value;
}

module.exports = {CURRENT_PLAY_CATALOG};
