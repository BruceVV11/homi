#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to deploy Homi backend." >&2
  exit 1
fi

if [ ! -f functions/package.json ] || [ ! -f functions/index.js ]; then
  echo "Homi Functions source is incomplete." >&2
  exit 1
fi

# Cloud Shell's persistent home disk is intentionally small. Function
# node_modules and npm download cache are generated artifacts, so keep the
# cache temporary and remove node_modules automatically after every run.
rm -rf "${REPO_ROOT}/functions/node_modules"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/homi-functions-deploy.XXXXXX")"
cleanup() {
  rm -rf "${REPO_ROOT}/functions/node_modules"
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

NPM_CACHE_DIR="${WORK_ROOT}/npm-cache"
mkdir -p "${NPM_CACHE_DIR}"
npm install \
  --prefix functions \
  --cache "${NPM_CACHE_DIR}" \
  --package-lock=false \
  --no-audit \
  --no-fund
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
  npm_config_cache="${NPM_CACHE_DIR}" \
    npx -y firebase-tools deploy --only firestore,functions --project "${PROJECT_ID}"
fi

echo "Homi backend deployment completed."
