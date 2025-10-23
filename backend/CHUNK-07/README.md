````markdown
# NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

This chunk adds an optional RapidAPI-backed fake-news classifier to the `/check-news` route. The backend now requests an ML score for the submitted text, falls back to a deterministic local heuristic when RapidAPI is unavailable, and blends that score with the news heuristics when no third-party ClaimReview verdict is present.

## Configuration

Update `backend/.env` with classifier settings:

```bash
CLASSIFIER_PROVIDER=rapidapi        # rapidapi | local
CLASSIFIER_CACHE_TTL_SECONDS=900    # seconds to cache classifier responses
CLASSIFIER_CACHE_MAXSIZE=128        # max cached entries
CLASSIFIER_HTTP_TIMEOUT_SECONDS=8
RAPIDAPI_CLASSIFIER_ENDPOINT=https://fake-news-detector.p.rapidapi.com/predict
RAPIDAPI_KEY=replace-with-your-key
RAPIDAPI_HOST=fake-news-detector.p.rapidapi.com
```

Set `CLASSIFIER_PROVIDER=local` to rely solely on the heuristic fallback. When RapidAPI keys are missing the service logs a warning and automatically uses the local stub.

## Score mapping

The classifier returns a score between 0 (likely real) and 1 (likely fake). Verdict mapping when ClaimReview data is absent:

- `score ≥ 0.70` → **fake** (confidence 0.90)
- `score ≤ 0.30` → **real** (confidence 0.85)
- otherwise → **unsure** (confidence 0.60)

The final blended score is computed as `0.6 * classifier_score + 0.4 * news_contradiction_score` where the latter is a lightweight heuristic over the returned sources.

## Running tests

```bash
cd backend
pip install -e .
pytest -q tests/test_classifier_service.py tests/test_check_news.py
```

The new `tests/test_classifier_service.py` file uses `respx` to mock RapidAPI responses and asserts caching plus fallback behaviour.

## Verification

Execute the automated verifier (requires a Bash-capable shell):

```bash
cd scripts
bash verify-chunk-07.sh
```

On Windows without Bash, run the individual steps manually:

1. `pytest -q tests/test_classifier_service.py tests/test_check_news.py`
2. `uvicorn app.main:app --port 8014`
3. `curl -X POST http://127.0.0.1:8014/check-news -H 'Content-Type: application/json' -d '{"text":"Example headline"}'`
4. Confirm the payload contains `classifier.provider` and `classifier.score`.

## To-do checklist

- [x] Implement `classifier_service.py` with RapidAPI integration, caching, and local fallback.
- [x] Blend classifier output in `/check-news` alongside ClaimReview/news signals.
- [x] Add pytest coverage for the classifier service and updated orchestration.
- [x] Update frontend to display classifier information.
- [x] Author chunk-specific README, verification script, and RESULT artefact.
- [ ] Promote local heuristic to a trained model with persisted weights (future work).

## Next steps

- Replace the heuristic fallback with a persisted TF–IDF or transformer model.
- Record classifier confidence trends for analytics and future retraining.
- Expose provider latency metrics to aid capacity planning.

````