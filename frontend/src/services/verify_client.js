/*
 NEWS CHUNK CONNECTIVITY — Browser Helper
 Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
 Behavior: Full write access. Create files, run checks, save results.
*/

const DEFAULT_BASE_URL = 'http://localhost:8000';
const DEFAULT_TEXT = 'Connectivity smoke test ping';

function resolveBaseUrl() {
  const envValue = import.meta.env?.VITE_API_BASE_URL;
  if (typeof envValue === 'string' && envValue.trim()) {
    return envValue.trim().replace(/\/$/, '');
  }
  return DEFAULT_BASE_URL;
}

async function postJson(url, payload, init = {}) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(init.headers ?? {})
    },
    body: JSON.stringify(payload),
    ...init
  });

  const text = await response.text();
  let json;
  try {
    json = text ? JSON.parse(text) : undefined;
  } catch (error) {
    json = { parseError: error.message, raw: text };
  }

  return {
    ok: response.ok,
    status: response.status,
    headers: Object.fromEntries(response.headers.entries()),
    body: json ?? text
  };
}

export async function runConnectivityCheck(sampleText = DEFAULT_TEXT) {
  const baseUrl = resolveBaseUrl();
  const endpoint = `${baseUrl}/check-news`;
  const payload = { text: sampleText };
  const result = await postJson(endpoint, payload, {
    mode: 'cors',
    credentials: 'include'
  });

  const summary = {
    baseUrl,
    endpoint,
    verdict: result.body?.verdict ?? null,
    confidence: result.body?.confidence ?? null,
    ok: result.ok,
    status: result.status,
    headers: result.headers,
    raw: result.body
  };

  if (typeof window !== 'undefined') {
    window.__newsChunkConnectivity = summary;
    window.runConnectivityCheck = runConnectivityCheck;
  }

  console.table({
    verdict: summary.verdict,
    confidence: summary.confidence,
    ok: summary.ok,
    status: summary.status,
    baseUrl: summary.baseUrl
  });

  if (!summary.ok) {
    console.error('Connectivity check failed:', summary);
  }

  return summary;
}

export function bootstrapConnectivityProbe(delayMs = 1000) {
  if (typeof window === 'undefined') {
    return;
  }

  const shouldAutoRun = import.meta.env?.VITE_AUTORUN_CONNECTIVITY === 'true';
  if (!shouldAutoRun) {
    console.info('Connectivity probe idle. Call runConnectivityCheck("your text") from the console.');
    return;
  }

  setTimeout(() => {
    runConnectivityCheck().catch((error) => {
      console.error('Connectivity probe error:', error);
    });
  }, delayMs);
}
