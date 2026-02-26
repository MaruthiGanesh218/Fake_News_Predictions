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
from app.services import factcheck_service


@pytest_asyncio.fixture(autouse=True)
async def _reset_factcheck_cache() -> AsyncIterator[None]:
    await factcheck_service._clear_cache_for_tests()  # noqa: SLF001
    yield
    await factcheck_service._clear_cache_for_tests()  # noqa: SLF001


@respx.mock
@pytest.mark.asyncio
async def test_factcheck_query_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(config, "FACTCHECK_PROVIDER", "google")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_KEY", "unit-key")
    monkeypatch.setattr(config, "GOOGLE_FACTCHECK_ENDPOINT", "https://factcheck.example/claims:search")
    monkeypatch.setattr(config, "FACTCHECK_CACHE_TTL_SECONDS", 600)
    monkeypatch.setattr(config, "FACTCHECK_CACHE_MAXSIZE", 32)

    route = respx.get("https://factcheck.example/claims:search").mock(
        return_value=Response(
            200,
            json={
                "claims": [
                    {
                        "text": "Claim",
                        "claimReview": [
                            {
                                "url": "https://factcheck.example/review",
                                "publisher": {"name": "FactCheck", "site": "factcheck.org"},
                                "reviewDate": "2024-01-01T00:00:00Z",
                                "reviewRating": {"textualRating": "False"},
                                "text": "Summary"
                            }
                        ],
                    }
                ]
            },
        )
    )

    first = await factcheck_service.query_claimreview("Claim to verify", limit=1)
    second = await factcheck_service.query_claimreview("Claim to verify", limit=1)

    assert first == second
    assert route.call_count == 1

    refreshed = await factcheck_service.query_claimreview("Claim to verify", limit=1, force_refresh=True)
    assert refreshed == first
    assert route.call_count == 2
