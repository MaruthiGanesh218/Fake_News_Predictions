# NEWS CHUNK 4 — Frontend–Backend Integration
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Purpose

Wire the Vite React frontend to the FastAPI mock backend, surface resilient loading and error states, and validate behaviour using mocked integration tests.

## Files Added / Updated

- `frontend/src/services/api.js` exposes `checkNews` for network operations.
- `frontend/src/App.jsx` now drives loading, error, and result states based on API responses.
- `frontend/src/components/InputCard.jsx` displays validation, error banners, and disable states.
- `frontend/src/components/ResultCard.jsx` renders returned payloads or alerts on failures.
- `frontend/src/tests/*.test.jsx` validates success, loading, and failure paths using Vitest + Testing Library.
- `frontend/package.json` adds testing dependencies and script.
- `scripts/verify-chunk-04.sh` automates dependency installation, testing, and runtime checks.

## To-do Checklist

- [x] Create/modify `frontend/src/services/api.js` with `checkNews` implementation.
- [x] Update `App.jsx` and `InputCard.jsx` to call `checkNews` and manage loading/error/result state.
- [x] Update `ResultCard.jsx` to display real data returned by API.
- [x] Add Vitest + Testing Library devDeps to `package.json` and create `frontend/src/tests/` with integration tests.
- [x] Add `CHUNK-04/README.md`, `CHUNK-04/RESULT.json`, and `CHUNK-04/verify-chunk-04.sh`.
- [x] Run verification and write `CHUNK-04/RESULT.json` with outcomes.

## Running the Frontend

```bash
cd frontend
npm install
npm run dev
```

Ensure the FastAPI backend runs on `http://localhost:8000` or update `VITE_API_BASE_URL` in `.env` accordingly.

## Running the Backend

```bash
cd backend
python -m uvicorn app.main:app --reload --port 8000
```

## Running Tests

```bash
cd frontend
npm install
npm run test
```

Vitest executes the mocked integration suite. Tests rely on `vi.mock` to isolate network behaviour.

## Verification Script

```bash
bash ../scripts/verify-chunk-04.sh
# or
bash CHUNK-04/verify-chunk-04.sh
```

The script checks file presence, installs dependencies, runs Vitest in CI mode, and reports outcomes in `CHUNK-04/RESULT.json`.

## Notes

- Network calls use `fetch` with a 10-second timeout for safety.
- Tests rely on mocked API responses to remain stable without a live backend.
- Update `.env` variables for different backend URLs as the project evolves.
