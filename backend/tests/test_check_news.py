# NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routes import check_news as check_news_route

MOCK_REQUEST = {"text": "Sample headline about space exploration."}
EXPECTED_KEYS = {"verdict", "confidence", "evidence", "sources", "claim_reviews", "classifier", "notes"}


def test_check_news_returns_mock_payload() -> None:
    """POST /check-news should emit every expected field from the mock."""
    client = TestClient(app)
    response = client.post("/check-news", json=MOCK_REQUEST)

    assert response.status_code == 200
    payload = response.json()
    assert EXPECTED_KEYS.issubset(payload.keys())
    assert payload["verdict"] == "unsure"
    assert payload["confidence"] == pytest.approx(0.6)
    assert isinstance(payload["evidence"], list)
    assert isinstance(payload["sources"], list)
    assert isinstance(payload["claim_reviews"], list)
    assert isinstance(payload["classifier"], dict)
    assert "provider" in payload["classifier"]
    assert "score" in payload["classifier"]
    if payload["sources"]:
        article = payload["sources"][0]
        assert "title" in article and "url" in article
    assert isinstance(payload["notes"], str)


def _async_return(value):
    async def _inner(*_args, **_kwargs):
        return value

    return _inner


def test_check_news_blends_classifier_when_no_claimreview(monkeypatch: pytest.MonkeyPatch) -> None:
    client = TestClient(app)

    monkeypatch.setattr(check_news_route.factcheck_service, "query_claimreview", _async_return([]))
    monkeypatch.setattr(
        check_news_route.news_service,
        "search_news",
        _async_return([
            {
                "title": "Credibility questioned",
                "source": "Unknown blog",
                "url": "https://example.com/story",
            }
        ]),
    )
    monkeypatch.setattr(
        check_news_route.classifier_service,
        "classify_text",
        _async_return({
            "provider": "local",
            "score": 0.92,
            "explanation": "High sensational term count",
        }),
    )
    monkeypatch.setattr(check_news_route, "_estimate_news_contradiction_score", lambda _sources: 1.0)

    response = client.post("/check-news", json=MOCK_REQUEST)

    assert response.status_code == 200
    payload = response.json()
    assert payload["verdict"] == "fake"
    assert pytest.approx(payload["confidence"], abs=1e-6) == 0.9
    assert payload["classifier"]["provider"] == "local"
    assert payload["classifier"]["score"] == pytest.approx(0.92)
