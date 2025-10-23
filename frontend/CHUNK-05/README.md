# NEWS CHUNK 5 — Integrate NewsAPI Search
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

The frontend now renders the related articles delivered by the backend. The `ResultCard` component lists the top three links with source, publication date, and snippet to help users understand supporting coverage.

## Key changes

- `ResultCard.jsx` formats provider responses, handles empty states, and keeps accessibility considerations in mind (focusable links, readable dates).
- Vitest integration test (`App.test.jsx`) now asserts an article link appears when the API returns sources.

## Running frontend checks

```bash
cd frontend
npm install
npm run test -- --run
```

## Manual verification

1. Start the backend with valid news provider credentials.
2. `npm run dev` inside `frontend`.
3. Submit a headline; observe the “Related Coverage” section populate with article links.

## Next steps

- Surface provider attribution or icons for each article.
- Add skeleton placeholders while news articles load.
- Offer filters (recent vs relevant) once provider support is richer.
