#!/usr/bin/env bash
# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
SMOKE_TEST_SCRIPT="${SCRIPT_DIR}/smoke_tests/smoke_test.sh"

PROJECT_ID="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${GCP_REGION:-us-central1}"
BACKEND_SERVICE="${BACKEND_SERVICE_NAME:-fake-news-backend}"
FRONTEND_SERVICE="${FRONTEND_SERVICE_NAME:-fake-news-frontend}"
TAG_SUFFIX="${TAG_SUFFIX:-$(date +%Y%m%d-%H%M%S)}"
BACKEND_ENV_FILE="${BACKEND_ENV_FILE:-${PROJECT_ROOT}/backend/.env.production}"
FRONTEND_ENV_FILE="${FRONTEND_ENV_FILE:-${PROJECT_ROOT}/frontend/.env.production}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "[ERROR] GCP_PROJECT is not set and no configured project found."
  echo "        Run 'gcloud config set project <PROJECT_ID>' or export GCP_PROJECT first."
  exit 1
fi

echo "Using GCP project: ${PROJECT_ID}"
echo "Target region: ${REGION}"

declare -A REQUIRED_CMDS=(
  [gcloud]="Google Cloud SDK"
  [docker]="Docker CLI"
  [bash]="GNU bash"
)

for cmd in "${!REQUIRED_CMDS[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] ${REQUIRED_CMDS[${cmd}]} ('${cmd}') is required but not found in PATH."
    exit 1
  fi
done

echo "Verifying Cloud Run API availability..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project "${PROJECT_ID}" >/dev/null

BACKEND_IMAGE="gcr.io/${PROJECT_ID}/${BACKEND_SERVICE}:${TAG_SUFFIX}"
FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/${FRONTEND_SERVICE}:${TAG_SUFFIX}"

echo "Building backend container via Cloud Build..."
gcloud builds submit "${BACKEND_DIR}" --tag "${BACKEND_IMAGE}" --project "${PROJECT_ID}" --quiet

echo "Building frontend container via Cloud Build..."
gcloud builds submit "${FRONTEND_DIR}" --tag "${FRONTEND_IMAGE}" --project "${PROJECT_ID}" --quiet

function env_file_to_flags() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo ""
    return 0
  fi

  python <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    sys.exit(0)

pairs = []
for line in path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    if '=' not in line:
        continue
    key, value = line.split('=', 1)
    key = key.strip()
    value = value.strip().strip('"').strip("'")
    pairs.append(f"{key}={value}")

print(",".join(pairs))
PY
  "${file_path}"
}

BACKEND_ENV_VARS="$(env_file_to_flags "${BACKEND_ENV_FILE}")"
FRONTEND_ENV_VARS="$(env_file_to_flags "${FRONTEND_ENV_FILE}")"

declare -a BACKEND_DEPLOY_FLAGS=(
  "--image" "${BACKEND_IMAGE}"
  "--region" "${REGION}"
  "--platform" "managed"
  "--allow-unauthenticated"
  "--project" "${PROJECT_ID}"
  "--port" "8000"
  "--memory" "512Mi"
  "--cpu" "1"
  "--max-instances" "5"
  "--concurrency" "80"
  "--timeout" "60"
)

declare -a FRONTEND_DEPLOY_FLAGS=(
  "--image" "${FRONTEND_IMAGE}"
  "--region" "${REGION}"
  "--platform" "managed"
  "--allow-unauthenticated"
  "--project" "${PROJECT_ID}"
  "--port" "8080"
  "--memory" "256Mi"
  "--cpu" "1"
  "--max-instances" "3"
  "--concurrency" "150"
  "--timeout" "30"
)

if [[ -n "${BACKEND_ENV_VARS}" ]]; then
  BACKEND_DEPLOY_FLAGS+=("--set-env-vars" "${BACKEND_ENV_VARS}")
else
  echo "[WARN] No backend environment file found at ${BACKEND_ENV_FILE}; deploying with defaults."
fi

if [[ -n "${FRONTEND_ENV_VARS}" ]]; then
  FRONTEND_DEPLOY_FLAGS+=("--set-env-vars" "${FRONTEND_ENV_VARS}")
fi

echo "Deploying backend service '${BACKEND_SERVICE}' to Cloud Run..."
gcloud run deploy "${BACKEND_SERVICE}" "${BACKEND_DEPLOY_FLAGS[@]}" --quiet

BACKEND_URL="$(gcloud run services describe "${BACKEND_SERVICE}" --region "${REGION}" --platform managed --project "${PROJECT_ID}" --format='value(status.url)')"

echo "Deploying frontend service '${FRONTEND_SERVICE}' to Cloud Run..."
gcloud run deploy "${FRONTEND_SERVICE}" "${FRONTEND_DEPLOY_FLAGS[@]}" --quiet

FRONTEND_URL="$(gcloud run services describe "${FRONTEND_SERVICE}" --region "${REGION}" --platform managed --project "${PROJECT_ID}" --format='value(status.url)')"

echo "Backend deployed to: ${BACKEND_URL}"
echo "Frontend deployed to: ${FRONTEND_URL}"

echo "Running smoke tests..."
if [[ ! -x "${SMOKE_TEST_SCRIPT}" ]]; then
  echo "[ERROR] Smoke test script missing or not executable at ${SMOKE_TEST_SCRIPT}."
  exit 1
fi

"${SMOKE_TEST_SCRIPT}" --backend "${BACKEND_URL}" --frontend "${FRONTEND_URL}"

echo "Deployment successful."
echo "Remember to monitor Cloud Run usage to stay within free tier / credit limits."
