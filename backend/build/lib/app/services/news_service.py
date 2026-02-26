"""NEWS CHUNK 9 - Testing + Caching Layer
Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.

Async news search service with provider specific adapters and shared caching utilities.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional

import httpx

from app import config
from app.utils import cache

logger = logging.getLogger(__name__)


class NewsServiceError(Exception):
    """Base exception for the news service."""


class MissingCredentialsError(NewsServiceError):
    """Raised when credentials required for the provider are missing."""


class _ProviderSettings:
    __slots__ = ("name", "api_key")

    def __init__(self, name: str, api_key: Optional[str]):
        self.name = name
        self.api_key = api_key

_NEWS_CACHE = cache.create_cache(
    "news.search",
    ttl=config.NEWS_CACHE_TTL_SECONDS,
    max_items=config.NEWS_CACHE_MAXSIZE,
)


def _make_cache_key(query: str, limit: int = 3, *, force_refresh: bool = False) -> str:
    normalised = " ".join(query.lower().split())
    per_page = max(1, limit or config.NEWS_DEFAULT_LIMIT)
    provider = config.NEWS_PROVIDER
    _ = force_refresh  # Consumed by caching decorator; ignored for key creation.
    return cache.make_key("news", provider, str(per_page), normalised)


def _provider_settings(provider: str) -> _ProviderSettings:
    if provider == "newsapi":
        return _ProviderSettings(name="newsapi", api_key=config.NEWSAPI_KEY)
    if provider == "gnews":
        return _ProviderSettings(name="gnews", api_key=config.GNEWS_KEY)
    if provider == "newsdata":
        return _ProviderSettings(name="newsdata", api_key=config.NEWSDATA_KEY)
    return _ProviderSettings(name=provider, api_key=None)


@cache.cached(
    ttl=config.NEWS_CACHE_TTL_SECONDS,
    key_func=_make_cache_key,
    cache=_NEWS_CACHE,
    namespace="news.search",
)
async def search_news(query: str, limit: int = 3, *, force_refresh: bool = False) -> List[Dict[str, Any]]:
    """Search for relevant articles using the configured provider.

    Missing credentials raise ``MissingCredentialsError``. Network errors or upstream
    failures are logged and result in an empty list.
    """

    trimmed = query.strip()
    if not trimmed:
        return []

    provider = config.NEWS_PROVIDER
    settings = _provider_settings(provider)
    per_page = max(1, limit or config.NEWS_DEFAULT_LIMIT)
    _ = force_refresh  # The caching decorator handles invalidation via this flag.

    if not settings.api_key:
        raise MissingCredentialsError(f"Missing API credentials for provider '{settings.name}'.")

    adapter = _PROVIDER_ADAPTERS.get(settings.name)
    if adapter is None:
        logger.warning("Unsupported news provider '%s'.", settings.name)
        return []

    articles: List[Dict[str, Any]] = []
    try:
        raw_articles = await adapter(trimmed, per_page, settings.api_key)
        articles = _filter_articles(raw_articles)
    except MissingCredentialsError:
        raise
    except httpx.HTTPError as exc:
        logger.warning("HTTP error during news search: %s", exc)
        articles = []
    except Exception as exc:  # pragma: no cover - safety net
        logger.exception("Unexpected error during news search", exc_info=exc)
        articles = []
    return articles


async def _search_news_newsapi(query: str, limit: int, api_key: str) -> List[Dict[str, Any]]:
    params = {
        "q": query,
        "language": "en",
        "pageSize": limit,
        "sortBy": "relevancy",
    }
    headers = {"X-Api-Key": api_key}
    async with httpx.AsyncClient(timeout=config.NEWS_HTTP_TIMEOUT_SECONDS) as client:
        response = await client.get(config.NEWSAPI_ENDPOINT, params=params, headers=headers)
        response.raise_for_status()
    data = response.json()
    articles = data.get("articles", [])
    return [_normalise_article(
        title=item.get("title"),
        source=(item.get("source") or {}).get("name"),
        url=item.get("url"),
        published_at=item.get("publishedAt"),
        snippet=item.get("description") or item.get("content"),
    ) for item in articles][:limit]


async def _search_news_gnews(query: str, limit: int, api_key: str) -> List[Dict[str, Any]]:
    params = {
        "q": query,
        "lang": "en",
        "max": limit,
        "token": api_key,
    }
    async with httpx.AsyncClient(timeout=config.NEWS_HTTP_TIMEOUT_SECONDS) as client:
        response = await client.get(config.GNEWS_ENDPOINT, params=params)
        response.raise_for_status()
    data = response.json()
    articles = data.get("articles", [])
    return [_normalise_article(
        title=item.get("title"),
        source=((item.get("source") or {}).get("name") or item.get("source")),
        url=item.get("url"),
        published_at=item.get("publishedAt"),
        snippet=item.get("description"),
    ) for item in articles][:limit]


async def _search_news_newsdata(query: str, limit: int, api_key: str) -> List[Dict[str, Any]]:
    params = {
        "q": query,
        "language": "en",
        "apikey": api_key,
    }
    async with httpx.AsyncClient(timeout=config.NEWS_HTTP_TIMEOUT_SECONDS) as client:
        response = await client.get(config.NEWSDATA_ENDPOINT, params=params)
        response.raise_for_status()
    data = response.json()
    articles = data.get("results", [])
    return [_normalise_article(
        title=item.get("title"),
        source=item.get("source_id") or item.get("creator"),
        url=item.get("link"),
        published_at=item.get("pubDate"),
        snippet=item.get("description") or item.get("content"),
    ) for item in articles][:limit]


def _normalise_article(
    *,
    title: Optional[str],
    source: Optional[str],
    url: Optional[str],
    published_at: Optional[str],
    snippet: Optional[str],
) -> Dict[str, Any]:
    if not title or not url:
        return {}
    return {
        "title": title.strip(),
        "source": (source or "Unknown").strip(),
        "url": url.strip(),
        "publishedAt": _normalise_datetime(published_at),
        "snippet": (snippet or "").strip() or None,
    }


def _normalise_datetime(value: Optional[str]) -> Optional[str]:
    if not value:
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


_PROVIDER_ADAPTERS: Dict[str, Any] = {
    "newsapi": _search_news_newsapi,
    "gnews": _search_news_gnews,
    "newsdata": _search_news_newsdata,
}


def _filter_articles(articles: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    filtered: List[Dict[str, Any]] = []
    for article in articles:
        if not article:
            continue
        filtered.append(article)
    return filtered


async def _clear_cache_for_tests() -> None:
    await _NEWS_CACHE.clear()


__all__ = [
    "search_news",
    "NewsServiceError",
    "MissingCredentialsError",
    "_clear_cache_for_tests",
]
