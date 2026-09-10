#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
RUNTIME_SA="homi-backend-runtime@homi-ee80a.iam.gserviceaccount.com"

cd "$(dirname "$0")/.."
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to change Homi runtime IAM." >&2
  exit 1
fi

DEPLOYER="$(gcloud config get-value account 2>/dev/null)"
if [ -z "${DEPLOYER}" ] || [ "${DEPLOYER}" = "(unset)" ]; then
  echo "No active gcloud account is available." >&2
  exit 1
fi

if ! gcloud iam service-accounts describe "${RUNTIME_SA}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Expected Homi backend runtime service account does not exist." >&2
  exit 1
fi

echo "==> Granting only the trigger/runtime roles Homi Functions require"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/eventarc.eventReceiver" >/dev/null

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/run.invoker" >/dev/null

echo "==> Allowing the current deployer to act as the dedicated runtime identity"
gcloud iam service-accounts add-iam-policy-binding "${RUNTIME_SA}" \
  --project "${PROJECT_ID}" \
  --member="user:${DEPLOYER}" \
  --role="roles/iam.serviceAccountUser" >/dev/null

echo "Homi Functions runtime IAM is ready."
echo "Runtime identity: ${RUNTIME_SA}"
echo "No Editor/Owner role was granted to the runtime service account."
