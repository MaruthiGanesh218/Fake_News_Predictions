"""NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.

Centralised configuration helpers for the FastAPI application. Keeping these in a
module simplifies future additions such as environment driven settings.
"""

from __future__ import annotations

import os
from typing import Final, Optional

from dotenv import load_dotenv

load_dotenv()


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    value = os.getenv(name)
    if value is None:
        return default
    stripped = value.strip()
    return stripped if stripped else default


def _env_int(name: str, default: int) -> int:
    raw_value = _env(name)
    if raw_value is None:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    raw_value = _env(name)
    if raw_value is None:
        return default
    try:
        return float(raw_value)
    except ValueError:
        return default


def _env_bool(name: str, default: bool = False) -> bool:
    raw_value = _env(name)
    if raw_value is None:
        return default
    lowered = raw_value.lower()
    return lowered in {"1", "true", "yes", "on"}


ALLOWED_ORIGINS: Final[list[str]] = [
    "http://localhost:5173",
    "http://localhost:3000",
]

API_TITLE: Final[str] = "Fake News Prediction API"
API_VERSION: Final[str] = "0.1.0"

CACHE_TTL_SECONDS: Final[int] = max(60, _env_int("CACHE_TTL_SECONDS", 600))
CACHE_MAX_ITEMS: Final[int] = max(4, _env_int("CACHE_MAX_ITEMS", 256))
USE_REDIS: Final[bool] = _env_bool("USE_REDIS", False)
REDIS_URL: Final[Optional[str]] = _env("REDIS_URL")

NEWS_PROVIDER: Final[str] = (_env("NEWS_PROVIDER", "newsapi") or "newsapi").lower()
NEWS_DEFAULT_LIMIT: Final[int] = max(1, _env_int("NEWS_DEFAULT_LIMIT", 3))
NEWS_CACHE_TTL_SECONDS: Final[int] = max(60, _env_int("NEWS_CACHE_TTL_SECONDS", 600))
NEWS_CACHE_MAXSIZE: Final[int] = max(4, _env_int("NEWS_CACHE_MAXSIZE", 64))
NEWS_HTTP_TIMEOUT_SECONDS: Final[float] = max(1.0, _env_float("NEWS_HTTP_TIMEOUT_SECONDS", 8.0))

NEWSAPI_ENDPOINT: Final[str] = _env("NEWSAPI_ENDPOINT", "https://newsapi.org/v2/everything")
GNEWS_ENDPOINT: Final[str] = _env("GNEWS_ENDPOINT", "https://gnews.io/api/v4/search")
NEWSDATA_ENDPOINT: Final[str] = _env("NEWSDATA_ENDPOINT", "https://newsdata.io/api/1/news")

NEWSAPI_KEY: Final[Optional[str]] = _env("NEWSAPI_KEY")
GNEWS_KEY: Final[Optional[str]] = _env("GNEWS_KEY")
NEWSDATA_KEY: Final[Optional[str]] = _env("NEWSDATA_KEY")

FACTCHECK_PROVIDER: Final[str] = (_env("FACTCHECK_PROVIDER", "google") or "google").lower()
FACTCHECK_DEFAULT_LIMIT: Final[int] = max(1, _env_int("FACTCHECK_DEFAULT_LIMIT", 5))
FACTCHECK_CACHE_TTL_SECONDS: Final[int] = max(60, _env_int("FACTCHECK_CACHE_TTL_SECONDS", 900))
FACTCHECK_CACHE_MAXSIZE: Final[int] = max(4, _env_int("FACTCHECK_CACHE_MAXSIZE", 64))
FACTCHECK_HTTP_TIMEOUT_SECONDS: Final[float] = max(1.0, _env_float("FACTCHECK_HTTP_TIMEOUT_SECONDS", 8.0))
GOOGLE_FACTCHECK_ENDPOINT: Final[str] = _env(
    "GOOGLE_FACTCHECK_ENDPOINT",
    "https://factchecktools.googleapis.com/v1alpha1/claims:search",
)
GOOGLE_FACTCHECK_KEY: Final[Optional[str]] = _env("GOOGLE_FACTCHECK_KEY")

CLASSIFIER_PROVIDER: Final[str] = (_env("CLASSIFIER_PROVIDER", "local") or "local").lower()
CLASSIFIER_CACHE_TTL_SECONDS: Final[int] = max(60, _env_int("CLASSIFIER_CACHE_TTL_SECONDS", 600))
CLASSIFIER_CACHE_MAXSIZE: Final[int] = max(4, _env_int("CLASSIFIER_CACHE_MAXSIZE", 64))
CLASSIFIER_HTTP_TIMEOUT_SECONDS: Final[float] = max(1.0, _env_float("CLASSIFIER_HTTP_TIMEOUT_SECONDS", 8.0))
RAPIDAPI_CLASSIFIER_ENDPOINT: Final[str] = _env(
    "RAPIDAPI_CLASSIFIER_ENDPOINT",
    "https://fake-news-detector.p.rapidapi.com/predict",
)
RAPIDAPI_KEY: Final[Optional[str]] = _env("RAPIDAPI_KEY")
RAPIDAPI_HOST: Final[Optional[str]] = _env("RAPIDAPI_HOST")


__all__ = [
    "ALLOWED_ORIGINS",
    "API_TITLE",
    "API_VERSION",
    "CACHE_TTL_SECONDS",
    "CACHE_MAX_ITEMS",
    "USE_REDIS",
    "REDIS_URL",
    "NEWS_PROVIDER",
    "NEWS_DEFAULT_LIMIT",
    "NEWS_CACHE_TTL_SECONDS",
    "NEWS_CACHE_MAXSIZE",
    "NEWS_HTTP_TIMEOUT_SECONDS",
    "NEWSAPI_ENDPOINT",
    "GNEWS_ENDPOINT",
    "NEWSDATA_ENDPOINT",
    "NEWSAPI_KEY",
    "GNEWS_KEY",
    "NEWSDATA_KEY",
    "FACTCHECK_PROVIDER",
    "FACTCHECK_DEFAULT_LIMIT",
    "FACTCHECK_CACHE_TTL_SECONDS",
    "FACTCHECK_CACHE_MAXSIZE",
    "FACTCHECK_HTTP_TIMEOUT_SECONDS",
    "GOOGLE_FACTCHECK_ENDPOINT",
    "GOOGLE_FACTCHECK_KEY",
    "CLASSIFIER_PROVIDER",
    "CLASSIFIER_CACHE_TTL_SECONDS",
    "CLASSIFIER_CACHE_MAXSIZE",
    "CLASSIFIER_HTTP_TIMEOUT_SECONDS",
    "RAPIDAPI_CLASSIFIER_ENDPOINT",
    "RAPIDAPI_KEY",
    "RAPIDAPI_HOST",
]
