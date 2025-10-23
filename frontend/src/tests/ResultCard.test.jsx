import { render, screen } from '@testing-library/react';
import ResultCard from '../components/ResultCard.jsx';

const MOCK_RESULT = {
  verdict: 'fake',
  confidence: 0.85,
  evidence: ['Some evidence'],
  sources: [
    {
      title: 'Test article',
      source: 'Example News',
      url: 'https://example.com/article',
      publishedAt: '2025-10-21T12:00:00Z',
      snippet: 'Snippet'
    }
  ],
  claim_reviews: [
    {
      claim: 'Test claim',
      claimant: 'Researcher',
      author: 'FactCheck.org',
      publisher: 'factcheck.org',
      url: 'https://example.com/factcheck',
      review_date: '2025-10-20T12:00:00Z',
      truth_rating: 'False',
      excerpts: 'Debunked'
    }
  ],
  classifier: {
    provider: 'local',
    score: 0.92,
    explanation: 'High sensational words'
  },
  notes: 'Test notes'
};

describe('ResultCard', () => {
  it('renders claim review first and classifier and sources', () => {
    render(<ResultCard result={MOCK_RESULT} isLoading={false} error={null} />);

    expect(screen.getByText(/False/i)).toBeInTheDocument();
    expect(screen.getByText(/Test article/i)).toBeInTheDocument();
    expect(screen.getByText(/local/i)).toBeInTheDocument();
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('shows loading skeleton when isLoading is true', () => {
    render(<ResultCard result={null} isLoading={true} error={null} />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });
});
