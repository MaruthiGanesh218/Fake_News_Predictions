# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
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
async def _reset_news_cache() -> AsyncIterator[None]:
    await news_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await news_service._clear_cache_for_tests()  # noqa: SLF001


@respx.mock
@pytest.mark.asyncio
async def test_news_search_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsapi")
    monkeypatch.setattr(config, "NEWSAPI_KEY", "unit-test-key")
    monkeypatch.setattr(config, "NEWSAPI_ENDPOINT", "https://newsapi.example/v2/everything")
    monkeypatch.setattr(config, "NEWS_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "NEWS_CACHE_MAXSIZE", 64)

    route = respx.get("https://newsapi.example/v2/everything").mock(
        return_value=Response(
            200,
            json={
                "articles": [
                    {
                        "title": "Cache Headline",
                        "url": "https://example.com/article",
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

    refreshed = await news_service.search_news("Cached query", limit=1, force_refresh=True)
    assert refreshed == first
    assert route.call_count == 2