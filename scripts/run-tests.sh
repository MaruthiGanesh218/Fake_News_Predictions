#!/usr/bin/env bash
# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"

printf '\n[%s] Running backend test suite...\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -d "${BACKEND_DIR}" ]; then
  pushd "${BACKEND_DIR}" >/dev/null
  python -m pytest -q
  popd >/dev/null
else
  echo "Backend directory not found; skipping backend tests." >&2
fi

printf '\n[%s] Running frontend unit tests...\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -d "${FRONTEND_DIR}" ]; then
  pushd "${FRONTEND_DIR}" >/dev/null
  if [ -f package.json ]; then
    if command -v npm >/dev/null 2>&1; then
      npm test -- --run
    else
      echo "npm is not available; skipping frontend tests." >&2
    fi
  else
    echo "No package.json detected; skipping frontend tests." >&2
  fi
  popd >/dev/null
else
  echo "Frontend directory not found; skipping frontend tests." >&2
fi

printf '\n[%s] Test run complete.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
