#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
FUNCTION_REGION="africa-south1"
LEGACY_CONNECTION_DELETE_FUNCTION="onConnectionDeleted"
REPLACEMENT_CONNECTION_DELETE_FUNCTION="onTrustedConnectionDeleted"
BILLING_RT_TOPIC="homi-google-play-rtdn"
PLAY_NOTIFICATION_PUBLISHER="google-play-developer-notifications@system.gserviceaccount.com"
FUNCTION_BATCH_SIZE=5
EXPECTED_FUNCTION_COUNT=43

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FUNCTIONS_DIR="${REPO_ROOT}/functions"
FUNCTIONS_LOCK="${FUNCTIONS_DIR}/package-lock.json"
cd "${REPO_ROOT}"

# Keep the local release toolchain aligned with the deployed Functions runtime.
# Cloud Shell normally exposes Node 22 for this project, but fail closed instead
# of silently validating with a different major version.
NODE_VERSION="$(node --version)"
case "${NODE_VERSION}" in
  v22.*) ;;
  *)
    echo "Homi backend deployment requires Node 22; found ${NODE_VERSION}." >&2
    exit 1
    ;;
esac

gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to deploy Homi backend." >&2
  exit 1
fi

if [ ! -f functions/package.json ] || \
   [ ! -f functions/index.js ] || \
   [ ! -f functions/entrypoint.js ] || \
   [ ! -f functions/households.js ] || \
   [ ! -f functions/household_invite_owner_sync.js ] || \
   [ ! -f functions/trusted_people_preferences.js ] || \
   [ ! -f functions/household_task_policy.js ] || \
   [ ! -f functions/household_task_policy.test.js ] || \
   [ ! -f functions/shared_tasks_canonical.js ] || \
   [ ! -f functions/household_data_cleanup.js ] || \
   [ ! -f functions/household_task_membership_sync.js ] || \
   [ ! -f functions/migrate_legacy_shared_tasks.js ] || \
   [ ! -f functions/billing_catalog.js ] || \
   [ ! -f functions/billing_policy.js ] || \
   [ ! -f functions/billing_policy.test.js ] || \
   [ ! -f functions/billing.js ]; then
  echo "Homi Functions source is incomplete." >&2
  exit 1
fi

# Homi does not currently track functions/package-lock.json in GitHub. Firebase
# uploads untracked files from the Functions source directory, and Cloud Build
# uses npm ci whenever a package-lock is present. A stale local lock therefore
# makes Cloud Build fail even when the local npm install succeeded.
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

