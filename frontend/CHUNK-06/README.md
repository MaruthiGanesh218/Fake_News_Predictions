````markdown
# NEWS CHUNK 6 — Integrate Google Fact Check API
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

The `ResultCard` now highlights ClaimReview verdicts returned by the backend. When fact-check data is present we give it priority, surfacing the truth rating, claim summary, publisher, and review date before falling back to related coverage links.

## Key changes

- `ResultCard.jsx` renders a dedicated "Fact Check Insights" section, showing up to two ClaimReview entries with styled verdict chips and excerpts.
- The Vitest integration test (`App.test.jsx`) exercises the new UI by mocking a response that includes both `claim_reviews` and news sources.

## Running frontend checks

```bash
cd frontend
npm install
npm run test -- --run
```

## Manual verification

1. Start the backend (optionally with a mock Fact Check API).
2. `npm run dev` inside `frontend`.
3. Submit a claim that the backend can fact-check; observe the new fact-check verdicts render above related coverage.

## To-do checklist

- [x] Add ClaimReview UI section with accessibility-safe defaults.
- [x] Update integration tests to cover fact-check data.
- [x] Create `CHUNK-06` documentation and verification artefacts.

````