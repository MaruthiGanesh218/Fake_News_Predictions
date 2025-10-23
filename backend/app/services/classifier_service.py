"""NEWS CHUNK 9 - Testing + Caching Layer
Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.

Classifier service responsible for sourcing a fake-news likelihood score from an
external RapidAPI endpoint with a deterministic local fallback. Results are cached
through the shared caching utilities to avoid repeated lookups.
"""

from __future__ import annotations

import hashlib
import logging
import math
from typing import Any, Dict, Optional

import httpx

from app import config
from app.utils import cache

logger = logging.getLogger(__name__)


class ClassifierServiceError(Exception):
    """Base exception raised by the classifier service."""


class MissingCredentialsError(ClassifierServiceError):
    """Raised when RapidAPI credentials are required but not configured."""

_SENSATIONAL_TERMS = {
    "shocking",
    "breaking",
    "exposed",
    "hoax",
    "cover-up",
    "outrage",
    "collapse",
    "apocalypse",
    "secret",
    "reveal",
}

_REPUTABLE_TERMS = {
    "according",
    "research",
    "study",
    "reported",
    "analysis",
    "verified",
    "official",
    "evidence",
    "journal",
    "investigation",
}


def _clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def _hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


_CLASSIFIER_CACHE = cache.create_cache(
    "classifier.score",
    ttl=config.CLASSIFIER_CACHE_TTL_SECONDS,
    max_items=config.CLASSIFIER_CACHE_MAXSIZE,
)


def _make_cache_key(text: str, *, force_refresh: bool = False) -> str:
    trimmed = " ".join(text.split())
    digest = _hash_text(trimmed)
    provider = config.CLASSIFIER_PROVIDER
    _ = force_refresh
    return cache.make_key("classifier", provider, digest)


def _sanitize_for_logs(text: str, max_len: int = 120) -> str:
    cleaned = " ".join(text.split())
    return cleaned[: max_len - 3] + "..." if len(cleaned) > max_len else cleaned


@cache.cached(
    ttl=config.CLASSIFIER_CACHE_TTL_SECONDS,
    key_func=_make_cache_key,
    cache=_CLASSIFIER_CACHE,
    namespace="classifier.score",
)
async def classify_text(text: str, *, force_refresh: bool = False) -> Dict[str, Any]:
    """Return a classifier score for *text*.

    Score is a float between 0 (likely real) and 1 (likely fake). RapidAPI is
    preferred when configured; otherwise the deterministic local heuristic is used.
    """

    trimmed = text.strip()
    if not trimmed:
        return {
            "provider": "local",
            "score": 0.5,
            "explanation": "No text submitted for classification.",
        }

    _ = force_refresh

    result: Dict[str, Any]
    try:
        if config.CLASSIFIER_PROVIDER == "rapidapi":
            result = await _classify_via_rapidapi(trimmed)
        elif config.CLASSIFIER_PROVIDER == "local":
            result = _classify_locally(trimmed, reason="Configured to use local classifier")
        else:
            logger.warning("Unsupported classifier provider '%s'; falling back to local.", config.CLASSIFIER_PROVIDER)
            result = _classify_locally(trimmed, reason="Unsupported provider requested")
    except MissingCredentialsError:
        logger.warning("RapidAPI credentials missing; using local classifier for input: %s", _sanitize_for_logs(trimmed))
        result = _classify_locally(trimmed, reason="RapidAPI credentials missing")
    except ClassifierServiceError as exc:  # pragma: no cover - defensive guard
        logger.warning("Classifier provider error: %s; using local fallback.", exc)
        result = _classify_locally(trimmed, reason=str(exc))

    return result


async def _classify_via_rapidapi(text: str) -> Dict[str, Any]:
    api_key = config.RAPIDAPI_KEY
    api_host = config.RAPIDAPI_HOST
    endpoint = config.RAPIDAPI_CLASSIFIER_ENDPOINT

    if not api_key or not api_host:
        raise MissingCredentialsError("RAPIDAPI_KEY and RAPIDAPI_HOST are required for RapidAPI provider.")

    headers = {
        "Content-Type": "application/json",
        "X-RapidAPI-Key": api_key,
        "X-RapidAPI-Host": api_host,
    }
    payload = {"text": text}

    async with httpx.AsyncClient(timeout=config.CLASSIFIER_HTTP_TIMEOUT_SECONDS) as client:
        response = await client.post(endpoint, json=payload, headers=headers)
        if response.status_code == httpx.codes.TOO_MANY_REQUESTS:
            raise ClassifierServiceError("RapidAPI rate limit reached")
        response.raise_for_status()
        data = response.json()

    score = _extract_score(data)
    explanation = _extract_explanation(data)

    return {
        "provider": "rapidapi",
        "score": score,
        "explanation": explanation,
        "raw": data,
    }


def _extract_score(payload: Dict[str, Any]) -> float:
    raw_score = payload.get("score")
    if isinstance(raw_score, (int, float)):
        return _clamp(float(raw_score))

    prediction = payload.get("prediction")
    if isinstance(prediction, (int, float)):
        return _clamp(float(prediction))

    probability = payload.get("probability")
    if isinstance(probability, dict):
        fake_prob = probability.get("fake")
        if isinstance(fake_prob, (int, float)):
            return _clamp(float(fake_prob))

    # Fallback: treat unrecognised structures as neutral.
    return 0.5


def _extract_explanation(payload: Dict[str, Any]) -> Optional[str]:
    explanation = payload.get("explanation")
    if isinstance(explanation, str) and explanation.strip():
        return explanation.strip()[:200]

    reason = payload.get("reason") or payload.get("label")
    if isinstance(reason, str) and reason.strip():
        return reason.strip()[:200]
    return None


def _classify_locally(text: str, *, reason: Optional[str] = None) -> Dict[str, Any]:
    words = [token.strip(".,!?;:\"'()").lower() for token in text.split() if token.strip()]
    sensational_hits = sum(1 for word in words if word in _SENSATIONAL_TERMS)
    reputable_hits = sum(1 for word in words if word in _REPUTABLE_TERMS)

    weight = 0.8 * sensational_hits - 0.6 * reputable_hits
    score = _clamp(1 / (1 + math.exp(-weight)))

    pieces = []
    if sensational_hits:
        pieces.append(f"Detected {sensational_hits} sensational terms")
    if reputable_hits:
        pieces.append(f"Found {reputable_hits} reputable cues")
    if reason:
        pieces.append(reason)

    explanation = "; ".join(pieces) if pieces else "Heuristic baseline applied."

    return {
        "provider": "local",
        "score": score,
        "explanation": explanation[:200],
    }


async def _clear_cache_for_tests() -> None:
    await _CLASSIFIER_CACHE.clear()


__all__ = [
    "classify_text",
    "MissingCredentialsError",
    "ClassifierServiceError",
    "_clear_cache_for_tests",
]
