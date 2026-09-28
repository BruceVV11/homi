#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
PACKAGE_NAME="za.co.theconceptlab.homi"
SHA1_INPUT="${1:-}"
SHA256_INPUT="${2:-}"
MAPS_KEY_DISPLAY_NAME="${3:-Homi Android Development}"

usage() {
  echo "Usage: bash scripts/repair-play-signing-runtime.sh 'PLAY_SHA1' 'PLAY_SHA256' ['Maps key display name']" >&2
  exit 1
}

[ -n "${SHA1_INPUT}" ] && [ -n "${SHA256_INPUT}" ] || usage

normalize_hex() {
  printf '%s' "$1" \
    | sed -e 's/^SHA1:[[:space:]]*//' -e 's/^SHA-256:[[:space:]]*//' -e 's/://g' -e 's/[[:space:]]//g' \
    | tr '[:lower:]' '[:upper:]'
}

SHA1_HEX="$(normalize_hex "${SHA1_INPUT}")"
SHA256_HEX="$(normalize_hex "${SHA256_INPUT}")"

if ! printf '%s' "${SHA1_HEX}" | grep -Eq '^[0-9A-F]{40}$'; then
  echo "Invalid Play App Signing SHA-1 fingerprint." >&2
  exit 1
fi
if ! printf '%s' "${SHA256_HEX}" | grep -Eq '^[0-9A-F]{64}$'; then
  echo "Invalid Play App Signing SHA-256 fingerprint." >&2
  exit 1
fi

for cmd in gcloud curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

echo "==> Guarding Homi project"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to change Homi signing configuration." >&2
  exit 1
fi

echo "==> Registering Play App Signing certificates with Firebase"
bash scripts/register-firebase-android-certs.sh "${SHA1_INPUT}" "${SHA256_INPUT}"

echo "==> Locating the existing restricted Homi Maps key"
mapfile -t KEY_NAMES < <(
  gcloud services api-keys list \
    --project="${PROJECT_ID}" \
    --filter="displayName='${MAPS_KEY_DISPLAY_NAME}'" \
    --format='value(name)'
)

if [ "${#KEY_NAMES[@]}" -ne 1 ]; then
  echo "Expected exactly one API key named '${MAPS_KEY_DISPLAY_NAME}', found ${#KEY_NAMES[@]}." >&2
  echo "Available API keys:" >&2
  gcloud services api-keys list \
    --project="${PROJECT_ID}" \
    --format='table(displayName,name)' >&2
  exit 1
fi

KEY_NAME="${KEY_NAMES[0]}"

echo "==> Appending Play App Signing SHA-1 to the existing Android key restriction"
gcloud services api-keys update "${KEY_NAME}" \
  --project="${PROJECT_ID}" \
  --append \
  --allowed-application="sha1_fingerprint=${SHA1_HEX},package_name=${PACKAGE_NAME}" \
  --quiet >/dev/null

echo "==> Confirming Firebase App Check Play Integrity registration"
TOKEN="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
APPS="$(curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}/androidApps")"
APP_ID="$(printf '%s' "${APPS}" | jq -r --arg pkg "${PACKAGE_NAME}" '.apps[]? | select(.packageName == $pkg) | .appId' | head -n 1)"

if [ -z "${APP_ID}" ] || [ "${APP_ID}" = "null" ]; then
  echo "Could not resolve the Firebase Android app for ${PACKAGE_NAME}." >&2
  exit 1
fi

APP_CHECK_HTTP="$(
  curl -sS \
    -o /tmp/homi-app-check-play-integrity.json \
    -w '%{http_code}' \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://firebaseappcheck.googleapis.com/v1/projects/${EXPECTED_PROJECT_NUMBER}/apps/${APP_ID}/playIntegrityConfig"
)"

echo
echo "============================================================"
echo "HOMI PLAY-SIGNING RUNTIME REPAIR"
echo "============================================================"
echo "Firebase SHA-1/SHA-256: registered"
echo "Maps Android restriction: Play SHA-1 appended"
echo "Firebase App ID: ${APP_ID}"

if [ "${APP_CHECK_HTTP}" = "200" ]; then
  echo "App Check Play Integrity config: present"
  echo
  echo "PASS: server-side signing configuration repaired."
  echo "Force-stop Homi and Google Play Store, reopen Homi, then retry the map and Homi-code connection."
else
  echo "App Check Play Integrity config: not confirmed (HTTP ${APP_CHECK_HTTP})"
  echo
  echo "The certificate and Maps repair succeeded, but App Check still needs one console check:"
  echo "Firebase Console -> App Check -> Homi Android -> Play Integrity."
  echo "Also confirm Play Console -> App integrity -> Play Integrity API is linked to project ${PROJECT_ID}."
  echo
  echo "No app rebuild is required for these server-side certificate/restriction changes."
fi

rm -f /tmp/homi-app-check-play-integrity.json
