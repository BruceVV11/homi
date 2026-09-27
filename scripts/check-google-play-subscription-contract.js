"use strict";

const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const manifestPath = path.join(__dirname, "google-play-subscription-catalog.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

const expectedProducts = [
  ["homi_plus_personal", "personal", 0, 7999, 79999],
  ["homi_plus_duo", "duo", 0, 12999, 129999],
  ["homi_plus_household_4", "household", 4, 19999, 199999],
  ["homi_plus_household_5", "household", 5, 24999, 249999],
  ["homi_plus_household_6", "household", 6, 29999, 299999],
  ["homi_plus_household_7", "household", 7, 34999, 349999],
  ["homi_plus_household_8", "household", 8, 39999, 399999],
  ["homi_plus_household_9", "household", 9, 44999, 449999],
  ["homi_plus_household_10", "household", 10, 49999, 499999],
];

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (manifest.schemaVersion !== 1) fail("Unexpected Play catalog schema version.");
if (manifest.packageName !== "za.co.theconceptlab.homi") fail("Wrong Android package in Play catalog.");
if (manifest.currency !== "ZAR" || manifest.launchRegion !== "ZA") {
  fail("Homi launch billing contract must use ZA/ZAR.");
}
if (manifest.rtdnTopic !== "homi-google-play-rtdn") fail("Wrong Homi RTDN topic.");
if (!Array.isArray(manifest.products) || manifest.products.length !== 9) {
  fail("Expected exactly nine Homi+ subscription products.");
}

const ids = new Set();
for (let index = 0; index < expectedProducts.length; index += 1) {
  const product = manifest.products[index];
  const [id, plan, memberLimit, monthlyCents, annualCents] = expectedProducts[index];
  if (!product || product.productId !== id) fail(`Product ${index + 1} must be ${id}.`);
  if (ids.has(product.productId)) fail(`Duplicate product ID: ${product.productId}`);
  ids.add(product.productId);
  if (product.plan !== plan || product.householdMemberLimit !== memberLimit) {
    fail(`Plan/capacity mismatch for ${id}.`);
  }
  if (product.monthly?.basePlanId !== "monthly" ||
      product.monthly?.billingPeriod !== "P1M" ||
      product.monthly?.priceCents !== monthlyCents) {
    fail(`Monthly contract mismatch for ${id}.`);
  }
  if (product.annual?.basePlanId !== "annual" ||
      product.annual?.billingPeriod !== "P1Y" ||
      product.annual?.priceCents !== annualCents) {
    fail(`Annual contract mismatch for ${id}.`);
  }
}

const backendCatalog = fs.readFileSync(
    path.join(ROOT, "functions", "billing_catalog.js"),
    "utf8",
);
const clientCatalog = fs.readFileSync(
    path.join(ROOT, "lib", "src", "domain", "homi_billing_catalog.dart"),
    "utf8",
);

const backendHasAnyId = expectedProducts.some(([id]) => backendCatalog.includes(`"${id}"`));
const clientHasAnyId = expectedProducts.some(([id]) => clientCatalog.includes(`'${id}'`));

if (backendHasAnyId !== clientHasAnyId) {
  fail("Client/backend Play catalogs are in different activation states.");
}

if (backendHasAnyId) {
  for (const [id] of expectedProducts) {
    if (!backendCatalog.includes(`"${id}"`)) fail(`Backend catalog missing ${id}.`);
    if (!clientCatalog.includes(`'${id}'`)) fail(`Client catalog missing ${id}.`);
  }
  console.log("Homi+ Play catalog contract: 9/9 source IDs activated and aligned.");
} else {
  console.log("Homi+ Play catalog contract: 9/9 permanent IDs reserved in manifest; source activation still fail-closed.");
}
