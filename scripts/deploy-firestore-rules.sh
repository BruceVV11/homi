#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

cd "$(dirname "$0")/.."
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to deploy rules." >&2
  exit 1
fi

if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only firestore --project "${PROJECT_ID}"
else
  npx -y firebase-tools deploy --only firestore --project "${PROJECT_ID}"
fi
