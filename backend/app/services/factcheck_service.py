"""NEWS CHUNK 9 - Testing + Caching Layer
Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.

Async ClaimReview lookup service backed by the Google Fact Check Tools API with
shared caching utilities.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx

from app import config
from app.utils import cache

logger = logging.getLogger(__name__)

_FACTCHECK_CACHE = cache.create_cache(
    "factcheck.query",
    ttl=config.FACTCHECK_CACHE_TTL_SECONDS,
    max_items=config.FACTCHECK_CACHE_MAXSIZE,
)


def _make_cache_key(query: str, limit: int = 5, *, force_refresh: bool = False) -> str:
    normalised = " ".join(query.lower().split())
    per_page = max(1, min(20, limit or config.FACTCHECK_DEFAULT_LIMIT))
    provider = config.FACTCHECK_PROVIDER or "none"
    _ = force_refresh
    return cache.make_key("factcheck", provider, str(per_page), normalised)


@cache.cached(
    ttl=config.FACTCHECK_CACHE_TTL_SECONDS,
    key_func=_make_cache_key,
    cache=_FACTCHECK_CACHE,
    namespace="factcheck.query",
)
async def query_claimreview(query: str, limit: int = 5, *, force_refresh: bool = False) -> List[Dict[str, Any]]:
    """Query ClaimReview entries for the supplied text.

    The Google Fact Check API is queried when configured. If the provider is disabled
    or credentials are missing, the function returns an empty list gracefully.
    """

    trimmed = query.strip()
    if not trimmed:
        return []

    provider = config.FACTCHECK_PROVIDER
    if provider != "google":
        return []

    per_page = max(1, min(20, limit or config.FACTCHECK_DEFAULT_LIMIT))
    _ = force_refresh

    api_key = config.GOOGLE_FACTCHECK_KEY
    if not api_key:
        logger.warning("FactCheck provider configured but GOOGLE_FACTCHECK_KEY missing.")
        return []

    params = {
        "query": trimmed,
        "pageSize": per_page,
        "languageCode": "en",
        "key": api_key,
    }

    try:
        async with httpx.AsyncClient(timeout=config.FACTCHECK_HTTP_TIMEOUT_SECONDS) as client:
            response = await client.get(config.GOOGLE_FACTCHECK_ENDPOINT, params=params)
            if response.status_code == httpx.codes.TOO_MANY_REQUESTS:
                logger.warning("FactCheck API rate limit encountered; returning cached empty response.")
                return []
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPStatusError as exc:
        logger.warning("FactCheck API HTTP error: %s", exc)
        return []
    except httpx.HTTPError as exc:
        logger.warning("FactCheck API network error: %s", exc)
        return []

    claims = data.get("claims") or []
    results = _normalise_claims(claims, per_page)
    return results


def _normalise_claims(claims: List[Dict[str, Any]], limit: int) -> List[Dict[str, Any]]:
    normalised: List[Dict[str, Any]] = []
    for claim in claims:
        claim_text = (claim.get("text") or "").strip()
        claimant = (claim.get("claimant") or "").strip() or None
        reviews = claim.get("claimReview") or []
        for review in reviews:
            article = _normalise_review(claim_text, claimant, review)
            if article:
                normalised.append(article)
            if len(normalised) >= limit:
                return normalised
    return normalised


def _normalise_review(claim_text: str, claimant: Optional[str], review: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    url = (review.get("url") or "").strip()
    if not url:
        return None

    publisher = review.get("publisher") or {}
    publisher_name = (publisher.get("name") or "").strip() or None
    publisher_site = (publisher.get("site") or "").strip() or None
    review_rating = review.get("reviewRating") or {}

    truth_rating = _extract_truth_rating(review_rating, review)
    review_date = _normalise_datetime(review.get("reviewDate"))
    excerpt = _extract_excerpt(review)

    return {
        "claim": claim_text or None,
        "claimant": claimant,
        "author": publisher_name,
        "publisher": publisher_site or publisher_name,
        "url": url,
        "review_date": review_date,
        "truth_rating": truth_rating,
        "excerpts": excerpt,
    }


def _extract_truth_rating(review_rating: Dict[str, Any], review: Dict[str, Any]) -> Optional[str]:
    candidates = [
        review_rating.get("textualRating"),
        review_rating.get("alternateName"),
        review_rating.get("ratingValue"),
        review.get("title"),
    ]
    for candidate in candidates:
        if isinstance(candidate, str) and candidate.strip():
            return candidate.strip()
    return None


def _extract_excerpt(review: Dict[str, Any]) -> Optional[str]:
    for key in ("text", "summaryText", "title"):
        value = review.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _normalise_datetime(value: Any) -> Optional[str]:
    if not value or not isinstance(value, str):
        return None
    raw = value.strip()
    if not raw:
        return None
    cleaned = raw.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(cleaned)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    else:
        parsed = parsed.astimezone(timezone.utc)
    return parsed.isoformat().replace("+00:00", "Z")


async def _clear_cache_for_tests() -> None:
    await _FACTCHECK_CACHE.clear()


__all__ = [
    "query_claimreview",
    "_clear_cache_for_tests",
]
