#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-508000"
PACKAGE_NAME="za.co.theconceptlab.homi"
SHA1_INPUT="${1:-}"
DISPLAY_NAME="${2:-Homi Android Development}"

if [ -z "${SHA1_INPUT}" ]; then
  echo "Usage: bash scripts/create-android-maps-key.sh 'AA:BB:CC:...' ['Display name']" >&2
  exit 1
fi

# keytool/Android Studio normally show a colon-delimited SHA-1. The API Keys
# API/gcloud expects the hexadecimal fingerprint without delimiters.
SHA1="$(printf '%s' "${SHA1_INPUT}" \
  | sed -e 's/^SHA1:[[:space:]]*//' -e 's/://g' -e 's/[[:space:]]//g' \
  | tr '[:lower:]' '[:upper:]')"

if ! printf '%s' "${SHA1}" | grep -Eq '^[0-9A-F]{40}$'; then
  echo "Invalid SHA-1 fingerprint. Expected 40 hexadecimal characters (colon-delimited input is accepted)." >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Creating a Google Maps Platform API key restricted to:"
echo "  package: ${PACKAGE_NAME}"
echo "  SHA-1:   ${SHA1_INPUT}"
echo "  APIs:    Maps SDK for Android + Places API (New)"

CREATE_JSON="$(gcloud services api-keys create \
  --display-name="${DISPLAY_NAME}" \
  --allowed-application="sha1_fingerprint=${SHA1},package_name=${PACKAGE_NAME}" \
  --api-target='service=maps-android-backend.googleapis.com' \
  --api-target='service=places.googleapis.com' \
  --project="${PROJECT_ID}" \
  --format=json)"

KEY_NAME="$(printf '%s' "${CREATE_JSON}" | jq -r '.name')"

if [ -z "${KEY_NAME}" ] || [ "${KEY_NAME}" = "null" ]; then
  echo "Could not determine the new API key resource name." >&2
  printf '%s\n' "${CREATE_JSON}" | jq . >&2
  exit 1
fi

KEY_STRING="$(gcloud services api-keys get-key-string "${KEY_NAME}" --format='value(keyString)')"

echo
echo "Created key resource: ${KEY_NAME}"
echo "API key: ${KEY_STRING}"
echo
echo "On the Windows Homi project, store it in a local secrets.properties file:"
echo "  MAPS_API_KEY=${KEY_STRING}"
echo "  PLACES_API_KEY=${KEY_STRING}"
echo
echo "Do not commit secrets.properties. The key is additionally protected by Android package/SHA-1 and API restrictions."
