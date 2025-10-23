# NEWS CHUNK 3 — Backend Routing & Test Endpoint
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Purpose

Introduce a production-aligned routing layout, deterministic mock service, and smoke tests for the FastAPI backend powering the Fake News Prediction project.

## Files Added / Updated

- `backend/app/config.py` centralises FastAPI metadata and CORS settings.
- `backend/app/main.py` wires middleware, routers, and the `/health` endpoint.
- `backend/app/routes/check_news.py` exposes the mock analysis route using a service abstraction.
- `backend/app/services/mock_service.py` isolates the static response provider for future replacement.
- `backend/tests/test_health.py` and `backend/tests/test_check_news.py` guard the critical endpoints.
- `backend/pyproject.toml` now lists pytest dependencies to support automated verification.
- `scripts/verify-chunk-03.sh` orchestrates dependency installation, testing, and runtime checks.

## To-do Checklist

- [x] Ensure `backend/` exists in project root.
- [x] Create/update `app/main.py`, `app/routes/check_news.py`, `app/services/mock_service.py`.
- [x] Add Pydantic models for request/response shapes.
- [x] Add pytest tests in `backend/tests/` for health and check-news endpoints.
- [x] Create `CHUNK-03/README.md`, `CHUNK-03/RESULT.json`, and `CHUNK-03/verify-chunk-03.sh`.
- [x] Run verification script and write `CHUNK-03/RESULT.json` with actual results.

## Local Development

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # On Windows use .venv\Scripts\activate
pip install -U pip
pip install -e .
pytest -q
uvicorn app.main:app --reload --port 8000
```

In a separate terminal confirm the health probe:

```bash
curl http://localhost:8000/health
```

## Verification Script

```bash
bash ../scripts/verify-chunk-03.sh
# or
bash CHUNK-03/verify-chunk-03.sh
```

The script validates file presence, installs dependencies if missing, executes pytest, and runs an ephemeral `uvicorn` health-check before updating `CHUNK-03/RESULT.json`.

## Next Steps

Future chunks can replace `mock_service.analyze_text_mock` with integrations against real fact-checking APIs, expand the response contract, and harden error handling based on upstream signals.
