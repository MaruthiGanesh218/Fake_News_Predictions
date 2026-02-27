import { render, screen } from '@testing-library/react';
import ClaimReviewCard from '../components/ClaimReviewCard.jsx';
import { describe, it, expect } from 'vitest';

describe('ClaimReviewCard', () => {
  it('renders a valid http URL', () => {
    const claimReview = {
      url: 'http://example.com',
      truth_rating: 'True'
    };
    render(<ClaimReviewCard claimReview={claimReview} />);
    const link = screen.getByRole('link', { name: /Read full fact-check/i });
    expect(link.getAttribute('href')).toBe('http://example.com');
  });

  it('renders a valid https URL', () => {
    const claimReview = {
      url: 'https://example.com',
      truth_rating: 'True'
    };
    render(<ClaimReviewCard claimReview={claimReview} />);
    const link = screen.getByRole('link', { name: /Read full fact-check/i });
    expect(link.getAttribute('href')).toBe('https://example.com');
  });

  it('does not render a javascript: URL', () => {
    const claimReview = {
      url: 'javascript:alert(1)',
      truth_rating: 'True'
    };
    render(<ClaimReviewCard claimReview={claimReview} />);
    const link = screen.queryByRole('link', { name: /Read full fact-check/i });
    expect(link).toBeNull();
  });

  it('does not render an invalid URL', () => {
    const claimReview = {
      url: 'ftp://example.com',
      truth_rating: 'True'
    };
    render(<ClaimReviewCard claimReview={claimReview} />);
    const link = screen.queryByRole('link', { name: /Read full fact-check/i });
    expect(link).toBeNull();
  });
});
