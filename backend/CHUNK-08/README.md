````markdown
# NEWS CHUNK 8 — Frontend Result Display Enhancement (Backend notes)

This chunk is frontend focused. Backend has no changes for UI layout, but ensures the API returns fields required by the UI (claim_reviews, classifier, sources, notes).

How to run front-end verification:

```bash
cd frontend
npm run dev
```

Checkpoints:

- The API returns `classifier` and `claim_reviews` keys.
- The UI visually prioritises ClaimReview, then evidence and classifier.

````