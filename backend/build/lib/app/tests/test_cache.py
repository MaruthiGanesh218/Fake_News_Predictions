# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

import asyncio
from typing import List

import pytest

from app.utils import cache


@pytest.mark.asyncio
async def test_cache_set_get_round_trip() -> None:
    backend = cache.Cache(ttl=5, max_items=4)

    payload = {"value": 1}
    await backend.set("example", payload)
    result = await backend.get("example")

    assert result == payload
    assert result is not payload  # ensure a copy is returned when possible


@pytest.mark.asyncio
async def test_cache_respects_ttl_expiry() -> None:
    backend = cache.Cache(ttl=1, max_items=4)

    await backend.set("short", "value", ttl=0.1)
    await asyncio.sleep(0.2)

    assert await backend.get("short") is None


@pytest.mark.asyncio
async def test_cache_eviction_respects_lru_order() -> None:
    backend = cache.Cache(ttl=5, max_items=2)

    await backend.set("first", 1)
    await backend.set("second", 2)
    # Access first so that second becomes the oldest entry.
    assert await backend.get("first") == 1

    await backend.set("third", 3)

    assert await backend.get("second") is None
    assert await backend.get("first") == 1
    assert await backend.get("third") == 3


@pytest.mark.asyncio
async def test_cache_delete_and_clear() -> None:
    backend = cache.Cache(ttl=5, max_items=4)

    await backend.set("key", "value")
    await backend.delete("key")
    assert await backend.get("key") is None

    await backend.set("another", "item")
    await backend.clear()
    assert await backend.get("another") is None


@pytest.mark.asyncio
async def test_cached_decorator_respects_force_refresh() -> None:
    backend = cache.Cache(ttl=5, max_items=8)
    call_log: List[int] = []

    @cache.cached(cache=backend, ttl=1)
    async def compute(value: int, *, force_refresh: bool = False) -> int:
        call_log.append(value)
        _ = force_refresh
        return value * 2

    assert await compute(5) == 10
    assert await compute(5) == 10
    assert call_log == [5]

    assert await compute(5, force_refresh=True) == 10
    assert call_log == [5, 5]


@pytest.mark.asyncio
async def test_create_cache_falls_back_when_redis_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(cache.config, "USE_REDIS", False)
    monkeypatch.setattr(cache.config, "REDIS_URL", None)

    backend = cache.create_cache("unit-test", ttl=60, max_items=16)

    await backend.set("key", "value")
    assert await backend.get("key") == "value"