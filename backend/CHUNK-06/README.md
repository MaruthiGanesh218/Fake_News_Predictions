````markdown
# NEWS CHUNK 6 — Integrate Google Fact Check API
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

This chunk promotes third-party fact-check intelligence into the `/check-news` route. We added a dedicated `factcheck_service` that calls the Google Fact Check Tools API, normalises ClaimReview metadata, and caches responses. When ClaimReview data is found, the backend now prioritises the fact-check verdict over the mock verdict before falling back to news coverage.

## What changed

- Introduced `app/services/factcheck_service.py` with async httpx calls, TTL/LRU caching, and defensive error handling.
- Expanded `app/config.py` and `.env.example` with fact-check provider settings (timeouts, cache sizing, API endpoint).
- Updated `app/services/mock_service.py` and `/check-news` route so responses always include a `claim_reviews` array and optionally promote verdict/confidence from the strongest match.
- Added pytest coverage for the new service (`tests/test_factcheck_service.py`) plus refreshed the route integration test to assert `claim_reviews` are present.
- Created chunk-specific verification script and documentation artefacts.

## Environment configuration

Populate the backend `.env` with your Google Fact Check API key and optional tuning knobs:

```bash
FACTCHECK_PROVIDER=google
GOOGLE_FACTCHECK_KEY=your-api-key
FACTCHECK_DEFAULT_LIMIT=5
FACTCHECK_CACHE_TTL_SECONDS=900
FACTCHECK_HTTP_TIMEOUT_SECONDS=8
```

You can override the `GOOGLE_FACTCHECK_ENDPOINT` if you are pointing at a mock server. When the provider key is missing, the service gracefully returns an empty list and the route falls back to news coverage.

## Running tests

```bash
cd backend
pip install -e .
pytest -q tests/test_factcheck_service.py tests/test_news_service.py tests/test_check_news.py
```

`respx` intercepts outbound HTTP calls, so the Fact Check API is never hit during the suite.

## Verification steps

1. Ensure the `.env` contains a valid `GOOGLE_FACTCHECK_KEY` (or leave blank to test the graceful fallback).
2. `uvicorn app.main:app --reload`
3. `curl -X POST http://localhost:8000/check-news -H 'Content-Type: application/json' -d '{"text":"Example fact-check claim"}'`
4. Confirm the JSON payload includes `claim_reviews` (empty or populated) and that the verdict reflects fact-check truth ratings when available.

## To-do checklist

- [x] Add `factcheck_service.py` with caching and normalisation helpers.
- [x] Extend configuration and env placeholders for fact-check settings.
- [x] Update `/check-news` to prefer ClaimReview verdicts before querying news sources.
- [x] Update mock response contract and route tests to include `claim_reviews`.
- [x] Add pytest coverage for the fact-check service.
- [x] Author `CHUNK-06` verification script, README, and RESULT artifact.

````