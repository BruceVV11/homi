#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
RTDN_TOPIC="homi-google-play-rtdn"
PLAY_NOTIFICATION_PUBLISHER="serviceAccount:google-play-developer-notifications@system.gserviceaccount.com"

echo "==> Guarding the exact Homi Google Cloud project"
gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Wrong Google Cloud project number; refusing provider mutation." >&2
  exit 1
fi

echo "==> Enabling Google Play Developer API and Pub/Sub"
gcloud services enable \
  androidpublisher.googleapis.com \
  pubsub.googleapis.com \
  --project "${PROJECT_ID}"

echo "==> Ensuring the governed RTDN topic exists"
if ! gcloud pubsub topics describe "${RTDN_TOPIC}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud pubsub topics create "${RTDN_TOPIC}" --project "${PROJECT_ID}"
fi

echo "==> Granting Google Play notification publisher access to the RTDN topic"
gcloud pubsub topics add-iam-policy-binding "${RTDN_TOPIC}" \
  --project "${PROJECT_ID}" \
  --member "${PLAY_NOTIFICATION_PUBLISHER}" \
  --role "roles/pubsub.publisher" \
  --quiet >/dev/null

echo "==> Verifying the exact topic and publisher binding"
gcloud pubsub topics describe "${RTDN_TOPIC}" \
  --project "${PROJECT_ID}" \
  --format='value(name)'

if ! gcloud pubsub topics get-iam-policy "${RTDN_TOPIC}" \
    --project "${PROJECT_ID}" \
    --flatten='bindings[].members' \
    --filter="bindings.role:roles/pubsub.publisher AND bindings.members:${PLAY_NOTIFICATION_PUBLISHER}" \
    --format='value(bindings.members)' | grep -Fq "google-play-developer-notifications@system.gserviceaccount.com"; then
  echo "Google Play RTDN publisher binding was not observed." >&2
  exit 1
fi

echo
echo "HOMI GOOGLE PLAY GCP PROVIDER BOOTSTRAP PASSED"
echo "Topic: projects/${PROJECT_ID}/topics/${RTDN_TOPIC}"
echo
echo "Play Console service-account access and subscription products are separate provider steps."
