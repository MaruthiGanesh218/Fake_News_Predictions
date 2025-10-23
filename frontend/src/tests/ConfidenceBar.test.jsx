import { render, screen } from '@testing-library/react';
import ConfidenceBar from '../components/ConfidenceBar.jsx';

describe('ConfidenceBar', () => {
  it('renders progressbar with correct aria value', () => {
    render(<ConfidenceBar confidence={0.72} />);
    const progress = screen.getByRole('progressbar');
    expect(progress).toHaveAttribute('aria-valuenow', '72');
    expect(screen.getByText(/72%/)).toBeInTheDocument();
  });
});
