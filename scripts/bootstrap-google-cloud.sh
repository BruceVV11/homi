#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-508000"
EXPECTED_PROJECT_NUMBER="429164377824"
PACKAGE_NAME="za.co.theconceptlab.homi"
FIRESTORE_LOCATION="africa-south1"
RUNTIME_SA_NAME="homi-backend-runtime"
RUNTIME_SA_EMAIL="${RUNTIME_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

log() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

wait_firebase_operation() {
  local operation_name="$1"
  local url="https://firebase.googleapis.com/v1beta1/${operation_name}"
  local token
  local response

  for _ in $(seq 1 60); do
    token="$(gcloud auth print-access-token)"
    response="$(curl -fsS -H "Authorization: Bearer ${token}" "${url}")"
    if [ "$(printf '%s' "${response}" | jq -r '.done // false')" = "true" ]; then
      if [ "$(printf '%s' "${response}" | jq -r 'has("error")')" = "true" ]; then
        printf '%s\n' "${response}" | jq .
        return 1
      fi
      printf '%s\n' "${response}"
      return 0
    fi
    sleep 3
  done

  echo "Timed out waiting for Firebase operation: ${operation_name}" >&2
  return 1
}

require_command gcloud
require_command curl
require_command jq
require_command base64

log "Selecting Google Cloud project ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed." >&2
  echo "Expected ${PROJECT_ID} to have project number ${EXPECTED_PROJECT_NUMBER}, got ${ACTUAL_PROJECT_NUMBER}." >&2
  echo "Stopping before any cloud changes are made." >&2
  exit 1
fi
gcloud projects describe "${PROJECT_ID}" --format='table(projectId,projectNumber,name)'

if [ -n "${HOMI_BILLING_ACCOUNT:-}" ]; then
  log "Linking billing account supplied in HOMI_BILLING_ACCOUNT"
  gcloud billing projects link "${PROJECT_ID}" --billing-account="${HOMI_BILLING_ACCOUNT}"
else
  log "Billing account was not supplied"
  echo "Maps Platform and production serverless features require billing."
  echo "If billing is not already linked, rerun with:"
  echo "  HOMI_BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX bash scripts/bootstrap-google-cloud.sh"
fi

gcloud billing projects describe "${PROJECT_ID}" --format='table(projectId,billingEnabled,billingAccountName)'

log "Enabling Homi Google/Firebase APIs - batch 1 of 2"
# Google Service Usage accepts at most 20 services in one enable request.
# Keep this batch at 20 or fewer so the bootstrap remains rerunnable/idempotent.
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudbilling.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  firebase.googleapis.com \
  firestore.googleapis.com \
  firebaserules.googleapis.com \
  identitytoolkit.googleapis.com \
  securetoken.googleapis.com \
  fcm.googleapis.com \
  firebaseappcheck.googleapis.com \
  playintegrity.googleapis.com \
  drive.googleapis.com \
  maps-android-backend.googleapis.com \
  places.googleapis.com \
  apikeys.googleapis.com \
  secretmanager.googleapis.com \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  --project="${PROJECT_ID}"

log "Enabling Homi Google/Firebase APIs - batch 2 of 2"
gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  eventarc.googleapis.com \
  pubsub.googleapis.com \
  --project="${PROJECT_ID}"

log "Adding Firebase to the existing Google Cloud project if needed"
TOKEN="$(gcloud auth print-access-token)"
HTTP_CODE="$(curl -sS -o /tmp/homi-firebase-project.json -w '%{http_code}' \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}")"

if [ "${HTTP_CODE}" = "200" ]; then
  echo "Firebase is already enabled for ${PROJECT_ID}."
else
  TOKEN="$(gcloud auth print-access-token)"
  ADD_RESPONSE="$(curl -fsS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{}' \
    "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}:addFirebase")"
  OPERATION_NAME="$(printf '%s' "${ADD_RESPONSE}" | jq -r '.name')"
  wait_firebase_operation "${OPERATION_NAME}" >/dev/null
  echo "Firebase enabled for ${PROJECT_ID}."
fi

