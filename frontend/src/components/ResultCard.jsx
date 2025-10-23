import VerdictBadge from './VerdictBadge.jsx';
import ConfidenceBar from './ConfidenceBar.jsx';
import ClaimReviewCard from './ClaimReviewCard.jsx';
import EvidenceList from './EvidenceList.jsx';
import ClassifierSummary from './ClassifierSummary.jsx';

const STATUS_COLORS = {
  real: 'bg-emerald-500/90 text-emerald-950',
  fake: 'bg-rose-500/90 text-rose-50',
  unsure: 'bg-amber-400/90 text-amber-950'
};

function formatConfidence(value) {
  const numeric = Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
  return Math.round(numeric * 100);
}

function ResultCard({ result, isLoading, error }) {
  const verdict = (result?.verdict || 'unsure').toLowerCase();
  const badgeClass = STATUS_COLORS[verdict] ?? STATUS_COLORS.unsure;
  const confidencePct = formatConfidence(result?.confidence);
  const sources = Array.isArray(result?.sources) ? result.sources : [];
  const claimReviews = Array.isArray(result?.claim_reviews) ? result.claim_reviews : [];
  const classifier = typeof result?.classifier === 'object' && result.classifier !== null ? result.classifier : null;
  const notesContent = typeof result?.notes === 'string' && result.notes.trim().length > 0
    ? result.notes
    : 'No notes yet.';

  return (
    <section
      className="relative flex min-h-[420px] flex-col gap-6 rounded-3xl border border-slate-800 bg-slate-900/30 p-6 shadow-inner shadow-slate-950/40"
      aria-live="polite"
    >
      <header className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-slate-100">Analysis Result</h2>
          <p className="text-sm text-slate-400">Outputs update automatically when the analysis finishes.</p>
        </div>
        <span className={`rounded-full px-4 py-1 text-xs font-semibold uppercase tracking-widest ${badgeClass}`}>
          {verdict}
        </span>
      </header>

      {isLoading && (
        <div className="flex flex-1 flex-col justify-center gap-3" role="status">
          <div className="h-3 w-3/5 animate-pulse rounded-full bg-slate-700/80" />
          <div className="h-3 w-2/5 animate-pulse rounded-full bg-slate-700/60" />
          <div className="h-3 w-4/5 animate-pulse rounded-full bg-slate-700/70" />
          <p className="text-sm text-slate-400">Running mock inference...</p>
        </div>
      )}

      {!isLoading && !result && !error && (
        <div className="flex flex-1 flex-col justify-center gap-4 text-sm text-slate-400">
          <p>No assessment yet. Submit a headline to preview the inference layout.</p>
          <p>The card will display verdict, confidence score, and supporting evidence once available.</p>
        </div>
      )}

      {!isLoading && error && (
        <div className="flex flex-1 flex-col justify-center gap-4">
          <p className="rounded-2xl border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-200" role="alert">
            {error}
          </p>
        </div>
      )}

      {!isLoading && result && (
        <div className="flex flex-1 flex-col gap-6">
          <section className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <VerdictBadge verdict={verdict} label={verdict} />
                <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Result</h3>
              </div>
              <div className="text-xs text-slate-400">{confidencePct}% confidence</div>
            </div>
            <ConfidenceBar confidence={result?.confidence} />
          </section>

          <section className="flex flex-col gap-2">
            <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Evidence</h3>
            {result.evidence?.length ? (
              <ul className="list-disc space-y-2 pl-5 text-sm text-slate-200">
                {result.evidence.map((item, index) => (
                  <li key={`${item}-${index}`}>{item}</li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-slate-400">No evidence yet.</p>
            )}
          </section>

          <section className="flex flex-col gap-3">
            <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Fact Check Insights</h3>
            {claimReviews.length ? (
              <div className="flex flex-col gap-3">
                {claimReviews.slice(0, 2).map((review, i) => (
                  <ClaimReviewCard key={`${review.url || i}-${i}`} claimReview={review} />
                ))}
              </div>
            ) : (
              <p className="text-sm text-slate-400">Fact-check providers did not return any ClaimReview entries.</p>
            )}
          </section>

          <section className="flex flex-col gap-3">
            <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Classifier Signal</h3>
            <ClassifierSummary classifier={classifier} />
          </section>

          <section className="flex flex-col gap-3">
            <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Related Coverage</h3>
            <EvidenceList sources={sources} />
          </section>

          <section className="flex flex-col gap-2">
            <h3 className="text-sm font-semibold uppercase tracking-wide text-slate-400">Notes</h3>
            <p className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4 text-sm text-slate-200">
              {notesContent}
            </p>
          </section>
        </div>
      )}
    </section>
  );
}

export default ResultCard;
