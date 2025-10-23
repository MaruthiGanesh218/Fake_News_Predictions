#!/usr/bin/env bash
# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

FRONTEND_URL=""
BACKEND_URL=""
TIMEOUT="10"

usage() {
  cat <<'EOF'
Smoke test for Fake News Prediction deployment.
Usage: smoke_test.sh --frontend <URL> --backend <URL> [--timeout <seconds>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frontend)
      FRONTEND_URL="$2"
      shift 2
      ;;
    --backend)
      BACKEND_URL="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown flag: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${FRONTEND_URL}" || -z "${BACKEND_URL}" ]]; then
  echo "[ERROR] Both --frontend and --backend URLs are required." >&2
  usage
  exit 1
fi

echo "[INFO] Verifying frontend availability at ${FRONTEND_URL}..."
FRONT_HTML="$(curl -fsSL --max-time "${TIMEOUT}" "${FRONTEND_URL}/")"
if [[ "${FRONT_HTML}" != *"Fake News"* ]]; then
  echo "[ERROR] Frontend did not return expected branding." >&2
  exit 1
fi

echo "[INFO] Frontend responded successfully."

PAYLOAD='{"text":"Breaking news: smoke test ping"}'

echo "[INFO] Exercising backend /health endpoint..."
curl -fsSL --max-time "${TIMEOUT}" "${BACKEND_URL}/health" >/dev/null

echo "[INFO] Exercising backend /ready endpoint..."
curl -fsSL --max-time "${TIMEOUT}" "${BACKEND_URL}/ready" >/dev/null

echo "[INFO] Posting payload to backend /check-news..."
BACKEND_RESPONSE="$(curl -fsSL --max-time "${TIMEOUT}" -X POST "${BACKEND_URL}/check-news" -H 'Content-Type: application/json' -d "${PAYLOAD}")"

if [[ "${BACKEND_RESPONSE}" != *"verdict"* ]]; then
  echo "[ERROR] Backend response did not contain 'verdict'. Full payload:" >&2
  echo "${BACKEND_RESPONSE}" >&2
  exit 1
fi

echo "[INFO] Smoke test passed."
