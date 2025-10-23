# NEWS CHUNK 5 — Integrate NewsAPI Search
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

from typing import AsyncIterator

import pytest
import pytest_asyncio
import respx
from httpx import Response

from app import config
from app.services import news_service


@pytest_asyncio.fixture(autouse=True)
async def _reset_cache() -> AsyncIterator[None]:
    await news_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await news_service._clear_cache_for_tests()  # noqa: SLF001


def _set_common_config(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "NEWS_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "NEWS_CACHE_MAXSIZE", 64)
    monkeypatch.setattr(config, "NEWS_HTTP_TIMEOUT_SECONDS", 5)


@respx.mock
@pytest.mark.asyncio
async def test_newsapi_search_normalises(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_common_config(monkeypatch)
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsapi")
    monkeypatch.setattr(config, "NEWSAPI_KEY", "test-key")
    monkeypatch.setattr(config, "NEWSAPI_ENDPOINT", "https://newsapi.example/v2/everything")

    respx.get("https://newsapi.example/v2/everything").mock(
        return_value=Response(
            200,
            json={
                "articles": [
                    {
                        "title": "Sample Headline",
                        "url": "https://example.com/article",
                        "source": {"name": "Example News"},
                        "publishedAt": "2025-10-20T12:00:00Z",
                        "description": "Snippet text",
                    }
                ]
            },
        )
    )

    articles = await news_service.search_news("Sample query", limit=1)

    assert len(articles) == 1
    article = articles[0]
    assert article["title"] == "Sample Headline"
    assert article["source"] == "Example News"
    assert article["url"] == "https://example.com/article"
    assert article["publishedAt"] == "2025-10-20T12:00:00Z"
    assert article["snippet"] == "Snippet text"


@respx.mock
@pytest.mark.asyncio
async def test_gnews_search_normalises(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_common_config(monkeypatch)
    monkeypatch.setattr(config, "NEWS_PROVIDER", "gnews")
    monkeypatch.setattr(config, "GNEWS_KEY", "gnews-key")
    monkeypatch.setattr(config, "GNEWS_ENDPOINT", "https://gnews.example/api/v4/search")

    respx.get("https://gnews.example/api/v4/search").mock(
        return_value=Response(
            200,
            json={
                "articles": [
                    {
                        "title": "GNews Headline",
                        "url": "https://gnews.example/story",
                        "source": {"name": "GNews Source"},
                        "publishedAt": "2025-10-19T08:15:00Z",
                        "description": "GNews snippet",
                    }
                ]
            },
        )
    )

    articles = await news_service.search_news("Another query", limit=1)

    assert len(articles) == 1
    article = articles[0]
    assert article["source"] == "GNews Source"


@respx.mock
@pytest.mark.asyncio
async def test_newsdata_search_normalises(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_common_config(monkeypatch)
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsdata")
    monkeypatch.setattr(config, "NEWSDATA_KEY", "newsdata-key")
    monkeypatch.setattr(config, "NEWSDATA_ENDPOINT", "https://newsdata.example/api")

    respx.get("https://newsdata.example/api").mock(
        return_value=Response(
            200,
            json={
                "results": [
                    {
                        "title": "NewsData Headline",
                        "link": "https://newsdata.example/story",
                        "source_id": "NewsData Source",
                        "pubDate": "2025-10-18T00:00:00Z",
                        "content": "NewsData snippet",
                    }
                ]
            },
        )
    )

    articles = await news_service.search_news("Third query", limit=1)

    assert len(articles) == 1
    article = articles[0]
    assert article["source"] == "NewsData Source"


@respx.mock
@pytest.mark.asyncio
async def test_search_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_common_config(monkeypatch)
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsapi")
    monkeypatch.setattr(config, "NEWSAPI_KEY", "cache-key")
    monkeypatch.setattr(config, "NEWSAPI_ENDPOINT", "https://newsapi.example/v2/everything")

    route = respx.get("https://newsapi.example/v2/everything").mock(
        return_value=Response(
            200,
            json={
                "articles": [
                    {
                        "title": "Cache Headline",
                        "url": "https://example.com/cache",
                        "source": {"name": "Cache Source"},
                    }
                ]
            },
        )
    )

    first = await news_service.search_news("Cached query", limit=1)
    second = await news_service.search_news("Cached query", limit=1)

    assert first == second
    assert route.call_count == 1


@pytest.mark.asyncio
async def test_missing_credentials_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_common_config(monkeypatch)
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsapi")
    monkeypatch.setattr(config, "NEWSAPI_KEY", None)

    with pytest.raises(news_service.MissingCredentialsError):
        await news_service.search_news("needs credentials", limit=1)