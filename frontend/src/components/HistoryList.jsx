import { useEffect, useState } from 'react';
import { fetchHistory } from '../services/api';

function HistoryList({ onSelect, refreshTrigger }) {
  const [history, setHistory] = useState([]);

  useEffect(() => {
    let mounted = true;
    fetchHistory().then(data => {
      if (mounted && Array.isArray(data)) {
        setHistory(data);
      }
    });
    return () => { mounted = false; };
  }, [refreshTrigger]);

  if (history.length === 0) {
    return null;
  }

  return (
    <section className="flex flex-col gap-4 rounded-3xl border border-slate-800 bg-slate-900/50 p-6 shadow-xl shadow-slate-950/40">
      <h3 className="text-sm font-semibold uppercase tracking-wider text-slate-400">
        Recent Searches
      </h3>
      <div className="flex flex-wrap gap-2">
        {history.map((item, index) => (
          <button
            key={`${index}-${item.substring(0, 10)}`}
            onClick={() => onSelect(item)}
            className="max-w-full truncate rounded-full border border-slate-700 bg-slate-950/50 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-sky-400 hover:bg-slate-900 hover:text-sky-200"
            title={item}
          >
            {item.length > 50 ? `${item.substring(0, 50)}...` : item}
          </button>
        ))}
      </div>
    </section>
  );
}

export default HistoryList;
