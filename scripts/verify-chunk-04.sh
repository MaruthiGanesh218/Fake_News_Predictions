#!/usr/bin/env bash
# NEWS CHUNK 4 — Frontend–Backend Integration
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
BACKEND_DIR="${PROJECT_ROOT}/backend"
CHUNK_DIR="${FRONTEND_DIR}/CHUNK-04"
RESULT_FILE="${CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

REQUIRED_PATHS=(
  "frontend/src/services/api.js"
  "frontend/src/App.jsx"
  "frontend/src/components/InputCard.jsx"
  "frontend/src/components/ResultCard.jsx"
  "frontend/src/tests/App.test.jsx"
  "frontend/src/tests/InputCard.test.jsx"
  "frontend/package.json"
  "frontend/CHUNK-04/README.md"
  "frontend/CHUNK-04/RESULT.json"
  "frontend/CHUNK-04/verify-chunk-04.sh"
  "scripts/verify-chunk-04.sh"
)

missing_paths=()
created_files=()
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

npm_install_status="skip"
tests_run_status="skip"
integration_probe_status="skip"
notes=()

if [ "${files_exist_status}" = "fail" ]; then
  notes+=("Missing required paths: ${missing_paths[*]}")
fi

if command -v npm >/dev/null 2>&1; then
  if pushd "${FRONTEND_DIR}" >/dev/null 2>&1; then
    install_cmd="npm install --no-audit --no-fund --no-progress"
    fallback_cmd=""
    if [ -f package-lock.json ]; then
      install_cmd="npm ci --no-audit --no-fund --no-progress"
      fallback_cmd="npm install --no-audit --no-fund --no-progress"
    fi

    if ${install_cmd} >/dev/null 2>&1; then
      npm_install_status="pass"
    elif [ -n "${fallback_cmd}" ] && ${fallback_cmd} >/dev/null 2>&1; then
      npm_install_status="pass"
      notes+=("npm ci failed; npm install succeeded instead.")
    else
      npm_install_status="fail"
      notes+=("Dependency installation failed. Check npm logs for details.")
    fi

    if [ "${npm_install_status}" = "pass" ]; then
      if npm run test -- --run >/dev/null 2>&1; then
        tests_run_status="pass"
      else
        tests_run_status="fail"
        notes+=("npm run test did not complete successfully. Review Vitest output.")
      fi

      if command -v curl >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  BACKEND_VENV="${BACKEND_DIR}/.venv"
        server_log="$(mktemp 2>/dev/null || echo "${PROJECT_ROOT}/backend/uvicorn-chunk04.log")"
        if [ ! -d "${BACKEND_VENV}" ]; then
          python -m venv "${BACKEND_VENV}" >/dev/null 2>&1 || notes+=("Failed to provision backend venv for integration probe.")
        fi
        ACTIVATED=0
        if [ -f "${BACKEND_VENV}/bin/activate" ]; then
          # shellcheck disable=SC1091
          source "${BACKEND_VENV}/bin/activate"
          ACTIVATED=1
        elif [ -f "${BACKEND_VENV}/Scripts/activate" ]; then
          # shellcheck disable=SC1091
          source "${BACKEND_VENV}/Scripts/activate"
          ACTIVATED=1
        fi
        if [ "${ACTIVATED}" -eq 1 ]; then
          pip install --quiet --upgrade pip >/dev/null 2>&1 || true
          pip install --quiet fastapi uvicorn[standard] python-dotenv httpx >/dev/null 2>&1 || true
          if pushd "${BACKEND_DIR}" >/dev/null 2>&1; then
            python -m uvicorn app.main:app --port 8001 --log-level warning >"${server_log}" 2>&1 &
            server_pid=$!
            popd >/dev/null 2>&1 || true
          else
            notes+=("Unable to enter backend directory; integration probe skipped.")
          fi
          if [ -z "${server_pid:-}" ]; then
            integration_probe_status="fail"
            notes+=("Failed to launch backend server for integration probe.")
          fi
          if [ "${integration_probe_status}" != "fail" ]; then
            ready=0
            for _ in {1..10}; do
              if curl --fail --silent --max-time 3 http://127.0.0.1:8001/health | grep -q '"status"'; then
                integration_probe_status="pass"
                ready=1
                break
              fi
              sleep 0.5
            done
            if [ "${ready}" -ne 1 ]; then
              integration_probe_status="fail"
              notes+=("Backend health probe failed during integration check. See ${server_log}.")
            fi
          fi
          if [ -n "${server_pid:-}" ]; then
            kill "${server_pid}" >/dev/null 2>&1
            wait "${server_pid}" >/dev/null 2>&1 || true
          fi
          if declare -f deactivate >/dev/null 2>&1; then
            deactivate || true
          fi
        fi
      else
        notes+=("curl or python unavailable; skipped live integration probe.")
      fi
    fi

    popd >/dev/null 2>&1 || true
  else
    notes+=("Unable to enter frontend directory; npm operations skipped.")
  fi
else
  notes+=("npm not available; dependency installation and tests skipped.")
fi

status="pass"
if [ "${files_exist_status}" != "pass" ] || [ "${npm_install_status}" = "fail" ] || [ "${tests_run_status}" = "fail" ] || [ "${integration_probe_status}" = "fail" ]; then
  status="fail"
fi

if [ "${status}" = "pass" ]; then
  notes+=("All checks passed. Frontend integration tests executed successfully.")
fi

if [ "${#notes[@]}" -eq 0 ]; then
  notes+=("No additional verification notes recorded.")
fi

notes_text="$(printf '%s; ' "${notes[@]}")"
notes_text="${notes_text%; }"

created_json="["
for path in "${created_files[@]}"; do
  created_json+="\"${path//"/\\"}\","
done
created_json="${created_json%,}"
created_json+="]"

cat >"${RESULT_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 4",
  "created_files": ${created_json},
  "verification": {
    "files_exist": "${files_exist_status}",
    "npm_install": "${npm_install_status}",
    "tests_run": "${tests_run_status}",
    "integration_probe": "${integration_probe_status}",
    "notes": "${notes_text//"/\\"}"
  },
  "status": "${status}"
}
EOF

if [ "${status}" = "pass" ]; then
  exit 0
else
  exit 1
fi
