#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

cd "$(dirname "$0")/.."
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to run Homi security tests." >&2
  exit 1
fi

if [ ! -f security-tests/package.json ] || [ ! -f security-tests/firestore.rules.test.js ]; then
  echo "Homi Firestore security test harness is incomplete." >&2
  exit 1
fi

npm install --prefix security-tests --no-audit --no-fund

TEST_COMMAND="npm test --prefix security-tests"
if command -v firebase >/dev/null 2>&1; then
  firebase emulators:exec --only firestore --project "${PROJECT_ID}" "${TEST_COMMAND}"
else
  npx -y firebase-tools emulators:exec --only firestore --project "${PROJECT_ID}" "${TEST_COMMAND}"
fi

echo "Homi Firestore security tests completed."
