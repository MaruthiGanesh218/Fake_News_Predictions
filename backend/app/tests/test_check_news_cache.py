# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

from typing import AsyncIterator

import pytest
import pytest_asyncio
import respx
from fastapi.testclient import TestClient
from httpx import Response

from app import config
from app.main import app
from app.utils import cache


@pytest_asyncio.fixture(autouse=True)
async def _clear_all_caches() -> AsyncIterator[None]:
    await cache.clear_registered_caches()
    yield
    await cache.clear_registered_caches()


@respx.mock
def test_check_news_endpoint_uses_cached_services(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "NEWS_PROVIDER", "newsapi")
    monkeypatch.setattr(config, "NEWSAPI_KEY", "news-key")
    monkeypatch.setattr(config, "NEWSAPI_ENDPOINT", "https://newsapi.example/v2/everything")
    monkeypatch.setattr(config, "FACTCHECK_PROVIDER", "google")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_KEY", "fact-key")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_ENDPOINT", "https://factcheck.example/claims:search")
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "rapidapi")
    monkeypatch.setattr(config, "RAPIDAPI_KEY", "rapid-key")
    monkeypatch.setattr(config, "RAPIDAPI_HOST", "fake-news-detector.p.rapidapi.com")
    monkeypatch.setattr(config, "RAPIDAPI_CLASSIFIER_ENDPOINT", "https://rapidapi.example/predict")

    news_route = respx.get("https://newsapi.example/v2/everything").mock(
        return_value=Response(
            200,
            json={
                "articles": [
                    {
                        "title": "Cached headline",
                        "url": "https://example.com/article",
                        "source": {"name": "Example News"},
                    }
                ]
            },
        )
    )

    factcheck_route = respx.get("https://factcheck.example/claims:search").mock(
        return_value=Response(
            200,
            json={
                "claims": []
            },
        )
    )

    classifier_route = respx.post("https://rapidapi.example/predict").mock(
        return_value=Response(
            200,
            json={
                "score": 0.76,
                "explanation": "Cached classifier payload",
            },
        )
    )

    client = TestClient(app)

    payload = {"text": "Cached response headline"}

    first = client.post("/check-news", json=payload)
    assert first.status_code == 200

    second = client.post("/check-news", json=payload)
    assert second.status_code == 200

    assert news_route.call_count == 1
    assert factcheck_route.call_count == 1
    assert classifier_route.call_count == 1

    refreshed = client.post("/check-news?refresh=true", json=payload)
    assert refreshed.status_code == 200

    assert news_route.call_count == 2
    assert factcheck_route.call_count == 2
    assert classifier_route.call_count == 2
