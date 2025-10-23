#!/usr/bin/env bash
# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
BACKEND_CHUNK_DIR="${BACKEND_DIR}/CHUNK-09"
FRONTEND_CHUNK_DIR="${FRONTEND_DIR}/CHUNK-09"
RESULT_FILE="${BACKEND_CHUNK_DIR}/RESULT.json"
TIMESTAMP="$(date -Iseconds)"

mkdir -p "${BACKEND_CHUNK_DIR}"
mkdir -p "${FRONTEND_CHUNK_DIR}"

status="pass"
cache_module_status="pass"
pytest_status="skip"
redis_status="skip"
frontend_status="skip"
notes=()

if [ ! -f "${BACKEND_DIR}/app/utils/cache.py" ]; then
  cache_module_status="fail"
  status="fail"
  notes+=("backend/app/utils/cache.py is missing")
fi

if [ -d "${BACKEND_DIR}" ]; then
  pushd "${BACKEND_DIR}" >/dev/null
  echo "Running targeted pytest suite for Chunk 9..."
  if python -m pytest -q app/tests/test_cache.py app/tests/test_news_cache.py app/tests/test_factcheck_cache.py app/tests/test_classifier_cache.py app/tests/test_check_news_cache.py --maxfail=1; then
    pytest_status="pass"
  else
    pytest_status="fail"
    status="fail"
    notes+=("pytest chunk-9 suite failed")
  fi
  popd >/dev/null
else
  pytest_status="skip"
  notes+=("Backend directory missing; pytest skipped")
  status="fail"
fi

echo "Running in-memory cache smoke test..."
if python <<'PY'
import asyncio
from app.utils.cache import Cache

async def main() -> None:
    backend = Cache(ttl=1, max_items=4)
    await backend.set("key", "value", ttl=0.1)
    assert await backend.get("key") == "value"
    await asyncio.sleep(0.2)
    assert await backend.get("key") is None

asyncio.run(main())
PY
then
  :
else
  status="fail"
  notes+=("In-memory cache smoke test failed")
fi

if [ "${USE_REDIS:-false}" = "true" ] && [ -n "${REDIS_URL:-}" ]; then
  echo "Running Redis cache smoke test..."
  if python <<'PY'
import asyncio
from app.utils import cache

async def main() -> None:
    backend = cache.create_cache("verify.redis", ttl=2, max_items=8)
    if not cache.is_redis_available():
        raise RuntimeError("Redis backend unavailable")
    await backend.set("redis-key", {"value": 1}, ttl=1)
    cached = await backend.get("redis-key")
    assert cached == {"value": 1}

asyncio.run(main())
PY
  then
    redis_status="pass"
  else
    redis_status="fail"
    status="fail"
    notes+=("Redis smoke test failed; ensure Redis is reachable and redis/aioredis is installed")
  fi
else
  notes+=("Redis checks skipped (USE_REDIS not enabled or REDIS_URL missing)")
fi

if [ -d "${FRONTEND_DIR}" ]; then
  pushd "${FRONTEND_DIR}" >/dev/null
  if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
    echo "Running frontend cached-response test..."
    if npm test -- --run src/tests/api_cache.test.jsx; then
      frontend_status="pass"
    else
      frontend_status="fail"
      status="fail"
      notes+=("Frontend cached-response test failed")
    fi
  else
    notes+=("Frontend dependencies unavailable; cached-response test skipped")
  fi
  popd >/dev/null
else
  notes+=("Frontend directory missing; cached-response test skipped")
fi

if [ ${#notes[@]} -eq 0 ]; then
  notes+=("All checks executed")
fi

notes_text="$(printf '%s; ' "${notes[@]}")"
notes_text="${notes_text%; }"

created_files=(
  "backend/app/utils/cache.py"
  "backend/app/tests/test_cache.py"
  "backend/app/tests/test_news_cache.py"
  "backend/app/tests/test_factcheck_cache.py"
  "backend/app/tests/test_classifier_cache.py"
  "backend/app/tests/test_check_news_cache.py"
  "frontend/src/tests/api_cache.test.jsx"
  "backend/CHUNK-09/README.md"
  "backend/CHUNK-09/verify-chunk-09.sh"
  "frontend/CHUNK-09/README.md"
  "frontend/CHUNK-09/verify-chunk-09.sh"
  "scripts/run-tests.sh"
  "scripts/verify-chunk-09.sh"
)

created_json="["
for file in "${created_files[@]}"; do
  created_json+="\"${file}\",";
done
created_json="${created_json%,}"
created_json+"]"

cat >"${RESULT_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 9",
  "created_files": ${created_json},
  "verification": {
    "cache_module_exists": "${cache_module_status}",
    "pytest_core_cache_tests": "${pytest_status}",
    "redis_integration": "${redis_status}",
    "frontend_cached_ui_test": "${frontend_status}",
    "notes": "${notes_text}"
  },
  "status": "${status}"
}
EOF

FRONTEND_RESULT_FILE="${FRONTEND_CHUNK_DIR}/RESULT.json"
cat >"${FRONTEND_RESULT_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "chunk": "NEWS CHUNK 9",
  "created_files": [
    "frontend/src/tests/api_cache.test.jsx"
  ],
  "verification": {
    "frontend_cached_ui_test": "${frontend_status}",
    "notes": "${notes_text}"
  },
  "status": "${status}"
}
EOF

echo "Verification complete. Status: ${status}"