FUNCTION_NAMES=()
load_function_exports() {
  local function_name

  mapfile -t FUNCTION_NAMES < <(
    node -e 'const exported = require("./functions/entrypoint.js"); Object.keys(exported).sort().forEach((name) => console.log(name));'
  )

  if [ "${#FUNCTION_NAMES[@]}" -ne "${EXPECTED_FUNCTION_COUNT}" ]; then
    echo "Expected ${EXPECTED_FUNCTION_COUNT} Homi Function exports; found ${#FUNCTION_NAMES[@]}. Refusing to deploy." >&2
    exit 1
  fi

  for function_name in "${FUNCTION_NAMES[@]}"; do
    if [[ ! "${function_name}" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "Unexpected Function export name '${function_name}'; refusing to deploy." >&2
      exit 1
    fi
  done

  echo "==> Verified ${#FUNCTION_NAMES[@]} Homi Function exports"
  printf '    %s\n' "${FUNCTION_NAMES[@]}"
}

verify_active_v2_function() {
  local function_name="$1"
  local state
  state="$(gcloud functions describe "${function_name}" \
    --v2 \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" \
    --format='value(state)' 2>/dev/null || true)"
  if [ "${state}" != "ACTIVE" ]; then
    echo "Homi Function ${function_name} is not ACTIVE after deployment; refusing to continue." >&2
    exit 1
  fi
}

verify_billing_provider_prerequisites() {
  echo "==> Verifying governed Homi+ Play catalog"
  node - <<'NODE'
require("./functions/billing_catalog");
const {configuredCatalog} = require("./functions/billing_policy");
if (!configuredCatalog(process.env).configured) {
  console.error("Homi+ Play product/base-plan IDs are still unconfigured; refusing to deploy billing runtime.");
  process.exit(1);
}
NODE

  if ! gcloud services list \
      --enabled \
      --project "${PROJECT_ID}" \
      --filter='config.name:androidpublisher.googleapis.com' \
      --format='value(config.name)' | grep -qx 'androidpublisher.googleapis.com'; then
    echo "Google Play Android Developer API is not enabled for ${PROJECT_ID}; refusing billing deployment." >&2
    exit 1
  fi

  if ! gcloud pubsub topics describe "${BILLING_RT_TOPIC}" \
      --project "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Homi+ RTDN topic ${BILLING_RT_TOPIC} does not exist; refusing billing deployment." >&2
    exit 1
  fi

  if ! gcloud pubsub topics get-iam-policy "${BILLING_RT_TOPIC}" \
      --project "${PROJECT_ID}" \
      --flatten='bindings[].members' \
      --filter="bindings.role:roles/pubsub.publisher AND bindings.members:serviceAccount:${PLAY_NOTIFICATION_PUBLISHER}" \
      --format='value(bindings.members)' | grep -q "${PLAY_NOTIFICATION_PUBLISHER}"; then
    echo "Google Play RTDN publisher does not have roles/pubsub.publisher on ${BILLING_RT_TOPIC}; refusing billing deployment." >&2
    exit 1
  fi

  echo "==> Homi+ GCP billing prerequisites are present"
  echo "    Play Console API access for the canonical runtime identity must still be proven by Internal Testing purchase verification."
}

reconcile_legacy_connection_delete() {
  local legacy_present=false

  if gcloud functions describe "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
      --v2 \
      --region "${FUNCTION_REGION}" \
      --project "${PROJECT_ID}" >/dev/null 2>&1; then
    legacy_present=true
  elif gcloud functions describe "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
      --region "${FUNCTION_REGION}" \
      --project "${PROJECT_ID}" >/dev/null 2>&1; then
    legacy_present=true
  fi

  if [ "${legacy_present}" != true ]; then
    echo "==> No legacy Homi connection-delete Function needs migration"
    return
  fi

  echo "==> Migrating legacy Homi connection-delete trigger"
  run_firebase deploy \
    --only "functions:${REPLACEMENT_CONNECTION_DELETE_FUNCTION}" \
    --project "${PROJECT_ID}"

  verify_active_v2_function "${REPLACEMENT_CONNECTION_DELETE_FUNCTION}"

  echo "Replacement trigger is ACTIVE. Removing exact stale HTTPS function."
  run_firebase functions:delete "${LEGACY_CONNECTION_DELETE_FUNCTION}" \
    --region "${FUNCTION_REGION}" \
    --project "${PROJECT_ID}" \
    --force
}

deploy_canonical_task_boundary() {
  local selector
  selector="functions:createSharedTask,functions:toggleSharedTask,functions:removeSharedTask,functions:onHouseholdTaskMembershipChanged"

  echo "==> Deploying canonical Homi shared-task writers before legacy migration"
  run_firebase deploy --only "${selector}" --project "${PROJECT_ID}"

  verify_active_v2_function "createSharedTask"
  verify_active_v2_function "toggleSharedTask"
  verify_active_v2_function "removeSharedTask"
  verify_active_v2_function "onHouseholdTaskMembershipChanged"
  echo "==> Canonical shared-task writers are ACTIVE"
}

deploy_function_batches() {
  local -a batch=()
  local function_name
  local selector
  local batch_number=0

  if [ "${#FUNCTION_NAMES[@]}" -ne "${EXPECTED_FUNCTION_COUNT}" ]; then
    echo "Homi Function export preflight is missing or stale; refusing to deploy." >&2
    exit 1
  fi

  echo "==> Deploying ${#FUNCTION_NAMES[@]} Homi Functions in batches of ${FUNCTION_BATCH_SIZE}"
  for function_name in "${FUNCTION_NAMES[@]}"; do
    batch+=("functions:${function_name}")
    if [ "${#batch[@]}" -ge "${FUNCTION_BATCH_SIZE}" ]; then
      batch_number=$((batch_number + 1))
      selector="$(IFS=,; echo "${batch[*]}")"
      echo "==> Deploying Homi Function batch ${batch_number} (${#batch[@]} functions)"
      run_firebase deploy --only "${selector}" --project "${PROJECT_ID}"
      batch=()
    fi
  done

  if [ "${#batch[@]}" -gt 0 ]; then
    batch_number=$((batch_number + 1))
    selector="$(IFS=,; echo "${batch[*]}")"
    echo "==> Deploying Homi Function batch ${batch_number} (${#batch[@]} functions)"
    run_firebase deploy --only "${selector}" --project "${PROJECT_ID}"
  fi
}

echo "==> Homi backend runtime: ${NODE_VERSION}"
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
npm test --prefix functions

# Load and validate the exact export surface only after dependencies exist, but
# before security tests or any Firebase deployment begins.
load_function_exports

if [ -f scripts/test-firestore-security.sh ]; then
  echo "==> Running Homi Firestore security gate"
  bash scripts/test-firestore-security.sh
else
  echo "Homi Firestore security test helper is missing; refusing to deploy." >&2
  exit 1
fi

# The 0.13 deployment helper must never create a half-connected billing runtime.
# Product IDs are source-controlled once verified; GCP API/topic/IAM must also
# exist before any production mutation starts.
verify_billing_provider_prerequisites

# Inspect the legacy production task data without changing it before any 0.12
# task boundary reaches production.
echo "==> Dry-running Homi legacy shared-task migration"
node functions/migrate_legacy_shared_tasks.js

# Resolve the only known stale Function migration before any new Function
# deployment. This prevents codebase reconciliation from turning a known legacy
# resource into a non-interactive deployment surprise.
reconcile_legacy_connection_delete

# 0.12 tightened shared-task reads around canonical Household identity. Deploy
# only the canonical task writers/membership synchronizer first so no new
# preference-era task can appear during the migration window. Then apply the
# safe intersection-only migration and prove no safely migratable task remains
# before stricter Firestore rules/indexes are allowed to reach production.
deploy_canonical_task_boundary

echo "==> Applying safe Homi legacy shared-task migration"
node functions/migrate_legacy_shared_tasks.js --apply

echo "==> Proving Homi legacy shared-task migration is stable"
node functions/migrate_legacy_shared_tasks.js --assert-stable

# Rules/indexes are one deployment surface. Functions are intentionally batched
# because Firebase documents that large simultaneous Function deployments can
# hit provider deployment limits and recommends groups of 10 or fewer. Five at
# a time keeps Homi comfortably below that boundary while remaining resumable.
echo "==> Deploying Homi Firestore rules and indexes"
run_firebase deploy --only firestore --project "${PROJECT_ID}"

deploy_function_batches

echo "==> Verifying all ${EXPECTED_FUNCTION_COUNT} deployed Homi Functions are ACTIVE"
for function_name in "${FUNCTION_NAMES[@]}"; do
  verify_active_v2_function "${function_name}"
done

echo "Homi backend deployment completed."
