# NEWS CHUNK 5 — Integrate NewsAPI Search
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

This chunk wires live(ish) news discovery into the `/check-news` FastAPI route. The backend now hosts a configurable `news_service` that queries NewsAPI, GNews, or NewsData, normalises the response, and shares the three most relevant articles with the frontend. We also refreshed the frontend result card to surface those links.

## What changed

- Added `app/services/news_service.py` with async provider adapters, LRU + TTL caching, and defensive error handling.
- Expanded `app/config.py` and `.env.example` so operators can pick a provider and set API keys without code changes.
- Updated `/check-news` to call the news service, append provider notes, and return structured `sources` objects.
- Refreshed the React `ResultCard` to render article links, dates, and snippets, plus friendlier fallbacks.
- Authored targeted pytest suites for the news service (using `respx` to mock HTTP) and updated the integration test to ensure `sources` are shaped correctly.

## Environment configuration

Create a `.env` in the backend folder and set the provider plus credentials. Example values:

```bash
NEWS_PROVIDER=newsapi
NEWSAPI_KEY=sk-live-replace-with-real
NEWS_CACHE_TTL_SECONDS=900
NEWS_CACHE_MAXSIZE=128
```

To switch to GNews:

```bash
NEWS_PROVIDER=gnews
GNEWS_KEY=glive-your-token
```

For NewsData:

```bash
NEWS_PROVIDER=newsdata
NEWSDATA_KEY=ndp-live-key
```

You can override the HTTP endpoint URLs, default result limit, timeout, or cache sizing via similarly named variables listed in `.env.example`.

## Caching behaviour

The in-memory cache stores up to `NEWS_CACHE_MAXSIZE` entries for `NEWS_CACHE_TTL_SECONDS` (default 10 minutes). Queries are normalised (trimmed and lowercased) to increase hit rate. Cache is process-local; restart the server to clear, or call the helper during tests.

## Running tests

```bash
cd backend
pip install -e .
pytest -q tests/test_news_service.py tests/test_check_news.py
```

The suite uses `respx` to intercept outbound HTTP calls, so no network access is required.

## Verification steps

1. Ensure `.env` contains the provider of choice plus API key.
2. `uvicorn app.main:app --reload`
3. `curl -X POST http://localhost:8000/check-news -d '{"text":"Space exploration breakthrough"}' -H 'Content-Type: application/json'`
4. Confirm the JSON includes a `sources` list with article metadata.

## Next steps (Chunk 6 preview)

- Replace mock inference with fact-check/credibility scoring using FactCheck tools.
- Surface explanation snippets and confidence bands on the frontend.
- Introduce persistence for aggregated engagement signals.

## To-do checklist

- [x] Add `news_service.py` with provider adapters and caching.
- [x] Update `config.py` and `.env.example` with provider settings and placeholders.
- [x] Update `/check-news` route to include `sources` from `news_service`.
- [x] Update frontend `ResultCard.jsx` to render returned articles.
- [x] Add unit tests for `news_service` and update integration tests.
- [x] Create `CHUNK-05/README.md`, `CHUNK-05/RESULT.json`, and `CHUNK-05/verify-chunk-05.sh`.
- [x] Run verification and write `CHUNK-05/RESULT.json`.
