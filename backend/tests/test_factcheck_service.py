# NEWS CHUNK 6 — Integrate Google Fact Check API
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

from typing import AsyncIterator

import pytest
import pytest_asyncio
import respx
from httpx import Response

from app import config
from app.services import factcheck_service


@pytest_asyncio.fixture(autouse=True)
async def _reset_cache() -> AsyncIterator[None]:
    await factcheck_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await factcheck_service._clear_cache_for_tests()  # noqa: SLF001


@pytest.mark.asyncio
async def test_returns_empty_for_blank_text() -> None:
    results = await factcheck_service.query_claimreview("   ")
    assert results == []


@pytest.mark.asyncio
async def test_returns_empty_when_provider_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "FACTCHECK_PROVIDER", "disabled")
    results = await factcheck_service.query_claimreview("Some claim")
    assert results == []


@pytest.mark.asyncio
async def test_missing_key_short_circuits(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "FACTCHECK_PROVIDER", "google")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_KEY", None)
    monkeypatch.setattr(config, "FACTCHECK_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "FACTCHECK_CACHE_MAXSIZE", 16)

    first = await factcheck_service.query_claimreview("Missing key")
    second = await factcheck_service.query_claimreview("Missing key")

    assert first == []
    assert second == []


@respx.mock
@pytest.mark.asyncio
async def test_query_normalises_reviews(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "FACTCHECK_PROVIDER", "google")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_KEY", "test-key")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_ENDPOINT", "https://factcheck.example/claims:search")
    monkeypatch.setattr(config, "FACTCHECK_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "FACTCHECK_CACHE_MAXSIZE", 16)
    monkeypatch.setattr(config, "FACTCHECK_HTTP_TIMEOUT_SECONDS", 5)

    route = respx.get("https://factcheck.example/claims:search").mock(
        return_value=Response(
            200,
            json={
                "claims": [
                    {
                        "text": "Sample claim text",
                        "claimant": "Researcher",
                        "claimReview": [
                            {
                                "url": "https://fact.example/review",
                                "publisher": {
                                    "name": "FactCheck.org",
                                    "site": "factcheck.org"
                                },
                                "reviewDate": "2024-01-01T12:00:00-04:00",
                                "reviewRating": {
                                    "textualRating": "False",
                                    "alternateName": "Pants on Fire"
                                },
                                "title": "Claim about vaccines is false",
                                "text": "Detailed summary"
                            }
                        ]
                    }
                ]
            },
        )
    )

    results = await factcheck_service.query_claimreview("Vaccines are bad", limit=3)

    assert len(results) == 1
    review = results[0]
    assert review["claim"] == "Sample claim text"
    assert review["claimant"] == "Researcher"
    assert review["author"] == "FactCheck.org"
    assert review["publisher"] == "factcheck.org"
    assert review["url"] == "https://fact.example/review"
    assert review["review_date"] == "2024-01-01T16:00:00Z"
    assert review["truth_rating"] == "False"
    assert review["excerpts"] == "Detailed summary"

    cached = await factcheck_service.query_claimreview("Vaccines are bad", limit=3)
    assert cached == results
    assert route.call_count == 1
