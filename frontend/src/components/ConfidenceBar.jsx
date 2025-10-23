import React from 'react';

function ConfidenceBar({ confidence = 0.5 }) {
  const pct = Math.round(Math.max(0, Math.min(1, confidence)) * 100);
  return (
    <div className="w-full">
      <div className="flex items-center justify-between">
        <p className="text-xs text-slate-400">Confidence</p>
        <p className="text-xs font-semibold text-slate-100">{pct}%</p>
      </div>
      <div
        className="mt-1 h-3 w-full rounded-full bg-slate-800"
        role="progressbar"
        aria-valuemin="0"
        aria-valuemax="100"
        aria-valuenow={pct}
        aria-label={`Confidence: ${pct}%`}
      >
        <div
          className="h-full rounded-full bg-gradient-to-r from-sky-400 via-indigo-500 to-purple-500"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

export default ConfidenceBar;
