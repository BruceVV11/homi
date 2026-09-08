#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
PACKAGE_NAME="za.co.theconceptlab.homi"
SHA1_INPUT="${1:-}"
DISPLAY_NAME="${2:-Homi Android Development}"
SECRET_FILE="${HOME}/homi-secrets.properties"

if [ -z "${SHA1_INPUT}" ]; then
  echo "Usage: bash scripts/create-android-maps-key.sh 'AA:BB:CC:...' ['Display name']" >&2
  exit 1
fi

SHA1="$(printf '%s' "${SHA1_INPUT}" \
  | sed -e 's/^SHA1:[[:space:]]*//' -e 's/://g' -e 's/[[:space:]]//g' \
  | tr '[:lower:]' '[:upper:]')"

if ! printf '%s' "${SHA1}" | grep -Eq '^[0-9A-F]{40}$'; then
  echo "Invalid SHA-1 fingerprint. Expected 40 hexadecimal characters (colon-delimited input is accepted)." >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed. Expected ${PROJECT_ID}/${EXPECTED_PROJECT_NUMBER}, got ${ACTUAL_PROJECT_NUMBER}." >&2
  exit 1
fi

echo "Creating a Google Maps Platform API key restricted to:"
echo "  project: ${PROJECT_ID}"
echo "  package: ${PACKAGE_NAME}"
echo "  SHA-1:   ${SHA1_INPUT}"
echo "  APIs:    Maps SDK for Android + Places API (New)"

gcloud services api-keys create \
  --display-name="${DISPLAY_NAME}" \
  --allowed-application="sha1_fingerprint=${SHA1},package_name=${PACKAGE_NAME}" \
  --api-target='service=maps-android-backend.googleapis.com' \
  --api-target='service=places.googleapis.com' \
  --project="${PROJECT_ID}" \
  --quiet >/dev/null

# `gcloud services api-keys create` is backed by a long-running operation. Some
# Cloud SDK versions return the operation resource from --format output instead
# of the final Key resource. Resolve the actual created key by display name
# after the operation has completed rather than treating the operation name as
# a key ID.
KEY_NAME="$(gcloud services api-keys list \
  --project="${PROJECT_ID}" \
  --filter="displayName='${DISPLAY_NAME}'" \
  --sort-by='~createTime' \
  --limit=1 \
  --format='value(name)')"

if [ -z "${KEY_NAME}" ]; then
  echo "The key was created, but its key resource could not be resolved by display name." >&2
  echo "Run: gcloud services api-keys list --project=${PROJECT_ID}" >&2
  exit 1
fi

KEY_ID="${KEY_NAME##*/}"
KEY_STRING="$(gcloud services api-keys get-key-string "${KEY_ID}" \
  --project="${PROJECT_ID}" \
  --format='value(keyString)')"

if [ -z "${KEY_STRING}" ]; then
  echo "The key resource was found, but its key string could not be retrieved." >&2
  exit 1
fi

umask 077
cat > "${SECRET_FILE}" <<EOF
MAPS_API_KEY=${KEY_STRING}
PLACES_API_KEY=${KEY_STRING}
EOF
chmod 600 "${SECRET_FILE}"

echo
echo "Created key resource: ${KEY_NAME}"
echo "Restricted key created successfully."
echo "The key value was intentionally not printed to the terminal."
echo "Secret file: ${SECRET_FILE}"
echo
echo "Download that file to the Windows Homi project as:"
echo "  C:\\ConceptLab\\Projects\\homi\\secrets.properties"
echo
echo "Do not commit secrets.properties. The key is additionally protected by Android package/SHA-1 and API restrictions."
