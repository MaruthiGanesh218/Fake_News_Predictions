#!/usr/bin/env bash
# NEWS CHUNK 8 - Frontend Result Display Enhancement

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
CHUNK_DIR="${FRONTEND_DIR}/CHUNK-08"
RESULT_FILE="${CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

mkdir -p "${CHUNK_DIR}"

REQUIRED_PATHS=(
  "frontend/src/components/VerdictBadge.jsx"
  "frontend/src/components/ConfidenceBar.jsx"
  "frontend/src/components/ClaimReviewCard.jsx"
  "frontend/src/components/EvidenceList.jsx"
  "frontend/src/components/ClassifierSummary.jsx"
  "frontend/src/components/ResultCard.jsx"
  "frontend/src/tests/VerdictBadge.test.jsx"
  "frontend/src/tests/ConfidenceBar.test.jsx"
  "frontend/src/tests/ResultCard.test.jsx"
)

missing=()
created=()
for p in "${REQUIRED_PATHS[@]}"; do
  if [ -e "${PROJECT_ROOT}/${p}" ]; then
    created+=("${p}")
  else
    missing+=("${p}")
  fi
done

status="pass"
if [ "${#missing[@]}" -ne 0 ]; then
  status="fail"
fi

tests_status="skip"
notes=()

if command -v npm >/dev/null 2>&1; then
  if pushd "${FRONTEND_DIR}" >/dev/null 2>&1; then
    if npm ci --no-audit --no-fund --no-progress >/dev/null 2>&1; then
      if npm run test -- --run >/dev/null 2>&1; then
        tests_status="pass"
      else
        tests_status="fail"
        status="fail"
        notes+=("Vitest tests failed. Run locally to inspect failures.")
      fi
    else
      tests_status="fail"
      status="fail"
      notes+=("npm install failed; cannot run tests.")
    fi
    popd >/dev/null 2>&1 || true
  else
    notes+=("Cannot enter frontend directory.")
    status="fail"
  fi
else
  notes+=("npm not available; tests skipped.")
  tests_status="skip"
fi

if [ "${#notes[@]}" -eq 0 ]; then
  notes+=("All checks executed.")
fi

notes_text="$(printf '%s; ' "${notes[@]}")"
notes_text="${notes_text%; }"

escaped_created_files="["
for p in "${created[@]}"; do
  escaped_created_files+="\"${p}\"," 
 done
escaped_created_files="${escaped_created_files%,}"
escaped_created_files+"]"

cat >"${RESULT_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 8",
  "created_files": ${escaped_created_files},
  "verification": {
    "files_exist": "${status}",
    "tests_run": "${tests_status}",
    "accessibility_checks": "skip",
    "notes": "${notes_text}"
  },
  "status": "${status}"
}
EOF

if [ "${status}" = "pass" ]; then
  exit 0
else
  exit 1
fi
