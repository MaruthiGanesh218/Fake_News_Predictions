import React, { useState } from 'react';

function ClassifierSummary({ classifier }) {
  const [open, setOpen] = useState(false);
  if (!classifier) {
    return <p className="text-sm text-slate-400">Classifier signal unavailable.</p>;
  }
  const scorePct = Math.round((classifier.score || 0) * 100);

  return (
    <div className="rounded-2xl border border-sky-500/30 bg-sky-500/10 p-4 text-sm text-sky-100">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-xs font-semibold">{classifier.provider || 'unknown provider'}</div>
          <div className="text-xs text-sky-200">Score: {scorePct}% fake likelihood</div>
        </div>
        <div>
          {classifier.explanation ? (
            <button
              onClick={() => setOpen((v) => !v)}
              aria-expanded={open}
              aria-controls="classifier-explanation"
              className="text-xs font-medium text-sky-200"
            >
              {open ? 'Hide explanation' : 'Read explanation'}
            </button>
          ) : null}
        </div>
      </div>
      {open && classifier.explanation ? (
        <div id="classifier-explanation" className="mt-3 text-xs text-sky-100/90">
          {classifier.explanation}
        </div>
      ) : null}
    </div>
  );
}

export default ClassifierSummary;
