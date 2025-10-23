#!/usr/bin/env bash
# NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
BACKEND_CHUNK_DIR="${BACKEND_DIR}/CHUNK-07"
FRONTEND_CHUNK_DIR="${FRONTEND_DIR}/CHUNK-07"
RESULT_FILE_BACKEND="${BACKEND_CHUNK_DIR}/RESULT.json"
RESULT_FILE_FRONTEND="${FRONTEND_CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

mkdir -p "${BACKEND_CHUNK_DIR}" "${FRONTEND_CHUNK_DIR}"

REQUIRED_PATHS=(
  "backend/app/services/classifier_service.py"
  "backend/app/routes/check_news.py"
  "backend/app/config.py"
  "backend/app/services/mock_service.py"
  "backend/tests/test_classifier_service.py"
  "backend/tests/test_check_news.py"
  "backend/.env.example"
  "frontend/src/components/ResultCard.jsx"
  "frontend/src/tests/App.test.jsx"
  "scripts/verify-chunk-07.sh"
  "backend/CHUNK-07/README.md"
  "frontend/CHUNK-07/README.md"
)

created_files=()
missing_paths=()
for path in "${REQUIRED_PATHS[@]}"; do
  if [ -e "${PROJECT_ROOT}/${path}" ]; then
    created_files+=("${path}")
  else
    missing_paths+=("${path}")
  fi
done

files_exist_status="pass"
if [ "${#missing_paths[@]}" -ne 0 ]; then
  files_exist_status="fail"
fi

env_placeholders_status="skip"
classifier_symbol_status="skip"
pytest_status="skip"
post_check_status="skip"
notes=()

if [ "${files_exist_status}" = "fail" ]; then
  notes+=("Missing required paths: ${missing_paths[*]}")
fi

if grep -q "CLASSIFIER_PROVIDER" "${PROJECT_ROOT}/backend/.env.example" && \
   grep -q "RAPIDAPI_KEY" "${PROJECT_ROOT}/backend/.env.example" && \
   grep -q "RAPIDAPI_HOST" "${PROJECT_ROOT}/backend/.env.example"; then
  env_placeholders_status="pass"
else
  env_placeholders_status="fail"
  notes+=(".env.example missing classifier provider placeholders.")
fi

python_cmd="python3"
if command -v python >/dev/null 2>&1; then
  python_cmd="python"
fi

if command -v "${python_cmd}" >/dev/null 2>&1; then
  if "${python_cmd}" - <<'PY' >/dev/null 2>&1; then
import importlib
module = importlib.import_module("app.services.classifier_service")
getattr(module, "classify_text")
PY
    classifier_symbol_status="pass"
  else
    classifier_symbol_status="fail"
    notes+=("Unable to import classifier_service.classify_text")
  fi
else
  classifier_symbol_status="fail"
  notes+=("Python interpreter unavailable for import checks")
fi

backend_python="${BACKEND_DIR}/.venv/bin/python"
if [[ "$(uname -s)" =~ MINGW|MSYS|CYGWIN ]]; then
  backend_python="${BACKEND_DIR}/.venv/Scripts/python.exe"
fi

if [ ! -x "${backend_python}" ] && command -v "${python_cmd}" >/dev/null 2>&1; then
  (cd "${BACKEND_DIR}" && "${python_cmd}" -m venv .venv) >/dev/null 2>&1 || notes+=("Failed to create backend virtualenv for pytest")
fi

if [ -x "${backend_python}" ]; then
  "${backend_python}" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
  (cd "${BACKEND_DIR}" && "${backend_python}" -m pip install --quiet -e .) >/dev/null 2>&1 && pytest_ready=1 || pytest_ready=0
else
  pytest_ready=0
fi

if [ "${pytest_ready:-0}" -eq 1 ]; then
  (cd "${BACKEND_DIR}" && "${backend_python}" -m pytest -q tests/test_classifier_service.py tests/test_check_news.py) >/tmp/chunk07-pytest.log 2>&1 && pytest_status="pass" || pytest_status="fail"
  if [ "${pytest_status}" != "pass" ]; then
    notes+=("pytest failed; inspect /tmp/chunk07-pytest.log")
  fi
else
  pytest_status="fail"
  notes+=("Backend virtualenv not ready; pytest skipped.")
fi

if command -v curl >/dev/null 2>&1 && [ -x "${backend_python}" ]; then
  server_log="$(mktemp 2>/dev/null || echo "${BACKEND_DIR}/uvicorn-chunk07.log")"
  pushd "${BACKEND_DIR}" >/dev/null 2>&1 || true
  "${backend_python}" -m uvicorn app.main:app --port 8014 --log-level warning >"${server_log}" 2>&1 &
  server_pid=$!
  popd >/dev/null 2>&1 || true

  ready=0
  for _ in {1..14}; do
    if curl --fail --silent --max-time 3 http://127.0.0.1:8014/health | grep -q '"status"'; then
      ready=1
      break
    fi
    sleep 0.5
  done

  if [ "${ready}" -eq 1 ]; then
    curl_body='{"text":"RapidAPI verifier headline"}'
    response=$(curl --silent --show-error --fail --max-time 6 -H "Content-Type: application/json" -d "${curl_body}" http://127.0.0.1:8014/check-news 2>/tmp/chunk07-post.log || true)
    if [ -n "${response}" ] && echo "${response}" | grep -q '"classifier"'; then
      post_check_status="pass"
    else
      post_check_status="fail"
      notes+=("POST /check-news missing classifier field; inspect ${server_log} and /tmp/chunk07-post.log")
    fi
  else
    post_check_status="fail"
    notes+=("Backend health check failed during verification; see ${server_log}")
  fi

  if [ -n "${server_pid:-}" ]; then
    kill "${server_pid}" >/dev/null 2>&1
    wait "${server_pid}" >/dev/null 2>&1 || true
  fi
else
  notes+=("curl or backend python unavailable; live classifier probe skipped.")
fi

status="pass"
for flag in "${files_exist_status}" "${env_placeholders_status}" "${classifier_symbol_status}" "${pytest_status}" "${post_check_status}"; do
  if [ "${flag}" = "fail" ]; then
    status="fail"
    break
  fi
done

if [ "${#notes[@]}" -eq 0 ]; then
  notes+=("All verification steps executed.")
fi

notes_text="$(printf '%s; ' "${notes[@]}")"
notes_text="${notes_text%; }"
escaped_notes=${notes_text//"/\\"}

escaped_created_files=()
for path in "${created_files[@]}"; do
  escaped_created_files+=("\"${path//"/\\"}\"")

done
IFS=,
created_json="[${escaped_created_files[*]}]"
unset IFS

cat >"${RESULT_FILE_BACKEND}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 7",
  "created_files": ${created_json},
  "verification": {
    "files_exist": "${files_exist_status}",
    "env_placeholders": "${env_placeholders_status}",
    "classifier_import": "${classifier_symbol_status}",
    "pytest": "${pytest_status}",
    "post_check_news_classifier": "${post_check_status}",
    "notes": "${escaped_notes}"
  },
  "status": "${status}"
}
EOF

cp "${RESULT_FILE_BACKEND}" "${RESULT_FILE_FRONTEND}" >/dev/null 2>&1 || true

if [ "${status}" = "pass" ]; then
  exit 0
else
  exit 1
fi
