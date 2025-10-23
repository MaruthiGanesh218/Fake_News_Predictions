// NEWS CHUNK 4 — Frontend–Backend Integration
// Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
// Behavior: Full write access. Create files, run checks, save results.

import { useState } from 'react';
import Header from './components/Header.jsx';
import InputCard from './components/InputCard.jsx';
import ResultCard from './components/ResultCard.jsx';
import { checkNews } from './services/api.js';

function App() {
  const [text, setText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const handleSubmit = async (payload) => {
    const trimmed = payload.trim();
    if (!trimmed) {
      setResult(null);
      setError(null);
      return;
    }

    setIsLoading(true);
    setResult(null);
    setError(null);

    try {
      const response = await checkNews(trimmed);
      setResult(response);
    } catch (submissionError) {
      setError(submissionError instanceof Error ? submissionError.message : 'Unknown error occurred.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <div className="mx-auto flex min-h-screen max-w-6xl flex-col gap-12 px-6 pb-16 pt-12 lg:px-8">
        <Header />
        <main className="grid grid-cols-1 gap-10 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
          <InputCard
            value={text}
            onChange={setText}
            onSubmit={handleSubmit}
            isLoading={isLoading}
            error={error}
          />
          <ResultCard result={result} isLoading={isLoading} error={error} />
        </main>
      </div>
    </div>
  );
}

export default App;
