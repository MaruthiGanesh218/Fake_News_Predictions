import React from 'react';

const ICONS = {
  real: (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <path fillRule="evenodd" d="M16.704 5.29a1 1 0 010 1.42l-8.25 8.5a1 1 0 01-1.437.02l-4.25-4.25a1 1 0 011.414-1.414l3.543 3.543L15.29 6.704a1 1 0 011.414 0z" clipRule="evenodd" />
    </svg>
  ),
  fake: (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v4a1 1 0 102 0V7zm-1 7a1.5 1.5 0 110-3 1.5 1.5 0 010 3z" clipRule="evenodd" />
    </svg>
  ),
  unsure: (
    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <path d="M18 10c0 4.418-3.582 8-8 8s-8-3.582-8-8 3.582-8 8-8 8 3.582 8 8zM9 7a1 1 0 012 0c0 1-1 1.5-1 2.5H9C9 8.5 9 7 9 7zM9 13a1 1 0 002 0 1 1 0 00-2 0z" />
    </svg>
  ),
};

function VerdictBadge({ verdict = 'unsure', label }) {
  const normalized = (verdict || 'unsure').toLowerCase();
  const mapping = {
    real: 'bg-emerald-500 text-emerald-900',
    fake: 'bg-rose-500 text-rose-50',
    unsure: 'bg-amber-400 text-amber-900',
  };

  const classes = `inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-semibold ${mapping[normalized] || mapping.unsure}`;
  const readableLabel = label || normalized;

  return (
    <span className={classes} role="status" aria-live="polite" aria-label={`Verdict: ${readableLabel}`}>
      {ICONS[normalized]}
      <span className="capitalize">{readableLabel}</span>
    </span>
  );
}

export default VerdictBadge;
