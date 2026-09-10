#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"

if [ "$#" -ne 2 ]; then
  echo "Usage: bash scripts/manage-developer-admin.sh <firebase-auth-uid> <enable|disable>" >&2
  exit 2
fi

UID_VALUE="$1"
ACTION="$2"

if [ -z "${UID_VALUE}" ]; then
  echo "Firebase Auth UID cannot be empty." >&2
  exit 2
fi
if [ "${ACTION}" != "enable" ] && [ "${ACTION}" != "disable" ]; then
  echo "Second argument must be enable or disable." >&2
  exit 2
fi

gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to change developer access." >&2
  exit 1
fi

ACCESS_TOKEN="$(gcloud auth print-access-token)"
DOC_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/developerAdmins/${UID_VALUE}"

if [ "${ACTION}" = "disable" ]; then
  HTTP_CODE="$(curl -sS -o /tmp/homi-developer-admin-response.json -w '%{http_code}' \
    -X DELETE \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${DOC_URL}")"
  if [ "${HTTP_CODE}" != "200" ] && [ "${HTTP_CODE}" != "404" ]; then
    cat /tmp/homi-developer-admin-response.json >&2
    echo "Could not disable developer access (HTTP ${HTTP_CODE})." >&2
    exit 1
  fi
  echo "Homi developer notification access disabled."
  exit 0
fi

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BODY="$(cat <<JSON
{
  "fields": {
    "active": {"booleanValue": true},
    "role": {"stringValue": "developer"},
    "updatedAt": {"timestampValue": "${NOW}"}
  }
}
JSON
)"

HTTP_CODE="$(curl -sS -o /tmp/homi-developer-admin-response.json -w '%{http_code}' \
  -X PATCH \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${BODY}" \
  "${DOC_URL}?updateMask.fieldPaths=active&updateMask.fieldPaths=role&updateMask.fieldPaths=updatedAt")"

if [ "${HTTP_CODE}" != "200" ]; then
  cat /tmp/homi-developer-admin-response.json >&2
  echo "Could not enable developer access (HTTP ${HTTP_CODE})." >&2
  exit 1
fi

echo "Homi developer notification access enabled for the supplied Firebase Auth account."
echo "Restart/reopen Homi after signing in so the Developer notifications entry can refresh."
