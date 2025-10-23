/*
 NEWS CHUNK 2 — Frontend Base UI Layout
 Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
 Behavior: Full write access. Create files, run checks, save results.
*/

module.exports = {
  content: ['index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter"', '"Segoe UI"', 'system-ui', 'sans-serif']
      },
      animation: {
        pulse: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }
    }
  },
  plugins: []
};
