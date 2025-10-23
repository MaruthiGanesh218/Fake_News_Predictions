/*
 NEWS CHUNK 4 — Frontend–Backend Integration
 Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
 Behavior: Full write access. Create files, run checks, save results.
*/

const DEFAULT_BASE_URL = 'http://localhost:8000';
const REQUEST_TIMEOUT_MS = 10_000;

function resolveBaseUrl() {
  const candidate = import.meta.env.VITE_API_BASE_URL;
  if (typeof candidate === 'string' && candidate.trim().length > 0) {
    return candidate.trim().replace(/\/$/, '');
  }
  return DEFAULT_BASE_URL;
}

export async function checkNews(text) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const baseUrl = resolveBaseUrl();
    const response = await fetch(`${baseUrl}/check-news`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ text }),
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`Network error: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('Request timed out. Please try again.');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
