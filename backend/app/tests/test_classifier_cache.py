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
from app.services import classifier_service


@pytest_asyncio.fixture(autouse=True)
async def _reset_classifier_cache() -> AsyncIterator[None]:
    await classifier_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await classifier_service._clear_cache_for_tests()  # noqa: SLF001


@respx.mock
@pytest.mark.asyncio
async def test_classifier_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "rapidapi")
    monkeypatch.setattr(config, "CLASSIFIER_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "CLASSIFIER_CACHE_MAXSIZE", 64)
    monkeypatch.setattr(config, "RAPIDAPI_KEY", "rapid-key")
    monkeypatch.setattr(config, "RAPIDAPI_HOST", "fake-news-detector.p.rapidapi.com")
    monkeypatch.setattr(config, "RAPIDAPI_CLASSIFIER_ENDPOINT", "https://rapidapi.example/predict")

    route = respx.post("https://rapidapi.example/predict").mock(
        return_value=Response(
            200,
            json={
                "score": 0.77,
                "explanation": "Detected persuasive language",
            },
        )
    )

    first = await classifier_service.classify_text("Breaking secret exposed")
    second = await classifier_service.classify_text("Breaking secret exposed")

    assert first == second
    assert route.call_count == 1

    refreshed = await classifier_service.classify_text("Breaking secret exposed", force_refresh=True)
    assert refreshed == first
    assert route.call_count == 2
