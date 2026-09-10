#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="homi-ee80a"
EXPECTED_PROJECT_NUMBER="883068189841"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

gcloud config set project "${PROJECT_ID}" >/dev/null
ACTUAL_PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
if [ "${ACTUAL_PROJECT_NUMBER}" != "${EXPECTED_PROJECT_NUMBER}" ]; then
  echo "Project identity guard failed; refusing to run Homi cleanup." >&2
  exit 1
fi

echo "Cloud Shell persistent storage before cleanup:"
df -h "${HOME}" || true

# Only remove reproducible caches/build dependencies. Never remove gcloud/SSH
# configuration, source, Firebase configuration or operator-owned files.
rm -rf "${REPO_ROOT}/functions/node_modules"
rm -rf "${REPO_ROOT}/security-tests/node_modules"
rm -rf "${HOME}/.npm/_cacache"
rm -rf "${HOME}/.npm/_logs"
rm -rf "${HOME}/.cache/firebase"

# npm package metadata is cacheable and can grow over repeated deployments.
if [ -d "${HOME}/.cache" ]; then
  find "${HOME}/.cache" -maxdepth 1 -type d -name 'npm*' -exec rm -rf {} + 2>/dev/null || true
fi

echo
echo "Cloud Shell persistent storage after cleanup:"
df -h "${HOME}" || true

echo "Homi Cloud Shell cleanup completed."
echo "Only generated dependencies/caches/logs were removed; project source and credentials were left intact."
