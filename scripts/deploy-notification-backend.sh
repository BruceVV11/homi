#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

cd "$(dirname "$0")/.."
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to deploy Homi notifications." >&2
  exit 1
fi

if [ ! -f functions/package.json ] || [ ! -f functions/index.js ]; then
  echo "Homi notification Functions source is incomplete." >&2
  exit 1
fi

npm install --prefix functions --no-audit --no-fund
npm run lint --prefix functions

if [ -f scripts/test-firestore-security.sh ]; then
  echo "==> Running Homi Firestore security gate"
  bash scripts/test-firestore-security.sh
else
  echo "Homi Firestore security test helper is missing; refusing to deploy." >&2
  exit 1
fi

if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only firestore,functions --project "${PROJECT_ID}"
else
  npx -y firebase-tools deploy --only firestore,functions --project "${PROJECT_ID}"
fi

echo "Homi notification backend deployment completed."
