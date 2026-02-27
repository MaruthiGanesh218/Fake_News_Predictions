/**
 * Validates if a URL is safe to be used in an anchor tag's href attribute.
 * Only http and https protocols are allowed to prevent XSS (e.g., via javascript:).
 * @param {string} url - The URL to validate.
 * @returns {boolean} - True if the URL is safe, false otherwise.
 */
export function isSafeUrl(url) {
  if (typeof url !== 'string') return false;
  const lowerUrl = url.trim().toLowerCase();
  return lowerUrl.startsWith('http://') || lowerUrl.startsWith('https://');
}
