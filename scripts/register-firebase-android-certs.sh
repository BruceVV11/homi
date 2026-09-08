#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
PACKAGE_NAME="za.co.theconceptlab.homi"
SHA1_INPUT="${1:-}"
SHA256_INPUT="${2:-}"

usage() {
  echo "Usage: bash scripts/register-firebase-android-certs.sh 'SHA1' 'SHA256'" >&2
  exit 1
}

[ -n "$SHA1_INPUT" ] && [ -n "$SHA256_INPUT" ] || usage

normalize_hex() {
  printf '%s' "$1" \
    | sed -e 's/^SHA1:[[:space:]]*//' -e 's/^SHA-256:[[:space:]]*//' -e 's/://g' -e 's/[[:space:]]//g' \
    | tr '[:lower:]' '[:upper:]'
}

colonize_hex() {
  printf '%s' "$1" | sed 's/../&:/g; s/:$//'
}

SHA1_HEX="$(normalize_hex "$SHA1_INPUT")"
SHA256_HEX="$(normalize_hex "$SHA256_INPUT")"

if ! printf '%s' "$SHA1_HEX" | grep -Eq '^[0-9A-F]{40}$'; then
  echo "Invalid SHA-1 fingerprint." >&2
  exit 1
fi
if ! printf '%s' "$SHA256_HEX" | grep -Eq '^[0-9A-F]{64}$'; then
  echo "Invalid SHA-256 fingerprint." >&2
  exit 1
fi

SHA1="$(colonize_hex "$SHA1_HEX")"
SHA256="$(colonize_hex "$SHA256_HEX")"

for cmd in gcloud curl jq base64; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

echo "==> Verifying Homi Firebase project"
gcloud config set project "$PROJECT_ID" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
if [ "$ACTUAL_PROJECT_NUMBER" != "$EXPECTED_PROJECT_NUMBER" ]; then
  echo "Project identity guard failed. Expected $PROJECT_ID ($EXPECTED_PROJECT_NUMBER), got ($ACTUAL_PROJECT_NUMBER)." >&2
  exit 1
fi

echo "Project: $PROJECT_ID ($ACTUAL_PROJECT_NUMBER)"

echo "==> Locating Homi Android app"
TOKEN="$(gcloud auth print-access-token)"
APPS="$(curl -fsS -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/projects/${PROJECT_ID}/androidApps")"
ANDROID_APP_NAME="$(printf '%s' "$APPS" | jq -r --arg pkg "$PACKAGE_NAME" '.apps[]? | select(.packageName == $pkg) | .name' | head -n 1)"
if [ -z "$ANDROID_APP_NAME" ]; then
  echo "Could not find Firebase Android app for $PACKAGE_NAME." >&2
  exit 1
fi

echo "Android app: $ANDROID_APP_NAME"

echo "==> Reading existing certificate fingerprints"
TOKEN="$(gcloud auth print-access-token)"
CERTS="$(curl -fsS -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/${ANDROID_APP_NAME}/sha")"

ensure_cert() {
  local cert_type="$1"
  local hash_colon="$2"
  local hash_hex="$3"
  local exists
  exists="$(printf '%s' "$CERTS" | jq -r --arg h "$hash_hex" \
    'any(.certificates[]?; ((.shaHash | gsub(":"; "") | ascii_upcase) == $h))')"
  if [ "$exists" = "true" ]; then
    echo "$cert_type already registered: $hash_colon"
    return 0
  fi

  TOKEN="$(gcloud auth print-access-token)"
  curl -fsS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"shaHash\":\"${hash_colon}\",\"certType\":\"${cert_type}\"}" \
    "https://firebase.googleapis.com/v1beta1/${ANDROID_APP_NAME}/sha" >/dev/null
  echo "$cert_type registered: $hash_colon"
}

ensure_cert "SHA_1" "$SHA1" "$SHA1_HEX"
ensure_cert "SHA_256" "$SHA256" "$SHA256_HEX"

echo "==> Refreshing google-services.json"
TOKEN="$(gcloud auth print-access-token)"
CONFIG_RESPONSE="$(curl -fsS -H "Authorization: Bearer ${TOKEN}" \
  "https://firebase.googleapis.com/v1beta1/${ANDROID_APP_NAME}/config")"
printf '%s' "$CONFIG_RESPONSE" | jq -r '.configFileContents' | base64 --decode > "$HOME/homi-google-services.json"

echo
echo "Firebase Android certificates are ready."
echo "SHA-1:   $SHA1"
echo "SHA-256: $SHA256"
echo "Fresh config: $HOME/homi-google-services.json"
echo
echo "Next: create the restricted Maps/Places key with:"
echo "  bash scripts/create-android-maps-key.sh '$SHA1'"
