#!/usr/bin/env bash
# NEWS CHUNK CONNECTIVITY CHECK — Frontend ↔ Backend Verification
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/backend/logs"
DEBUG_LOG="${LOG_DIR}/connectivity-debug.log"
RESULT_FILE="${ROOT_DIR}/CONNECTIVITY-RESULT.json"
mkdir -p "${LOG_DIR}"
: > "${DEBUG_LOG}"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "${msg}" | tee -a "${DEBUG_LOG}" >&2
}

backend_health_status="fail"
backend_health_details="backend not checked"
backend_health_raw=""
backend_checknews_status="fail"
backend_checknews_details="not run"
backend_checknews_response=""
cors_status="fail"
cors_details="not checked"
cors_headers=""
frontend_env_status="fail"
frontend_env_details="not checked"
detected_base=""
e2e_status="fail"
e2e_details="not run"
e2e_response=""

prereq_node="missing"
prereq_npm="missing"
prereq_python="missing"
prereq_uvicorn="missing"

recommendations=()

PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

record_prereq() {
  local name="$1"
  local cmd="$2"
  if command -v "${cmd}" >/dev/null 2>&1; then
    local version
    if [[ "${cmd}" == "python" || "${cmd}" == "python3" ]]; then
      version="$(${cmd} -c 'import platform; print(platform.python_version())' 2>/dev/null || echo "unknown")"
    else
      version="$(${cmd} --version 2>&1 | head -n1)"
    fi
    printf -v "prereq_${name}" '%s' "${version}"
    log "Detected ${name}: ${version}"
  else
    log "Missing prerequisite: ${name} (${cmd})"
    recommendations+=("Install ${name} and ensure it is on PATH.")
  fi
}

record_prereq node node
record_prereq npm npm
if [[ -n "${PYTHON_BIN}" ]]; then
  prereq_python="$(${PYTHON_BIN} -c 'import platform; print(platform.python_version())')"
  log "Detected python: ${prereq_python}"
else
  log "Missing prerequisite: python"
  recommendations+=("Install python3 (3.10+) to run backend scripts.")
fi

if command -v uvicorn >/dev/null 2>&1; then
  prereq_uvicorn="$(uvicorn --version 2>&1 | head -n1)"
  log "Detected uvicorn: ${prereq_uvicorn}"
else
  if [[ -n "${prereq_python}" && "${prereq_python}" != "missing" ]]; then
    recommendations+=("Install uvicorn via 'pip install uvicorn[standard]' to run the backend server.")
  fi
  log "Missing prerequisite: uvicorn"
fi

BACKEND_PORT=${BACKEND_PORT:-8000}
for env_path in "${ROOT_DIR}/backend/.env" "${ROOT_DIR}/.env" "${ROOT_DIR}/backend/.env.local"; do
  if [[ -f "${env_path}" ]]; then
    port_line="$(grep -E '^PORT=' "${env_path}" || true)"
    if [[ -n "${port_line}" ]]; then
      candidate="${port_line#PORT=}"
      candidate="${candidate%%[[:space:]]*}"
      if [[ "${candidate}" =~ ^[0-9]+$ ]]; then
        BACKEND_PORT="${candidate}"
        log "Detected backend port ${BACKEND_PORT} from ${env_path}"
        break
      fi
    fi
  fi
done

BACKEND_HOSTS=("127.0.0.1" "localhost" "0.0.0.0")
CHECKNEWS_PAYLOAD='{"text":"connectivity test"}'
frontend_expected_origin="http://localhost:5173"

for host in "${BACKEND_HOSTS[@]}"; do
  url="http://${host}:${BACKEND_PORT}/health"
  log "Checking backend health at ${url}"
  response=$(curl -sS --max-time 5 "${url}" 2>>"${DEBUG_LOG}" || true)
  if [[ -n "${response}" && "${response}" == *'"status":"ok"'* ]]; then
    backend_health_status="pass"
    backend_health_details="${url} responded with ${response}"
    backend_health_raw="${response}"
    break
  fi
  backend_health_details="No healthy response from ${host}:${BACKEND_PORT}"
done

