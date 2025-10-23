import React from 'react';

function ClaimReviewCard({ claimReview }) {
  if (!claimReview) return null;
  const reviewedOn = claimReview.review_date ? new Date(claimReview.review_date).toLocaleDateString() : null;
  const rating = claimReview.truth_rating || 'Review';

  return (
    <article className="rounded-2xl border border-emerald-600/20 bg-emerald-500/8 p-4" aria-live="polite">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h4 className="text-sm font-semibold text-emerald-100">{rating}</h4>
          <p className="mt-1 text-xs text-emerald-200">{claimReview.author || claimReview.publisher}</p>
        </div>
        <div className="text-xs text-emerald-200">{reviewedOn}</div>
      </div>
      {claimReview.claim ? <p className="mt-3 text-sm text-emerald-100">{claimReview.claim}</p> : null}
      {claimReview.excerpts ? <p className="mt-2 text-sm text-emerald-100/90">{claimReview.excerpts}</p> : null}
      <div className="mt-3">
        <a href={claimReview.url} target="_blank" rel="noopener noreferrer" className="text-xs font-semibold text-emerald-200">
          Read full fact-check
        </a>
      </div>
    </article>
  );
}

export default ClaimReviewCard;
