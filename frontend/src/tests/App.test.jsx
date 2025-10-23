import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import App from '../App.jsx';

vi.mock('../services/api.js', () => ({
  checkNews: vi.fn()
}));

const { checkNews } = await import('../services/api.js');

const MOCK_RESPONSE = {
  verdict: 'unsure',
  confidence: 0.5,
  evidence: ['Sample evidence'],
  claim_reviews: [
    {
      claim: 'Claim text',
      claimant: 'Researcher',
      author: 'FactCheck.org',
      publisher: 'factcheck.org',
      url: 'https://example.com/factcheck',
      review_date: '2025-10-20T12:00:00Z',
      truth_rating: 'False',
      excerpts: 'Claim debunked summary'
    }
  ],
  classifier: {
    provider: 'local',
    score: 0.78,
    explanation: 'Detected persuasive language cues.'
  },
  sources: [
    {
      title: 'Sample article',
      source: 'Example News',
      url: 'https://example.com/article',
      publishedAt: '2025-10-20T12:00:00Z',
      snippet: 'Sample snippet'
    }
  ],
  notes: 'Mock response from News Chunk 7 test.'
};

describe('App integration', () => {
  afterEach(() => {
    vi.clearAllMocks();
    cleanup();
  });

  it('submits text and renders verdict on success', async () => {
    checkNews.mockResolvedValueOnce(MOCK_RESPONSE);

    render(<App />);

    const textarea = screen.getByLabelText(/news text or headline/i);
    fireEvent.change(textarea, { target: { value: 'Breaking news' } });

    const button = screen.getByRole('button', { name: /check news/i });
    fireEvent.click(button);

    await waitFor(() => expect(checkNews).toHaveBeenCalledWith('Breaking news'));
    expect(await screen.findByText(/Mock response from News Chunk 7 test/i)).toBeInTheDocument();

    // The verdict badge is announced via role=status to screen readers
    const verdictBadge = screen.getByRole('status');
    expect(verdictBadge).toHaveTextContent(/unsure/i);

    expect(screen.getByText(/local/i)).toBeInTheDocument();
    expect(screen.getByText(/78% fake likelihood/i)).toBeInTheDocument();

    // The fact-check card exposes the rating and a link to the full fact-check
    expect(screen.getByRole('heading', { name: /false/i })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /read full fact-check/i })).toHaveAttribute('href', 'https://example.com/factcheck');
    expect(screen.getByRole('link', { name: /sample article/i })).toBeInTheDocument();
  });

  it('shows loading indicator while waiting for response', async () => {
    checkNews.mockImplementation(() => new Promise((resolve) => setTimeout(() => resolve(MOCK_RESPONSE), 100)));

    render(<App />);

    const textarea = screen.getByLabelText(/news text or headline/i);
    fireEvent.change(textarea, { target: { value: 'Delayed news' } });

    const button = screen.getByRole('button', { name: /check news/i });
    fireEvent.click(button);

    expect(button).toBeDisabled();
    expect(await screen.findByText(/Running mock inference/i)).toBeInTheDocument();

    await waitFor(() => expect(button).not.toBeDisabled());
  });

  it('renders error message when API call fails', async () => {
    checkNews.mockRejectedValueOnce(new Error('Network error: 500'));

    render(<App />);

    const textarea = screen.getByLabelText(/news text or headline/i);
    fireEvent.change(textarea, { target: { value: 'Failing input' } });

    const button = screen.getByRole('button', { name: /check news/i });
    fireEvent.click(button);

    const alerts = await screen.findAllByRole('alert');
    expect(alerts.length).toBeGreaterThan(0);
    alerts.forEach((alert) => {
      expect(alert).toHaveTextContent(/Network error: 500/i);
    });
  });
});
