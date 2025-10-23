# NEWS CHUNK 9 - Testing + Caching Layer (Frontend)

This chunk adds regression coverage for the frontend flow to ensure that repeated cached responses from the backend do not regress the UI. The `api_cache.test.jsx` suite simulates identical responses, confirming that the app renders stable verdict badges and avoids lingering loading states on subsequent submissions.

## Running the test

```bash
cd frontend
npm test -- --run src/tests/api_cache.test.jsx
```

## Verification helper

Use `frontend/CHUNK-09/verify-chunk-09.sh` (or the repository-wide `scripts/verify-chunk-09.sh`) to execute the focused backend tests and the frontend cached-response check in one step.

## Notes

- The frontend still relies on backend caching for performance; this test guards against regressions in the React composition when identical payloads are returned.
- Extend the test with additional UI assertions (e.g. skeleton state transitions) if the component surface grows.
