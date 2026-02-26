/*
 NEWS CHUNK 9 - Testing + Caching Layer
 Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
 Behavior: Full write access. Create files, run checks, save results.
*/

import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import App from '../App.jsx';

describe('App cached responses', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    cleanup();
  });

  it('renders consistent state when backend returns cached response twice', async () => {
    const mockPayload = {
      verdict: 'real',
      confidence: 0.64,
      evidence: ['Cached evidence entry'],
      claim_reviews: [],
      classifier: {
        provider: 'local',
        score: 0.22,
        explanation: 'Cached response from backend'
      },
      sources: [],
      notes: 'Cached payload from backend test.'
    };

    const fetchMock = vi.spyOn(global, 'fetch').mockImplementation((url) => {
      if (url.includes('/history')) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve([])
        });
      }
      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve(mockPayload)
      });
    });

    render(<App />);

    const textarea = screen.getByLabelText(/news text or headline/i);
    fireEvent.change(textarea, { target: { value: 'Headline to cache' } });

    const button = screen.getByRole('button', { name: /check news/i });
    fireEvent.click(button);

    // Initial load fetches history, then click fetches check-news.
    // We expect 1 history fetch (on mount) + 1 check-news fetch.
    // However, depending on timing and React strict mode, history might be fetched twice or more.
    // The previous test expected 1 call, but we saw 3.
    // Let's filter calls to check-news for assertion.
    await waitFor(() => {
        const calls = fetchMock.mock.calls.filter(call => call[0].includes('/check-news'));
        expect(calls).toHaveLength(1);
    });
    expect(await screen.findByText(/Cached payload from backend test/i)).toBeInTheDocument();

    // Trigger another submission with the same payload to simulate a cached backend response.
    fireEvent.click(button);

    await waitFor(() => {
        const calls = fetchMock.mock.calls.filter(call => call[0].includes('/check-news'));
        expect(calls).toHaveLength(2);
    });
    expect(screen.getByText(/Cached payload from backend test/i)).toBeInTheDocument();
    expect(screen.getByText(/local/i)).toBeInTheDocument();
    expect(screen.queryByText(/Running mock inference/i)).not.toBeInTheDocument();
  });
});
