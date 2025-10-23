/*
 NEWS CHUNK 4 — Frontend–Backend Integration
 Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
 Behavior: Full write access. Create files, run checks, save results.
*/

import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import InputCard from '../components/InputCard.jsx';

describe('InputCard', () => {
  it('calls onSubmit with trimmed text', () => {
    const handleSubmit = vi.fn();
    const handleChange = vi.fn();

    render(
      <InputCard
        value="  sample headline  "
        onChange={handleChange}
        onSubmit={handleSubmit}
        isLoading={false}
        error={null}
      />
    );

  fireEvent.submit(screen.getByTestId('input-card-form'));

    expect(handleSubmit).toHaveBeenCalledTimes(1);
  expect(handleSubmit).toHaveBeenCalledWith('  sample headline  ');
  });

  it('disables the button when loading', () => {
    render(
      <InputCard
        value="sample"
        onChange={() => {}}
        onSubmit={() => {}}
        isLoading
        error={null}
      />
    );

    expect(screen.getByRole('button', { name: /checking/i })).toBeDisabled();
  });

  it('renders error banner when provided', () => {
    render(
      <InputCard
        value="sample"
        onChange={() => {}}
        onSubmit={() => {}}
        isLoading={false}
        error="Something went wrong"
      />
    );

    expect(screen.getByRole('alert')).toHaveTextContent(/something went wrong/i);
  });
});
