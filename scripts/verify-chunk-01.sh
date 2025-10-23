#!/usr/bin/env bash
# NEWS CHUNK 1 — Project Bootstrap
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: You have full write access. Create files, run checks, save results. Prefer correctness, clarity and reproducibility.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHUNK_DIR="${PROJECT_ROOT}/CHUNK-01"
RESULT_FILE="${CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

REQUIRED_PATHS=(
  "frontend/package.json"
  "frontend/vite.config.ts"
  "frontend/index.html"
  "frontend/src/main.jsx"
  "frontend/src/App.jsx"
  "frontend/src/styles.css"
  "frontend/.env.example"
  "backend/pyproject.toml"
  "backend/app/main.py"
  "backend/app/routes/check_news.py"
  "backend/.env.example"
  "CHUNK-01/README.md"
  "scripts/verify-chunk-01.sh"
  ".gitignore"
  "README.md"
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

backend_health="fail"
frontend_scripts="fail"
notes=()

if [ "${#missing_paths[@]}" -ne 0 ]; then
  notes+=("Missing required paths: ${missing_paths[*]}")
fi

PYTHON_CMD=""
if command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
elif command -v py >/dev/null 2>&1; then
  PYTHON_CMD="py"
else
  notes+=("Python interpreter not found; backend verification skipped.")
fi

if [ -n "${PYTHON_CMD}" ]; then
  if pushd "${PROJECT_ROOT}/backend" >/dev/null 2>&1; then
    VENV_PATH="${PROJECT_ROOT}/backend/.venv"
    if [ ! -d "${VENV_PATH}" ]; then
      ${PYTHON_CMD} -m venv "${VENV_PATH}" >/dev/null 2>&1 || notes+=("Failed to create backend virtual environment.")
    fi

    if [ -d "${VENV_PATH}" ]; then
      if [ -f "${VENV_PATH}/bin/activate" ]; then
        # shellcheck disable=SC1091
        source "${VENV_PATH}/bin/activate"
      elif [ -f "${VENV_PATH}/Scripts/activate" ]; then
        # shellcheck disable=SC1091
        source "${VENV_PATH}/Scripts/activate"
      else
        notes+=("Unable to activate backend virtual environment.")
      fi
    fi

    if command -v pip >/dev/null 2>&1; then
      deps_installed=0
      if ! pip install --quiet --upgrade pip >/dev/null 2>&1; then
        notes+=("Failed to upgrade pip in backend environment.")
      fi
      if pip install --quiet fastapi uvicorn[standard] python-dotenv httpx >/dev/null 2>&1; then
        deps_installed=1
      else
        notes+=("Failed to install backend dependencies.")
      fi

      if [ "${deps_installed}" -eq 1 ]; then
        server_pid=""
        server_log="$(mktemp 2>/dev/null || echo "${PROJECT_ROOT}/backend/uvicorn.log")"
        ${PYTHON_CMD} -m uvicorn app.main:app --port 8000 --log-level warning >"${server_log}" 2>&1 &
        server_pid=$!
        sleep 1
        if command -v curl >/dev/null 2>&1; then
          for _ in {1..10}; do
            if curl --fail --silent --show-error --max-time 3 http://localhost:8000/health | grep -q '"status"'; then
              backend_health="pass"
              break
            fi
            sleep 1
          done
        else
          notes+=("curl not available; backend health probe skipped.")
        fi

        if [ -n "${server_pid}" ]; then
          kill "${server_pid}" >/dev/null 2>&1
          wait "${server_pid}" >/dev/null 2>&1 || true
        fi

        if [ "${backend_health}" != "pass" ]; then
          notes+=("Backend health probe did not return the expected status. Review ${server_log}.")
        fi
      fi
    else
      notes+=("pip unavailable after activating backend environment.")
    fi

    if declare -f deactivate >/dev/null 2>&1; then
      deactivate || true
    fi
    popd >/dev/null 2>&1 || true
  else
    notes+=("Unable to enter backend directory.")
  fi
fi

if command -v npm >/dev/null 2>&1; then
  if pushd "${PROJECT_ROOT}/frontend" >/dev/null 2>&1; then
    ci_attempted=0
    ci_succeeded=0
    if [ -f package-lock.json ]; then
      ci_attempted=1
      if npm ci --no-audit --no-fund >/dev/null 2>&1; then
        ci_succeeded=1
      else
        notes+=("npm ci failed; trying npm install instead.")
      fi
    fi

    if [ "${ci_attempted}" -eq 0 ] || [ "${ci_succeeded}" -eq 0 ]; then
      if npm install --no-audit --no-fund >/dev/null 2>&1; then
        ci_succeeded=1
      else
        notes+=("npm install failed.")
      fi
    fi

    if npm run build -- --mode production >/dev/null 2>&1; then
      frontend_scripts="pass"
    else
      notes+=("npm run build failed.")
    fi
    popd >/dev/null 2>&1 || true
  else
    notes+=("Unable to enter frontend directory.")
  fi
else
  notes+=("npm not found; frontend verification skipped.")
fi

if [ "${backend_health}" = "pass" ] && [ "${frontend_scripts}" = "pass" ] && [ "${#missing_paths[@]}" -eq 0 ]; then
  status="pass"
else
  status="fail"
fi

if [ "${status}" = "pass" ]; then
  notes+=("All checks passed. Backend /health returned ok. Frontend build completed.")
fi

if [ "${#notes[@]}" -eq 0 ]; then
  notes_text="All checks passed. Backend /health returned ok. Frontend build completed."
else
  notes_text="$(printf '%s; ' "${notes[@]}")"
  notes_text="${notes_text%; }"
fi

created_json="["
for path in "${created_files[@]}"; do
  created_json+="\"${path//"/\\"}\","
done
created_json="${created_json%,}" # trim trailing comma
created_json+="]"

cat >"${RESULT_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 1",
  "created_files": ${created_json},
  "verification": {
    "backend_health": "${backend_health}",
    "frontend_scripts": "${frontend_scripts}",
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
