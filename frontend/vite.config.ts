// NEWS CHUNK 4 — Frontend–Backend Integration
// Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
// Behavior: Full write access. Create files, run checks, save results.

import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/tests/setup.js'
  }
});
