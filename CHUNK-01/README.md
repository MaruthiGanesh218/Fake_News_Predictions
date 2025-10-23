# NEWS CHUNK 1 — Project Bootstrap
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: You have full write access. Create files, run checks, save results. Prefer correctness, clarity and reproducibility.

## Purpose

Bootstrap the Fake News Prediction project with a minimal, reproducible scaffold for both frontend and backend services plus verification tooling.

## Completed Checklist

- Create root folders and files exactly as listed.
- Initialize frontend minimal React+Vite scaffold and include `src/App.jsx` with placeholder UI.
- Initialize backend FastAPI scaffold with GET `/health` and POST `/check-news` returning the mock JSON.
- Add `.env.example` files with placeholders.
- Add `.gitignore` and root `README.md`.
- Create `CHUNK-01/README.md`, `scripts/verify-chunk-01.sh`, and `CHUNK-01/RESULT.json` (result is updated after verification).
- Run verification script and write actual `CHUNK-01/RESULT.json` with outcomes.
- Ensure no real API keys are committed; only use `.env.example`.

## Verification Command

Run the automated checks for this chunk:

```bash
bash scripts/verify-chunk-01.sh
```

The script handles dependency bootstrapping, backend health probing, and frontend build verification.

## Result Interpretation

After the script executes, inspect `CHUNK-01/RESULT.json` for a structured summary. The `status` field reports overall success (`pass`/`fail`), while the `verification` object captures backend and frontend outcomes plus contextual notes.
