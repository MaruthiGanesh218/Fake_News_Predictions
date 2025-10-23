# NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
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
async def _reset_cache() -> AsyncIterator[None]:
    await classifier_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await classifier_service._clear_cache_for_tests()  # noqa: SLF001


@pytest.mark.asyncio
async def test_local_classifier_baseline(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "local")

    result = await classifier_service.classify_text("Shocking headline lacks evidence")

    assert result["provider"] == "local"
    assert 0.0 <= result["score"] <= 1.0
    assert "Heuristic" not in result.get("explanation", "") or result["score"] == pytest.approx(0.5, abs=1e-6)


@pytest.mark.asyncio
async def test_missing_credentials_falls_back(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "rapidapi")
    monkeypatch.setattr(config, "RAPIDAPI_KEY", None)
    monkeypatch.setattr(config, "RAPIDAPI_HOST", None)

    result = await classifier_service.classify_text("Breaking secret exposed by officials")

    assert result["provider"] == "local"
    assert result["score"] <= 1.0
    assert "RapidAPI credentials missing" in (result.get("explanation") or "")


@respx.mock
@pytest.mark.asyncio
async def test_rapidapi_invocation_and_caching(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "rapidapi")
    monkeypatch.setattr(config, "CLASSIFIER_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "CLASSIFIER_CACHE_MAXSIZE", 32)
    monkeypatch.setattr(config, "RAPIDAPI_KEY", "test-key")
    monkeypatch.setattr(config, "RAPIDAPI_HOST", "fake-news-detector.p.rapidapi.com")
    monkeypatch.setattr(config, "RAPIDAPI_CLASSIFIER_ENDPOINT", "https://example-rapidapi.com/predict")

    route = respx.post("https://example-rapidapi.com/predict").mock(
        return_value=Response(
            200,
            json={
                "score": 0.82,
                "explanation": "Detected persuasive language",
            },
        )
    )

    first = await classifier_service.classify_text("Exposed cover-up shocks nation")
    second = await classifier_service.classify_text("Exposed cover-up shocks nation")

    assert route.call_count == 1
    assert first["provider"] == "rapidapi"
    assert second["provider"] == "rapidapi"
    assert second["score"] == pytest.approx(first["score"])
    assert first["explanation"] == "Detected persuasive language"


@pytest.mark.asyncio
async def test_local_classifier_explanation_contains_counts(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "CLASSIFIER_PROVIDER", "local")

    result = await classifier_service.classify_text("Research investigation contradicts shocking secret")

    assert result["provider"] == "local"
    assert "sensational" in (result.get("explanation") or "").lower()
    assert "reputable" in (result.get("explanation") or "").lower()