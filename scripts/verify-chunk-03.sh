#!/usr/bin/env bash
# NEWS CHUNK 3 — Backend Routing & Test Endpoint
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
CHUNK_DIR="${BACKEND_DIR}/CHUNK-03"
RESULT_FILE="${CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

REQUIRED_FILES=(
  "backend/pyproject.toml"
  "backend/app/__init__.py"
  "backend/app/main.py"
  "backend/app/config.py"
  "backend/app/routes/__init__.py"
  "backend/app/routes/check_news.py"
  "backend/app/services/mock_service.py"
  "backend/tests/test_health.py"
  "backend/tests/test_check_news.py"
  "backend/.env.example"
  "backend/CHUNK-03/README.md"
  "backend/CHUNK-03/RESULT.json"
  "backend/CHUNK-03/verify-chunk-03.sh"
  "scripts/verify-chunk-03.sh"
)

missing_files=()
created_files=()
for relative_path in "${REQUIRED_FILES[@]}"; do
  if [ -e "${PROJECT_ROOT}/${relative_path}" ]; then
    created_files+=("${relative_path}")
  else
    missing_files+=("${relative_path}")
  fi
done

files_exist_status="pass"
if [ "${#missing_files[@]}" -ne 0 ]; then
  files_exist_status="fail"
fi

python_status="fail"
uvicorn_status="fail"
pytest_status="fail"
tests_status="fail"
health_status="fail"
notes=()

PYTHON_CMD=()
if command -v python >/dev/null 2>&1; then
  PYTHON_CMD=(python)
  python_status="pass"
elif command -v py >/dev/null 2>&1; then
  PYTHON_CMD=(py -3)
  python_status="pass"
else
  notes+=("Python interpreter not found; backend verification skipped.")
fi

VENV_PATH="${BACKEND_DIR}/.venv"
ACTIVATED=0

if [ "${python_status}" = "pass" ]; then
  if pushd "${BACKEND_DIR}" >/dev/null 2>&1; then
    if [ ! -d "${VENV_PATH}" ]; then
      if ! "${PYTHON_CMD[@]}" -m venv "${VENV_PATH}" >/dev/null 2>&1; then
        notes+=("Failed to create backend virtual environment.")
      fi
    fi

    if [ -d "${VENV_PATH}" ]; then
      if [ -f "${VENV_PATH}/bin/activate" ]; then
        # shellcheck disable=SC1091
        source "${VENV_PATH}/bin/activate"
        ACTIVATED=1
      elif [ -f "${VENV_PATH}/Scripts/activate" ]; then
        # shellcheck disable=SC1091
        source "${VENV_PATH}/Scripts/activate"
        ACTIVATED=1
      else
        notes+=("Unable to activate backend virtual environment.")
      fi
    fi

    if [ "${ACTIVATED}" -eq 1 ]; then
      if command -v pip >/dev/null 2>&1; then
        pip install --quiet --upgrade pip >/dev/null 2>&1 || notes+=("Failed to upgrade pip in backend environment.")
        if pip install --quiet fastapi uvicorn[standard] python-dotenv httpx pytest pytest-asyncio >/dev/null 2>&1; then
          if command -v uvicorn >/dev/null 2>&1; then
            if uvicorn --version >/dev/null 2>&1; then
              uvicorn_status="pass"
            else
              notes+=("Unable to retrieve uvicorn version.")
            fi
          else
            notes+=("uvicorn command not found after dependency installation.")
          fi

          if command -v pytest >/dev/null 2>&1; then
            pytest --version >/dev/null 2>&1 && pytest_status="pass"
            if pytest -q --disable-warnings --maxfail=1 >/tmp/chunk03_pytest.log 2>&1; then
              tests_status="pass"
            else
              tests_status="fail"
              notes+=("pytest suite failed. Inspect backend/.venv or /tmp/chunk03_pytest.log for details.")
            fi
          else
            notes+=("pytest command unavailable after dependency installation.")
          fi

          if command -v curl >/dev/null 2>&1; then
            server_log="$(mktemp 2>/dev/null || echo "${BACKEND_DIR}/uvicorn-chunk03.log")"
            "${PYTHON_CMD[@]}" -m uvicorn app.main:app --port 8000 --log-level warning >"${server_log}" 2>&1 &
            server_pid=$!
            sleep 1
            for _ in {1..10}; do
              if curl --fail --silent --max-time 3 http://127.0.0.1:8000/health | grep -q '"status"'; then
                health_status="pass"
                break
              fi
              sleep 1
            done
            if [ -n "${server_pid:-}" ]; then
              kill "${server_pid}" >/dev/null 2>&1
              wait "${server_pid}" >/dev/null 2>&1 || true
            fi
            if [ "${health_status}" != "pass" ]; then
              notes+=("Health probe check failed. Review ${server_log} for uvicorn output.")
            fi
          else
            notes+=("curl command not available; skipped runtime health probe.")
          fi
        else
          notes+=("Failed to install backend dependencies via pip.")
        fi
      else
        notes+=("pip unavailable inside the backend virtual environment.")
      fi
    fi
    popd >/dev/null 2>&1 || true
  else
    notes+=("Unable to enter backend directory for verification tasks.")
  fi
fi

if [ "${ACTIVATED}" -eq 1 ] && declare -f deactivate >/dev/null 2>&1; then
  deactivate || true
fi

if [ "${pytest_status}" != "pass" ]; then
  tests_status="fail"
fi

status="pass"
if [ "${files_exist_status}" != "pass" ] || [ "${python_status}" != "pass" ] || [ "${uvicorn_status}" != "pass" ] || [ "${pytest_status}" != "pass" ] || [ "${tests_status}" != "pass" ] || { [ "${health_status}" != "pass" ] && command -v curl >/dev/null 2>&1; }; then
  status="fail"
fi

if [ "${status}" = "pass" ] && [ "${health_status}" != "pass" ]; then
  notes+=("Runtime health probe skipped due to missing curl; consider validating manually.")
fi

if [ "${status}" = "pass" ]; then
  notes+=("All checks passed. Backend endpoints and tests validated successfully.")
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
  "chunk": "NEWS CHUNK 3",
  "created_files": ${created_json},
  "verification": {
    "files_exist": "${files_exist_status}",
    "python_available": "${python_status}",
    "uvicorn_version": "${uvicorn_status}",
    "pytest": "${pytest_status}",
    "tests_passed": "${tests_status}",
    "health_endpoint": "${health_status}",
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