if [[ "${backend_health_status}" != "pass" ]]; then
  log "Backend health check failed; attempting to locate uvicorn process"
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -af uvicorn >>"${DEBUG_LOG}" 2>&1 || true
  fi
  recommendations+=("Ensure backend server is running: cd backend && uvicorn app.main:app --reload --port ${BACKEND_PORT}")
fi

for host in "${BACKEND_HOSTS[@]}"; do
  url="http://${host}:${BACKEND_PORT}/check-news"
  log "Posting payload to ${url}"
  response=$(curl -sS -X POST "${url}" -H 'Content-Type: application/json' -d "${CHECKNEWS_PAYLOAD}" --max-time 8 2>>"${DEBUG_LOG}" || true)
  if [[ -n "${response}" && "${response}" == *'"verdict"'* && "${response}" == *'"confidence"'* ]]; then
    backend_checknews_status="pass"
    backend_checknews_details="${url} responded with payload"
    backend_checknews_response="${response}"
    break
  else
    backend_checknews_details="${url} returned ${response:-no response}"
  fi
done

if [[ "${backend_checknews_status}" != "pass" ]]; then
  recommendations+=("Investigate backend /check-news endpoint; verify services and dependencies.")
fi

CORS_ALLOWED=""
main_py="${ROOT_DIR}/backend/app/main.py"
if [[ -n "${PYTHON_BIN}" && -f "${main_py}" ]]; then
  CORS_ALLOWED="$(BACKEND_MAIN="${main_py}" ${PYTHON_BIN} - <<'PY'
import os
import re
from pathlib import Path
path = Path(os.environ["BACKEND_MAIN"])
text = path.read_text(encoding="utf-8")
match = re.search(r"allow_origins\s*=\s*\[(.*?)\]", text, re.DOTALL)
if match:
    cleaned = " ".join(match.group(1).split())
    print(cleaned)
PY
  2>>"${DEBUG_LOG}" || true)"
fi

for host in "${BACKEND_HOSTS[@]}"; do
  url="http://${host}:${BACKEND_PORT}/check-news"
  log "Testing CORS preflight for ${url}"
  headers=$(curl -sS -D - -o /dev/null -X OPTIONS "${url}" \
    -H "Origin: ${frontend_expected_origin}" \
    -H 'Access-Control-Request-Method: POST' \
    --max-time 5 2>>"${DEBUG_LOG}" || true)
  if echo "${headers}" | grep -qi 'Access-Control-Allow-Origin'; then
    cors_status="pass"
    cors_details="Preflight succeeded for ${frontend_expected_origin}"
    cors_headers="${headers}"
    break
  else
    cors_details="Preflight missing Access-Control-Allow-Origin for ${frontend_expected_origin}"
  fi
done

if [[ "${cors_status}" != "pass" ]]; then
  recommendations+=("Update FastAPI CORSMiddleware allow_origins to include ${frontend_expected_origin}.")
fi

frontend_env_files=("${ROOT_DIR}/frontend/.env" "${ROOT_DIR}/frontend/.env.local" "${ROOT_DIR}/frontend/.env.development")
for env_file in "${frontend_env_files[@]}"; do
  if [[ -f "${env_file}" ]]; then
    line="$(grep -E '^VITE_API_BASE_URL=' "${env_file}" || true)"
    if [[ -n "${line}" ]]; then
      detected_base="${line#VITE_API_BASE_URL=}"
      detected_base="${detected_base%$'\r'}"
      log "Detected VITE_API_BASE_URL=${detected_base} in ${env_file}"
      break
    fi
  fi
done

if [[ -z "${detected_base}" ]]; then
  api_js="${ROOT_DIR}/frontend/src/services/api.js"
  if [[ -f "${api_js}" ]]; then
    detected_base="$(grep -Eo 'http://[^"'\'' ]+' "${api_js}" | head -n1 || true)"
  fi
fi

if [[ -z "${detected_base}" ]]; then
  detected_base="http://localhost:${BACKEND_PORT}"
  frontend_env_status="warn"
  frontend_env_details="No VITE_API_BASE_URL set; defaulting to ${detected_base}"
