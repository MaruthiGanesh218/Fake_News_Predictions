#!/usr/bin/env bash
# NEWS CHUNK 2 — Frontend Base UI Layout
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
CHUNK_DIR="${FRONTEND_DIR}/CHUNK-02"
RESULT_FILE="${CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

REQUIRED_FILES=(
  "package.json"
  "vite.config.ts"
  "index.html"
  "postcss.config.cjs"
  "tailwind.config.cjs"
  "src/main.jsx"
  "src/App.jsx"
  "src/components/Header.jsx"
  "src/components/InputCard.jsx"
  "src/components/ResultCard.jsx"
  "src/styles/index.css"
  "src/styles/tailwind.css"
  ".env.example"
  "CHUNK-02/README.md"
  "CHUNK-02/RESULT.json"
  "CHUNK-02/verify-chunk-02.sh"
)

missing_files=()
created_files=()
for relative_path in "${REQUIRED_FILES[@]}"; do
  if [ -e "${FRONTEND_DIR}/${relative_path}" ]; then
    created_files+=("frontend/${relative_path}")
  else
    missing_files+=("frontend/${relative_path}")
  fi
done

if [ -f "${PROJECT_ROOT}/scripts/verify-chunk-02.sh" ]; then
  created_files+=("scripts/verify-chunk-02.sh")
else
  missing_files+=("scripts/verify-chunk-02.sh")
fi

files_exist_status="pass"
if [ "${#missing_files[@]}" -ne 0 ]; then
  files_exist_status="fail"
fi

package_scripts_status="fail"
npm_install_status="skip"
build_status="skip"
notes=()

if [ "${files_exist_status}" = "fail" ]; then
  notes+=("Missing required files: ${missing_files[*]}")
fi

if command -v node >/dev/null 2>&1; then
  scripts_check=$(node - <<'EOF' "${FRONTEND_DIR}"
const fs = require('fs');
const path = require('path');
const pkgPath = path.join(process.argv[2], 'package.json');
try {
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  const required = ['dev', 'build', 'preview', 'lint'];
  const hasAll = required.every((key) => pkg.scripts && typeof pkg.scripts[key] === 'string');
  process.stdout.write(hasAll ? 'ok' : 'missing');
} catch (error) {
  process.stdout.write('error');
}
EOF
)
  if [ "${scripts_check}" = "ok" ]; then
    package_scripts_status="pass"
  elif [ "${scripts_check}" = "missing" ]; then
    package_scripts_status="fail"
    notes+=("package.json missing required scripts.")
  else
    package_scripts_status="fail"
    notes+=("Failed to parse package.json for script validation.")
  fi
else
  notes+=("node not found on PATH; package scripts could not be validated.")
fi

if command -v npm >/dev/null 2>&1; then
  if pushd "${FRONTEND_DIR}" >/dev/null 2>&1; then
    install_command="npm install --no-audit --no-fund --no-progress"
    fallback_command=""
    if [ -f package-lock.json ]; then
      install_command="npm ci --no-audit --no-fund --no-progress"
      fallback_command="npm install --no-audit --no-fund --no-progress"
    fi

    if ${install_command} >/dev/null 2>&1; then
      npm_install_status="pass"
    elif [ -n "${fallback_command}" ] && ${fallback_command} >/dev/null 2>&1; then
      npm_install_status="pass"
      notes+=("npm ci failed; npm install succeeded instead.")
    else
      npm_install_status="fail"
      notes+=("Dependency installation failed. Check npm logs for details.")
    fi

    if [ "${npm_install_status}" = "pass" ]; then
      if npm run build >/dev/null 2>&1; then
        build_status="pass"
      else
        build_status="fail"
        notes+=("npm run build failed. Inspect Vite output for diagnostics.")
      fi
    fi

    popd >/dev/null 2>&1 || true
  else
    notes+=("Unable to enter frontend directory for npm operations.")
  fi
else
  notes+=("npm unavailable; skipped dependency installation and build.")
fi

if [ "${package_scripts_status}" != "pass" ] || [ "${npm_install_status}" = "fail" ] || [ "${build_status}" = "fail" ] || [ "${files_exist_status}" != "pass" ]; then
  status="fail"
else
  status="pass"
fi

if [ "${npm_install_status}" = "skip" ] || [ "${build_status}" = "skip" ]; then
  status="fail"
  notes+=("Dependency installation or build was skipped; run locally to complete verification.")
fi

if [ "${status}" = "pass" ]; then
  notes+=("All checks passed. Frontend assets build successfully under Tailwind configuration.")
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
  "chunk": "NEWS CHUNK 2",
  "created_files": ${created_json},
  "verification": {
    "files_exist": "${files_exist_status}",
    "package_scripts": "${package_scripts_status}",
    "npm_install": "${npm_install_status}",
    "build": "${build_status}",
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
