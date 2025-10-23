// NEWS CHUNK 2 — Frontend Base UI Layout
// Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
// Behavior: Full write access. Create files, run checks, save results.

function Header() {
  return (
    <header className="flex flex-col gap-4 text-center lg:text-left">
      <p className="text-sm font-semibold uppercase tracking-[0.3em] text-slate-400">
        Fake News Prediction — Online Phase
      </p>
      <h1 className="text-3xl font-bold tracking-tight text-slate-50 sm:text-4xl lg:text-5xl">
        Fake News Checker — Demo
      </h1>
      <p className="max-w-2xl text-base text-slate-300">
        Paste a headline or short excerpt to preview how the platform will process credibility scores.
        Real scoring will be wired to live signals in a later chunk.
      </p>
    </header>
  );
}

export default Header;