else
  frontend_env_details="Detected API base ${detected_base}"
  if [[ "${detected_base}" == "http://localhost:${BACKEND_PORT}"* || "${detected_base}" == "http://127.0.0.1:${BACKEND_PORT}"* ]]; then
    frontend_env_status="pass"
  else
    frontend_env_status="warn"
    recommendations+=("Set VITE_API_BASE_URL=http://localhost:${BACKEND_PORT} in frontend/.env and restart Vite server.")
  fi
fi

for host in "${BACKEND_HOSTS[@]}"; do
  url="http://${host}:${BACKEND_PORT}/check-news"
  response=$(curl -sS -X POST "${url}" -H 'Content-Type: application/json' -H "Origin: ${frontend_expected_origin}" -d "${CHECKNEWS_PAYLOAD}" --max-time 8 2>>"${DEBUG_LOG}" || true)
  if [[ -n "${response}" && "${response}" == *'"verdict"'* ]]; then
    e2e_status="pass"
    e2e_details="Browser-style request succeeded at ${url}"
    e2e_response="${response}"
    break
  else
    e2e_details="Failed response ${response:-<empty>} from ${url}"
  fi
done

if [[ "${e2e_status}" != "pass" ]]; then
  recommendations+=("Run npm run dev, open the app in a browser, and execute runConnectivityCheck() helper to inspect errors.")
fi

status_overall="pass"
if [[ "${backend_health_status}" != "pass" || "${backend_checknews_status}" != "pass" || "${cors_status}" != "pass" || "${e2e_status}" != "pass" ]]; then
  status_overall="fail"
fi

if [[ ${#recommendations[@]} -gt 0 ]]; then
  RECOMMENDATIONS_JOINED="$(printf '%s||' "${recommendations[@]}")"
  RECOMMENDATIONS_JOINED="${RECOMMENDATIONS_JOINED%||}"
else
  RECOMMENDATIONS_JOINED=""
fi

export RESULT_FILE
export backend_health_status backend_health_details backend_health_raw
export backend_checknews_status backend_checknews_details backend_checknews_response
export cors_status cors_details cors_headers CORS_ALLOWED
export frontend_env_status frontend_env_details detected_base
export e2e_status e2e_details e2e_response
export prereq_node prereq_npm prereq_python prereq_uvicorn
export status_overall RECOMMENDATIONS_JOINED

if [[ -n "${PYTHON_BIN}" ]]; then
  ${PYTHON_BIN} - <<'PY'
import json
import os
from datetime import datetime, timezone

joined = os.environ.get("RECOMMENDATIONS_JOINED", "")
result = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "backend_health": {
        "status": os.environ.get("backend_health_status"),
        "details": os.environ.get("backend_health_details"),
        "raw": os.environ.get("backend_health_raw", "")
    },
    "backend_checknews": {
        "status": os.environ.get("backend_checknews_status"),
        "details": os.environ.get("backend_checknews_details"),
        "response": os.environ.get("backend_checknews_response", "")
    },
    "cors": {
        "status": os.environ.get("cors_status"),
        "details": os.environ.get("cors_details"),
        "headers": os.environ.get("cors_headers", ""),
        "allowed_config": os.environ.get("CORS_ALLOWED", "")
    },
    "frontend_env": {
        "status": os.environ.get("frontend_env_status"),
        "details": os.environ.get("frontend_env_details"),
        "detected_base": os.environ.get("detected_base", "")
    },
    "e2e": {
        "status": os.environ.get("e2e_status"),
        "details": os.environ.get("e2e_details"),
        "response": os.environ.get("e2e_response", "")
    },
    "prereqs": {
        "node": os.environ.get("prereq_node"),
        "npm": os.environ.get("prereq_npm"),
        "python": os.environ.get("prereq_python"),
        "uvicorn": os.environ.get("prereq_uvicorn")
    },
    "recommendations": [rec for rec in joined.split("||") if rec],
    "status": os.environ.get("status_overall")
}

path = os.environ["RESULT_FILE"]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(result, fh, indent=2)
    fh.write("\n")
PY
else
  log "Python unavailable; cannot write ${RESULT_FILE}"
fi

log "Connectivity verification completed with status ${status_overall}"
if [[ "${status_overall}" == "pass" ]]; then
  exit 0
else
  exit 1
fi
