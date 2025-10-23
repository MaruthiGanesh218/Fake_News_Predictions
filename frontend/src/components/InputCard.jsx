// NEWS CHUNK 4 — Frontend–Backend Integration
// Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
// Behavior: Full write access. Create files, run checks, save results.

const EXAMPLE_SNIPPETS = [
  'Scientists discover water on Mars for the second time this year.',
  'Government announces new policy to combat misinformation online.',
  'Celebrity endorses miracle cure with no scientific backing.'
];

function InputCard({ value, onChange, onSubmit, isLoading, error }) {
  const handleSubmit = (event) => {
    event.preventDefault();
    onSubmit(value);
  };

  const handleExample = (snippet) => {
    onChange(snippet);
  };

  return (
    <section className="rounded-3xl border border-slate-800 bg-slate-900/50 p-6 shadow-xl shadow-slate-950/40">
      <form
        className="flex flex-col gap-4"
        onSubmit={handleSubmit}
        data-testid="input-card-form"
        aria-busy={isLoading}
      >
        <div className="flex flex-col gap-2">
          <label className="text-sm font-semibold uppercase tracking-wider text-slate-400" htmlFor="news-input">
            News text or headline
          </label>
          <textarea
            id="news-input"
            name="news-input"
            placeholder="Paste news content to analyze..."
            value={value}
            onChange={(event) => onChange(event.target.value)}
            rows={10}
            className="w-full resize-y rounded-2xl border border-slate-700 bg-slate-950/80 p-4 text-base text-slate-100 placeholder:text-slate-500 focus:border-sky-400 focus:outline-none focus:ring-2 focus:ring-sky-500/60"
            aria-describedby="input-hint"
          />
          <p id="input-hint" className="text-xs text-slate-400">
            The backend mock will return a static response for now. Future chunks will call FastAPI directly.
          </p>
        </div>

        <div className="flex flex-wrap gap-2" aria-label="Example snippets">
          {EXAMPLE_SNIPPETS.map((snippet) => (
            <button
              key={snippet}
              type="button"
              className="rounded-full border border-slate-700 px-3 py-1 text-xs font-medium text-slate-300 transition hover:border-sky-400 hover:text-sky-200"
              onClick={() => handleExample(snippet)}
              aria-label={`Use sample: ${snippet}`}
              title={snippet}
            >
              Use sample
            </button>
          ))}
        </div>

        <div className="flex flex-col gap-3">
          {error ? (
            <div
              role="alert"
              className="rounded-2xl border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200"
            >
              {error}
            </div>
          ) : (
            <span className="text-xs text-slate-500">
              Tip: Keep input under 1,000 characters for faster processing.
            </span>
          )}
          <div className="flex items-center justify-end">
            <button
              id="check-btn"
              type="submit"
              disabled={isLoading || !value.trim()}
              className="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-sky-400 via-indigo-500 to-purple-500 px-5 py-2 text-sm font-semibold text-slate-950 transition hover:from-sky-300 hover:to-purple-400 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isLoading ? 'Checking…' : 'Check News'}
            </button>
          </div>
        </div>
      </form>
    </section>
  );
}

export default InputCard;
