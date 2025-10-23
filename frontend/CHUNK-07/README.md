````markdown
# NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

## Overview

The result card now visualises the backend classifier signal. When the backend supplies `classifier.provider`, `classifier.score`, and `classifier.explanation`, the UI highlights the provider name, shows a fake-likelihood percentage, and surfaces the short explanation. Graceful fallbacks keep the UI stable when the classifier is unavailable.

## Running tests

```bash
cd frontend
npm install
npm run test -- --run
```

Vitest assertions cover the new classifier section in `ResultCard.jsx`.

## Verification

Run the shared verifier (requires Bash) after the backend server is reachable:

```bash
cd scripts
bash verify-chunk-07.sh
```

On Windows without Bash, run the React tests and manually validate the API response using the backend instructions.

## To-do checklist

- [x] Render classifier provider, score, and explanation in `ResultCard.jsx`.
- [x] Extend Vitest integration test to assert classifier UI.
- [x] Ship chunk-specific README, verification wrapper, and RESULT artefact.
- [ ] Add tooltip/expand toggle for longer explanations.

## Next steps

- Introduce per-provider badges or icons for quick recognition.
- Animate score changes when subsequent analyses run.
- Add accessibility hints for classifier explanations (ARIA-live updates).

````