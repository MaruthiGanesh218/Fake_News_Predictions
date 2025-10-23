"""NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from app import config
from app.services import classifier_service, factcheck_service, news_service
from app.services.mock_service import analyze_text_mock

router = APIRouter(tags=["analysis"])
logger = logging.getLogger(__name__)


class CheckNewsRequest(BaseModel):
    """Incoming payload describing the news content to analyse."""

    text: str = Field(..., min_length=1, description="News article, snippet, or headline")


class SourceArticle(BaseModel):
    """Normalised article preview returned to the frontend."""

    title: str
    source: str
    url: str
    publishedAt: Optional[str] = None
    snippet: Optional[str] = None


class ClaimReviewItem(BaseModel):
    """Structured ClaimReview metadata promoted from fact-check providers."""

    claim: Optional[str] = None
    claimant: Optional[str] = None
    author: Optional[str] = None
    publisher: Optional[str] = None
    url: str
    review_date: Optional[str] = None
    truth_rating: Optional[str] = None
    excerpts: Optional[str] = None


class CheckNewsResponse(BaseModel):
    """Response payload exposing mock inference paired with live news matches."""

    verdict: str
    confidence: float
    evidence: list[str]
    sources: list[SourceArticle]
    claim_reviews: list[ClaimReviewItem]
    classifier: "ClassifierResult"
    notes: str


class ClassifierResult(BaseModel):
    provider: str
    score: float = Field(..., ge=0.0, le=1.0)
    explanation: Optional[str] = None


@router.post("/check-news", response_model=CheckNewsResponse, status_code=200)
async def check_news(
    payload: CheckNewsRequest,
    refresh: bool = Query(False, description="Force refresh of cached downstream results."),
) -> CheckNewsResponse:
    """Return deterministic mock analysis augmented with fact-check and news context."""

    response_data: dict[str, Any] = analyze_text_mock(payload.text)
    provider_label = config.NEWS_PROVIDER
    notes = response_data.get("notes", "")

    claim_reviews: list[dict[str, Any]] = []
    try:
        claim_reviews = await factcheck_service.query_claimreview(
            payload.text,
            limit=config.FACTCHECK_DEFAULT_LIMIT,
            force_refresh=refresh,
        )
    except Exception as exc:  # pragma: no cover - defensive guard
        logger.exception("FactCheck query failed", exc_info=exc)
        claim_reviews = []

    if claim_reviews:
        verdict, confidence = _promote_claim_review_verdict(claim_reviews)
        response_data["verdict"] = verdict
        response_data["confidence"] = confidence
        notes = _append_note(notes, "ClaimReview matched and promoted to primary verdict.")
    sources: list[dict[str, Any]] = []
    try:
        sources = await news_service.search_news(
            payload.text,
            limit=config.NEWS_DEFAULT_LIMIT,
            force_refresh=refresh,
        )
        if sources:
            notes = _append_note(notes, f"News results added from provider: {provider_label}")
        else:
            notes = _append_note(notes, "No related articles returned by the news provider.")
    except news_service.MissingCredentialsError as exc:
        notes = _append_note(notes, f"News provider credentials missing: {exc}.")
    except Exception as exc:  # pragma: no cover - defensive guard
        logger.exception("News search failed", exc_info=exc)
        notes = _append_note(notes, "News provider lookup failed; see logs for details.")

    classifier_payload = await _classify_with_fallback(payload.text, notes, refresh)
    notes = classifier_payload["notes"]

    if not claim_reviews:
        combined_score = _combine_scores(classifier_payload["score"], _estimate_news_contradiction_score(sources))
        verdict, confidence = _map_score_to_verdict(combined_score)
        response_data["verdict"] = verdict
        response_data["confidence"] = confidence
        notes = _append_note(notes, "Verdict blended classifier and news heuristics.")

    response_data["sources"] = sources
    response_data["claim_reviews"] = claim_reviews
    response_data["classifier"] = ClassifierResult(
        provider=classifier_payload["provider"],
        score=classifier_payload["score"],
        explanation=classifier_payload.get("explanation"),
    )
    response_data["notes"] = notes
    return CheckNewsResponse.model_validate(response_data)


def _append_note(existing: str, addition: str) -> str:
    cleaned_existing = existing.strip()
    if not cleaned_existing:
        return addition
    return f"{cleaned_existing} {addition}".strip()


def _promote_claim_review_verdict(reviews: list[dict[str, Any]]) -> tuple[str, float]:
    if not reviews:
        return "unsure", 0.5

    rating = (reviews[0].get("truth_rating") or "").strip().lower()

    negative_aliases = {
        "false",
        "pants on fire",
        "incorrect",
        "fake",
        "fiction",
        "wrong",
        "misleading",
    }
    positive_aliases = {
        "true",
        "accurate",
        "correct",
        "verified",
        "true story",
    }
    mixed_aliases = {
        "mixture",
        "half true",
        "partly true",
        "partly false",
        "mixed",
        "in between",
    }

    if rating in negative_aliases:
        return "fake", 0.95
    if rating in positive_aliases:
        return "real", 0.95
    if rating in mixed_aliases:
        return "unsure", 0.75

    return "unsure", 0.6


async def _classify_with_fallback(text: str, notes: str, refresh: bool) -> dict[str, Any]:
    try:
        result = await classifier_service.classify_text(text, force_refresh=refresh)
    except Exception as exc:  # pragma: no cover - defensive guard
        logger.exception("Classifier invocation failed", exc_info=exc)
        result = {
            "provider": "local",
            "score": 0.5,
            "explanation": "Classifier unavailable; defaulting to neutral score.",
        }

    note_suffix = f"Classifier provider {result['provider']} executed." if result.get("provider") else "Classifier executed."
    updated_notes = _append_note(notes, note_suffix)
    return {
        "provider": result.get("provider", "local"),
        "score": float(result.get("score", 0.5)),
        "explanation": result.get("explanation"),
        "notes": updated_notes,
    }


def _estimate_news_contradiction_score(sources: list[dict[str, Any]]) -> float:
    if not sources:
        return 0.5

    credible_publishers = {"associated press", "reuters", "bbc", "new york times", "washington post"}
    credible_hits = 0
    for article in sources:
        source_name = (article.get("source") or "").strip().lower()
        if source_name in credible_publishers:
            credible_hits += 1

    ratio = credible_hits / max(len(sources), 1)
    contradiction_score = 0.4 * (1 - ratio) + 0.3
    return max(0.0, min(1.0, contradiction_score))


def _combine_scores(classifier_score: float, news_score: float) -> float:
    classifier_clamped = max(0.0, min(1.0, classifier_score))
    news_clamped = max(0.0, min(1.0, news_score))
    return 0.6 * classifier_clamped + 0.4 * news_clamped


def _map_score_to_verdict(score: float) -> tuple[str, float]:
    if score >= 0.7:
        return "fake", 0.9
    if score <= 0.3:
        return "real", 0.85
    return "unsure", 0.6
