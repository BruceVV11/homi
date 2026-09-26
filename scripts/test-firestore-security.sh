#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
EXPECTED_TEST_COUNT=23
TEST_FILES=(
  "server.boundary.test.js"
  "household.boundary.test.js"
  "shared_task_household.boundary.test.js"
)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to run Homi security tests." >&2
  exit 1
fi

if [ ! -f security-tests/package.json ]; then
  echo "Homi Firestore security test harness is incomplete." >&2
  exit 1
fi
for test_file in "${TEST_FILES[@]}"; do
  if [ ! -f "security-tests/${test_file}" ]; then
    echo "Homi Firestore security test harness is missing ${test_file}." >&2
    exit 1
  fi
done

DECLARED_TEST_COUNT="$(grep -h -E '^test\(' "${TEST_FILES[@]/#/security-tests/}" | wc -l | tr -d '[:space:]')"
if [ "${DECLARED_TEST_COUNT}" != "${EXPECTED_TEST_COUNT}" ]; then
  echo "Expected ${EXPECTED_TEST_COUNT} Homi Firestore tests; found ${DECLARED_TEST_COUNT}. Refusing to run a stale security gate." >&2
  exit 1
fi
echo "==> Verified ${DECLARED_TEST_COUNT} declared Homi Firestore security tests"

# Generated dependencies are never source data. Remove leftovers from earlier
# Cloud Shell runs so the small persistent home disk cannot fill silently.
rm -rf "${REPO_ROOT}/security-tests/node_modules"

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/homi-firestore-security.XXXXXX")"
cleanup() {
  rm -rf "${WORK_ROOT}"
}
trap cleanup EXIT

mkdir -p "${WORK_ROOT}/security-tests" "${WORK_ROOT}/firebase"
cp security-tests/package.json "${WORK_ROOT}/security-tests/package.json"
for test_file in "${TEST_FILES[@]}"; do
  cp "security-tests/${test_file}" "${WORK_ROOT}/security-tests/${test_file}"
done
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

echo "Homi Firestore security tests completed: ${EXPECTED_TEST_COUNT}/${EXPECTED_TEST_COUNT} expected tests declared."
