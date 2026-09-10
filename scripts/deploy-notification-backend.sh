#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

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

if [ ! -f functions/package.json ] || [ ! -f functions/index.js ]; then
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

if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only firestore,functions --project "${PROJECT_ID}"
else
  npm_config_cache="${NPM_CACHE_DIR}" \
    npx -y firebase-tools deploy --only firestore,functions --project "${PROJECT_ID}"
fi

echo "Homi backend deployment completed."
