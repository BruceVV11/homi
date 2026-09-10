#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"
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

# Cloud Shell has a small persistent $HOME disk. Security-test dependencies are
# disposable, so keep both npm's package cache and node_modules in the VM's
# temporary filesystem instead of consuming the persistent home volume.
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/homi-firestore-security.XXXXXX")"
cleanup() {
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

mkdir -p "${WORK_ROOT}/security-tests" "${WORK_ROOT}/firebase"
cp security-tests/package.json "${WORK_ROOT}/security-tests/package.json"
cp security-tests/firestore.rules.test.js "${WORK_ROOT}/security-tests/firestore.rules.test.js"
cp firebase/firestore.rules "${WORK_ROOT}/firebase/firestore.rules"

NPM_CACHE_DIR="${WORK_ROOT}/npm-cache"
mkdir -p "${NPM_CACHE_DIR}"
npm install \
  --prefix "${WORK_ROOT}/security-tests" \
  --cache "${NPM_CACHE_DIR}" \
  --no-audit \
  --no-fund

TEST_COMMAND="cd '${WORK_ROOT}' && npm test --prefix security-tests"
if command -v firebase >/dev/null 2>&1; then
  firebase emulators:exec --only firestore --project "${PROJECT_ID}" "${TEST_COMMAND}"
else
  npm_config_cache="${NPM_CACHE_DIR}" \
    npx -y firebase-tools emulators:exec \
      --only firestore \
      --project "${PROJECT_ID}" \
      "${TEST_COMMAND}"
fi

echo "Homi Firestore security tests completed."