log "Verifying Firebase project identity"
TOKEN="$(gcloud auth print-access-token)"
FIREBASE_PROJECT="$(curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}")"
FIREBASE_PROJECT_ID="$(printf '%s' "${FIREBASE_PROJECT}" | jq -r '.projectId')"
FIREBASE_PROJECT_NUMBER="$(printf '%s' "${FIREBASE_PROJECT}" | jq -r '.projectNumber')"
if [ "${FIREBASE_PROJECT_ID}" != "${PROJECT_ID}" ] || [ "${FIREBASE_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Firebase identity verification failed." >&2
  printf '%s\n' "${FIREBASE_PROJECT}" | jq . >&2
  exit 1
fi
echo "Firebase project: ${FIREBASE_PROJECT_ID} (${FIREBASE_PROJECT_NUMBER})"

log "Registering the permanent Homi Android app if needed"
TOKEN="$(gcloud auth print-access-token)"
APPS_RESPONSE="$(curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}/androidApps")"
ANDROID_APP_NAME="$(printf '%s' "${APPS_RESPONSE}" | jq -r --arg pkg "${PACKAGE_NAME}" '.apps[]? | select(.packageName == $pkg) | .name' | head -n 1)"

if [ -z "${ANDROID_APP_NAME}" ]; then
  TOKEN="$(gcloud auth print-access-token)"
  CREATE_RESPONSE="$(curl -fsS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"displayName\":\"Homi Android\",\"packageName\":\"${PACKAGE_NAME}\"}" \
    "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}/androidApps")"
  OPERATION_NAME="$(printf '%s' "${CREATE_RESPONSE}" | jq -r '.name')"
  wait_firebase_operation "${OPERATION_NAME}" >/dev/null

  TOKEN="$(gcloud auth print-access-token)"
  APPS_RESPONSE="$(curl -fsS \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}/androidApps")"
  ANDROID_APP_NAME="$(printf '%s' "${APPS_RESPONSE}" | jq -r --arg pkg "${PACKAGE_NAME}" '.apps[]? | select(.packageName == $pkg) | .name' | head -n 1)"
fi

echo "Android app resource: ${ANDROID_APP_NAME}"

log "Downloading the initial Android Firebase config to Cloud Shell"
TOKEN="$(gcloud auth print-access-token)"
CONFIG_RESPONSE="$(curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/${ANDROID_APP_NAME}/config")"
printf '%s' "${CONFIG_RESPONSE}" | jq -r '.configFileContents' | base64 --decode > "${HOME}/homi-google-services.json"
echo "Created: ${HOME}/homi-google-services.json"
echo "This will later be copied to android/app/google-services.json on the Windows project PC."

log "Creating the Firestore Standard database in Johannesburg if needed"
if gcloud firestore databases describe --database='(default)' --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud firestore databases describe --database='(default)' --project="${PROJECT_ID}" \
    --format='table(name,locationId,type,edition)'
else
  gcloud firestore databases create \
    --database='(default)' \
    --location="${FIRESTORE_LOCATION}" \
    --edition=standard \
    --type=firestore-native \
    --delete-protection \
    --project="${PROJECT_ID}"
fi

log "Creating the keyless backend runtime service account"
if gcloud iam service-accounts describe "${RUNTIME_SA_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Service account already exists: ${RUNTIME_SA_EMAIL}"
else
  gcloud iam service-accounts create "${RUNTIME_SA_NAME}" \
    --display-name="Homi backend runtime" \
    --description="Runtime identity for Homi server-side notifications and trusted backend operations" \
    --project="${PROJECT_ID}"
fi

log "Granting only the initial runtime roles"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA_EMAIL}" \
  --role='roles/datastore.user' \
  --condition=None >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA_EMAIL}" \
  --role='roles/firebasecloudmessaging.admin' \
  --condition=None >/dev/null

echo "Runtime service account: ${RUNTIME_SA_EMAIL}"
echo "No JSON private key was created. Google-hosted workloads should use the attached service account/ADC."

log "Bootstrap complete"
echo "Automated: API enablement, Firebase attachment, Firebase identity verification, Android app registration, initial Firebase config, Firestore creation, backend runtime identity."
echo "Still manual: Authentication providers, Google Auth/OAuth consent branding, billing confirmation, SHA fingerprints, Maps key creation, App Check registration/enforcement, Play Console declarations."
