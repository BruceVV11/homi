"use strict";

const fs = require("node:fs");
const path = require("node:path");

const EXPECTED_POLICY_TEST_COUNT = 16;
const TEST_FILES = [
  "household_task_policy.test.js",
  "billing_policy.test.js",
];

let declared = 0;
for (const file of TEST_FILES) {
  const source = fs.readFileSync(path.join(__dirname, file), "utf8");
  declared += (source.match(/\btest\s*\(/g) || []).length;
}

if (declared !== EXPECTED_POLICY_TEST_COUNT) {
  console.error(
      `Expected ${EXPECTED_POLICY_TEST_COUNT} Homi Functions policy tests; ` +
      `found ${declared}. Refusing to run a stale policy gate.`,
  );
  process.exit(1);
}

console.log(`Verified ${declared}/${EXPECTED_POLICY_TEST_COUNT} Homi Functions policy tests.`);
