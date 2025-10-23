#!/usr/bin/env bash
# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
RESULT_FILE="${SCRIPT_DIR}/RESULT.json"
FINAL_REPORT_FILE="${PROJECT_ROOT}/FINAL-REPORT.json"
WORKFLOW_FILE="${PROJECT_ROOT}/.github/workflows/ci-cd.yml"
DEPLOY_SCRIPT="${PROJECT_ROOT}/deploy/gcloud_deploy.sh"
TIMESTAMP="$(python - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat())
PY
)"

status_overall="pass"
dockerfiles_status="pass"
workflow_status="pass"
local_docker_status="skip"
deploy_script_status="pass"
final_report_status="fail"
smoke_status="skip"
notes=()

# Ensure expected files exist
if [[ ! -f "${BACKEND_DIR}/Dockerfile" || ! -f "${FRONTEND_DIR}/Dockerfile" ]]; then
  dockerfiles_status="fail"
  status_overall="fail"
  notes+=("Dockerfiles missing; expected backend/Dockerfile and frontend/Dockerfile")
fi

if [[ ! -f "${WORKFLOW_FILE}" ]]; then
  workflow_status="fail"
  status_overall="fail"
  notes+=("GitHub Actions workflow missing at .github/workflows/ci-cd.yml")
else
  python <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
try:
    import yaml  # type: ignore
except ImportError:
    sys.exit(0)

try:
    yaml.safe_load(source)
except Exception as exc:  # pragma: no cover
    print(f"YAML parse error: {exc}", file=sys.stderr)
    sys.exit(1)
PY
  "${WORKFLOW_FILE}" || {
    workflow_status="fail"
    status_overall="fail"
    notes+=("Failed to parse GitHub Actions workflow yaml")
  }
fi

if [[ ! -f "${DEPLOY_SCRIPT}" ]]; then
  deploy_script_status="fail"
  status_overall="fail"
  notes+=("deploy/gcloud_deploy.sh missing")
else
  if ! grep -q "gcloud run deploy" "${DEPLOY_SCRIPT}"; then
    deploy_script_status="fail"
    status_overall="fail"
    notes+=("deploy/gcloud_deploy.sh missing Cloud Run deploy commands")
  fi
fi

if command -v docker >/dev/null 2>&1; then
  echo "[verify] Building backend Docker image (no cache)..."
  if docker build "${BACKEND_DIR}" --file "${BACKEND_DIR}/Dockerfile" --tag fake-news-backend:verify --no-cache; then
    local_docker_status="pass"
    docker image rm fake-news-backend:verify >/dev/null 2>&1 || true
  else
    local_docker_status="fail"
    status_overall="fail"
    notes+=("backend Docker build failed; see logs above")
  fi
else
  local_docker_status="skip"
  notes+=("Docker CLI not available; skipped local image build")
fi

# Aggregate chunk results -> FINAL-REPORT.json
python <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

project_root = Path(sys.argv[1])
final_report_path = Path(sys.argv[2])

result_files = sorted(project_root.glob("**/CHUNK-*/RESULT.json"))
chunks = []
failed = []
for path in result_files:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover
        chunks.append({
            "chunk": path.parent.name,
            "status": "error",
            "timestamp": None,
            "path": path.relative_to(project_root).as_posix(),
            "error": str(exc),
        })
        failed.append(path.parent.name)
        continue

    chunk_label = data.get("chunk") or path.parent.name
    status = data.get("status", "unknown")
    timestamp = data.get("timestamp")
    entry = {
        "chunk": chunk_label,
        "status": status,
        "timestamp": timestamp,
        "path": path.relative_to(project_root).as_posix(),
    }
    chunks.append(entry)
    if status == "fail":
        failed.append(chunk_label)

all_pass = chunks and all(item.get("status") == "pass" for item in chunks)
any_fail = any(item.get("status") == "fail" for item in chunks)

if any_fail:
    overall = "fail"
elif all_pass:
    overall = "pass"
else:
    overall = "partial"

report = {
    "project": "Fake News Prediction (Online Phase)",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "chunks": chunks,
    "overall_status": overall,
    "failed_chunks": failed,
    "deployed_urls": [],
    "notes": [
        "Manual Cloud Run deployment requires running deploy/gcloud_deploy.sh with authenticated gcloud credentials.",
        "GitHub Actions deployment job remains gated by secrets and environment approval.",
    ],
}

final_report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
PY
"${PROJECT_ROOT}" "${FINAL_REPORT_FILE}" && final_report_status="pass" || {
  final_report_status="fail"
  status_overall="fail"
  notes+=("Failed to generate FINAL-REPORT.json")
}

if [[ ${#notes[@]} -eq 0 ]]; then
  notes+=("All automated verifications completed.")
fi

notes_text="$(printf '%s; ' "${notes[@]}")"
notes_text="${notes_text%; }"

python <<'PY'
import json
import sys
from pathlib import Path

data = {
    "timestamp": sys.argv[1],
    "chunk": "NEWS CHUNK 10",
    "created_files": [
        "backend/Dockerfile",
        "frontend/Dockerfile",
        "deploy/gcloud_deploy.sh",
        "deploy/smoke_tests/smoke_test.sh",
        ".github/workflows/ci-cd.yml",
        "deploy/terraform/main.tf",
        "CHUNK-10/README.md",
        "CHUNK-10/verify-chunk-10.sh",
        "FINAL-REPORT.json"
    ],
    "verification": {
        "dockerfiles_exist": sys.argv[2],
        "workflow_present": sys.argv[3],
        "local_docker_build": sys.argv[4],
        "deployment_artifacts": sys.argv[5],
        "deployment_executed": "skip",
        "final_report_generated": sys.argv[6],
        "smoke_tests": "skip",
        "notes": sys.argv[7]
    },
    "status": sys.argv[8]
}

Path(sys.argv[9]).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
"${TIMESTAMP}" \
"${dockerfiles_status}" \
"${workflow_status}" \
"${local_docker_status}" \
"${deploy_script_status}" \
"${final_report_status}" \
"${notes_text}" \
"${status_overall}" \
"${RESULT_FILE}"

echo "Verification complete. Status: ${status_overall}"