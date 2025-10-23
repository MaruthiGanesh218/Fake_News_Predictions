# NEWS CHUNK 9 - Testing + Caching Layer

This chunk introduces reusable caching utilities, integrates them into the heavy service calls, and adds regression tests that confirm cached paths reduce downstream traffic. It also brings a verification script that exercises critical cache scenarios in CI environments.

## Configuration

Update `.env` (or rely on defaults) to tune cache behaviour:

- `CACHE_TTL_SECONDS` – default TTL for shared caches (in seconds).
- `CACHE_MAX_ITEMS` – maximum items retained by in-memory caches before LRU eviction.
- `USE_REDIS` – set to `true` to enable the Redis adapter.
- `REDIS_URL` – connection string for Redis (e.g. `redis://localhost:6379/0`).
- Existing per-service knobs (`NEWS_CACHE_TTL_SECONDS`, `FACTCHECK_CACHE_TTL_SECONDS`, `CLASSIFIER_CACHE_TTL_SECONDS`, etc.) still apply and override the defaults where needed.

To run with Redis locally:

```bash
docker run --rm -p 6379:6379 redis:7
export USE_REDIS=true
export REDIS_URL=redis://localhost:6379/0
```

## Running tests

```bash
# Backend cache suite
python -m pytest -q backend/app/tests/test_cache.py backend/app/tests/test_news_cache.py \
  backend/app/tests/test_factcheck_cache.py backend/app/tests/test_classifier_cache.py \
  backend/app/tests/test_check_news_cache.py

# Full test run (backend + frontend)
./scripts/run-tests.sh
```

The verification harness lives in `scripts/verify-chunk-09.sh` and can be invoked at the repository root. It reruns the focused pytest selection, performs in-memory and optional Redis smoke tests, and writes `backend/CHUNK-09/RESULT.json`.

## Force-refreshing caches

The `/check-news` endpoint now accepts `?refresh=true` to bypass cached entries for that request. Service functions also honour a `force_refresh` keyword argument so diagnostics can be scripted directly in Python.

## To-do checklist

- [x] Implement `backend/app/utils/cache.py` (in-memory + Redis adapter).
- [x] Integrate `@cached` into `news_service`, `factcheck_service`, and `classifier_service`.
- [x] Add unit tests for the cache and service-level cache tests.
- [x] Add frontend test for cached API responses.
- [x] Add `scripts/run-tests.sh` and `scripts/verify-chunk-09.sh`.
- [x] Create chunk-09 README, RESULT.json scaffolding, and verification script wrappers.
- [x] Run verification and write `CHUNK-09/RESULT.json`.

## Next steps

- Capture cache hit/miss metrics (e.g. via logging or Prometheus exporters).
- Expose operational dashboards to monitor key eviction and TTL expiries.
- Evaluate redis-cluster or managed cache services for production hardening.
