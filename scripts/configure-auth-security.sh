#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
CONFIG_URL="https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_command gcloud
require_command curl
require_command jq

gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to change Homi Authentication security." >&2
  exit 1
fi

gcloud services enable identitytoolkit.googleapis.com --project="${PROJECT_ID}" >/dev/null
TOKEN="$(gcloud auth print-access-token --project="${PROJECT_ID}")"

patch_config() {
  local update_mask="$1"
  local payload="$2"
  curl -fsS -X PATCH \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-Goog-User-Project: ${PROJECT_ID}" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    "${CONFIG_URL}?updateMask=${update_mask}" >/dev/null
}

echo "==> Enabling email enumeration protection"
patch_config \
  "emailPrivacyConfig" \
  '{"emailPrivacyConfig":{"enableImprovedEmailPrivacy":true}}'

echo "==> Enforcing the Homi password baseline for new passwords"
patch_config \
  "passwordPolicyConfig" \
  '{"passwordPolicyConfig":{"enforcementState":"ENFORCE","forceUpgradeOnSignin":false,"constraints":{"requireUppercase":true,"requireLowercase":true,"requireNumeric":true,"minLength":10,"maxLength":128}}}'

# Read back only the non-secret security settings so the operator can verify
# the result without exposing tokens, provider secrets or user data.
TOKEN="$(gcloud auth print-access-token --project="${PROJECT_ID}")"
CONFIG="$(curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Goog-User-Project: ${PROJECT_ID}" \
  "${CONFIG_URL}")"

EMAIL_PRIVACY="$(printf '%s' "${CONFIG}" | jq -r '.emailPrivacyConfig.enableImprovedEmailPrivacy // false')"
PASSWORD_STATE="$(printf '%s' "${CONFIG}" | jq -r '.passwordPolicyConfig.enforcementState // "OFF"')"
MIN_LENGTH="$(printf '%s' "${CONFIG}" | jq -r '.passwordPolicyConfig.constraints.minLength // 0')"
MAX_LENGTH="$(printf '%s' "${CONFIG}" | jq -r '.passwordPolicyConfig.constraints.maxLength // 0')"
FORCE_UPGRADE="$(printf '%s' "${CONFIG}" | jq -r '.passwordPolicyConfig.forceUpgradeOnSignin // false')"

if [ "${EMAIL_PRIVACY}" != "true" ] || \
   [ "${PASSWORD_STATE}" != "ENFORCE" ] || \
   [ "${MIN_LENGTH}" != "10" ] || \
   [ "${MAX_LENGTH}" != "128" ] || \
   [ "${FORCE_UPGRADE}" != "false" ]; then
  echo "Homi Authentication security verification failed." >&2
  exit 1
fi

echo "Homi Authentication security baseline is enabled."
echo "Email enumeration protection: ON"
echo "Password policy: 10-128 characters, uppercase + lowercase + number"
echo "Existing accounts are not forced to change their password on sign-in."
echo "No access token or Authentication secret was printed."
