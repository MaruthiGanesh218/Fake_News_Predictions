import { render, screen } from '@testing-library/react';
import VerdictBadge from '../components/VerdictBadge.jsx';

describe('VerdictBadge', () => {
  it('renders real verdict with aria attributes', () => {
    render(<VerdictBadge verdict="real" />);
    expect(screen.getByRole('status')).toHaveAttribute('aria-label', 'Verdict: real');
    expect(screen.getByText(/real/i)).toBeInTheDocument();
  });

  it('renders fake verdict', () => {
    render(<VerdictBadge verdict="fake" />);
    expect(screen.getByText(/fake/i)).toBeInTheDocument();
  });
});
