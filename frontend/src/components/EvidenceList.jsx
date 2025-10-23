import React from 'react';

function ArticleCard({ article }) {
  const published = article?.publishedAt ? new Date(article.publishedAt).toLocaleDateString() : null;
  const reputation = (article?.source || '').toLowerCase();
  const reputationHint = ['reuters', 'bbc', 'associated press', 'ap', 'new york times'].some((d) => reputation.includes(d)) ? 'reputable' : 'unknown';

  return (
    <li className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4 text-sm text-slate-200">
      <a href={article.url} target="_blank" rel="noopener noreferrer" className="font-semibold text-sky-300 transition hover:text-sky-200">
        {article.title}
      </a>
      <div className="mt-1 text-xs text-slate-400">
        <span>{article.source || 'Unknown source'}</span>
        {published ? <span aria-hidden="true"> | </span> : null}
        {published ? <span>{published}</span> : null}
      </div>
      {article.snippet ? <p className="mt-2 text-xs text-slate-400">{article.snippet}</p> : null}
      <div className="mt-2 text-xs text-slate-400">Source: {reputationHint}</div>
    </li>
  );
}

function EvidenceList({ sources = [] }) {
  if (!sources || sources.length === 0) {
    return <p className="text-sm text-slate-400">No related articles found for this query.</p>;
  }

  return (
    <ul className="flex flex-col gap-3">
      {sources.map((s, i) => (
        <ArticleCard key={`${s.url || i}-${i}`} article={s} />
      ))}
    </ul>
  );
}

export default EvidenceList;
