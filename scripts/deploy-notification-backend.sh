#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
FUNCTION_REGION="africa-south1"
LEGACY_CONNECTION_DELETE_FUNCTION="onConnectionDeleted"
REPLACEMENT_CONNECTION_DELETE_FUNCTION="onTrustedConnectionDeleted"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FUNCTIONS_DIR="${REPO_ROOT}/functions"
FUNCTIONS_LOCK="${FUNCTIONS_DIR}/package-lock.json"
cd "${REPO_ROOT}"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to deploy Homi backend." >&2
  exit 1
fi

if [ ! -f functions/package.json ] || [ ! -f functions/index.js ] || [ ! -f functions/entrypoint.js ]; then
  echo "Homi Functions source is incomplete." >&2
  exit 1
fi

# Homi does not currently track functions/package-lock.json in GitHub. Firebase
# uploads untracked files from the Functions source directory, and Cloud Build
# uses npm ci whenever a package-lock is present. A stale local lock therefore
# makes Cloud Build fail even when the local npm install succeeded.
#
# Preserve the old smooth deployment behaviour by generating a lock that
# matches package.json before every upload, while keeping npm cache/dependency
# storage disposable so Cloud Shell's small persistent home disk stays clean.
LOCKFILE_TRACKED=false
if git ls-files --error-unmatch functions/package-lock.json >/dev/null 2>&1; then
  LOCKFILE_TRACKED=true
else
  rm -f "${FUNCTIONS_LOCK}"
fi

rm -rf "${FUNCTIONS_DIR}/node_modules"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/homi-functions-deploy.XXXXXX")"
cleanup() {
  rm -rf "${FUNCTIONS_DIR}/node_modules"
  if [ "${LOCKFILE_TRACKED}" = false ]; then
    rm -f "${FUNCTIONS_LOCK}"
  fi
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

NPM_CACHE_DIR="${WORK_ROOT}/npm-cache"
mkdir -p "${NPM_CACHE_DIR}"

run_firebase() {
  if command -v firebase >/dev/null 2>&1; then
    firebase "$@"
  else
    npm_config_cache="${NPM_CACHE_DIR}" npx -y firebase-tools "$@"
  fi
}

echo "==> Preparing Homi Functions dependency lock"
npm install \
  --prefix functions \
  --package-lock-only \
  --ignore-scripts \
  --cache "${NPM_CACHE_DIR}" \
  --no-audit \
  --no-fund

if [ ! -f "${FUNCTIONS_LOCK}" ]; then
  echo "Functions package-lock.json was not generated; refusing to deploy." >&2
  exit 1
fi

if [ "${LOCKFILE_TRACKED}" = true ] && ! git diff --quiet -- functions/package-lock.json; then
  echo "Tracked functions/package-lock.json is out of sync with package.json; regenerate and commit it before deployment." >&2
  exit 1
fi

echo "==> Verifying Homi Functions dependencies with npm ci"
npm ci \
  --prefix functions \
  --cache "${NPM_CACHE_DIR}" \
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

# Firebase cannot change an existing Function from HTTPS to an event trigger in
# place. Homi has a stale HTTPS function named onConnectionDeleted, while the
# 0.8.2 source needs a Firestore deletion backstop. Migrate safely and
# idempotently: deploy the renamed trigger, prove it ACTIVE, then delete only
# the exact stale name/region before the normal full deployment continues.
LEGACY_PRESENT=false
if gcloud functions describe "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
    --gen2 \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" >/dev/null 2>&1; then
  LEGACY_PRESENT=true
elif gcloud functions describe "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" >/dev/null 2>&1; then
  LEGACY_PRESENT=true
fi

if [ "${LEGACY_PRESENT}" = true ]; then
  echo "==> Migrating legacy Homi connection-delete trigger"
  run_firebase deploy \
    --only "functions:${REPLACEMENT_CONNECTION_DELETE_FUNCTION}" \
    --project "${PROJECT_ID}"

  REPLACEMENT_STATE="$(gcloud functions describe "${REPLACEMENT_CONNECTION_DELETE_FUNCTION}" \
    --gen2 \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" \
    --format='value(state)' 2>/dev/null || true)"
  if [ "${REPLACEMENT_STATE}" != "ACTIVE" ]; then
    echo "Replacement connection-delete trigger is not ACTIVE; refusing to delete the legacy function." >&2
    exit 1
  fi

  echo "Replacement trigger is ACTIVE. Removing exact stale HTTPS function."
  run_firebase functions:delete "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" \
    --force
fi

echo "==> Deploying Homi Firestore and Functions"
run_firebase deploy --only firestore,functions --project "${PROJECT_ID}"

echo "Homi backend deployment completed."
