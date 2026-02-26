"""NEWS CHUNK 3 — Backend Routing & Test Endpoint
Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import ALLOWED_ORIGINS, API_TITLE, API_VERSION, REDIS_URL, USE_REDIS
from app.routes.check_news import router as check_news_router
from app.utils.cache import Cache, is_redis_available

app = FastAPI(title=API_TITLE, version=API_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(check_news_router)


@app.get("/health", tags=["health"])
async def healthcheck() -> dict[str, str]:
    """Expose a lightweight readiness probe."""
    return {"status": "ok"}


@app.get("/ready", tags=["health"])
async def readiness() -> dict[str, object]:
    """Expose a readiness probe that validates core dependencies."""

    cache_check = await _probe_cache()
    redis_expected = bool(USE_REDIS and REDIS_URL)
    redis_available = cache_check.pop("redis_available", False)

    status = "ok"
    if cache_check["status"] == "fail":
        status = "fail"
    elif cache_check["status"] != "pass":
        status = "degraded"
    elif redis_expected and not redis_available:
        status = "degraded"

    return {
        "status": status,
        "checks": {
            "cache": cache_check,
            "redis": {
                "configured": redis_expected,
                "available": redis_available,
            },
        },
    }


async def _probe_cache() -> dict[str, object]:
    try:
        cache = Cache(ttl=2, max_items=8)
        await cache.set("ready", True, ttl=1)
        await cache.get("ready")
        cache_status = "pass"
        cache_error = None
    except Exception as exc:  # pragma: no cover - defensive guard
        cache_status = "fail"
        cache_error = str(exc)

    redis_available = False
    if USE_REDIS and REDIS_URL:
        try:
            redis_available = is_redis_available()
        except Exception as exc:  # pragma: no cover - defensive guard
            cache_status = "degraded" if cache_status == "pass" else cache_status
            cache_error = f"redis probe failed: {exc}"

    payload: dict[str, object] = {"status": cache_status, "redis_available": redis_available}
    if cache_error:
        payload["error"] = cache_error
    return payload
