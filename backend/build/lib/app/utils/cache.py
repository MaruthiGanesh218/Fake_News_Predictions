# NEWS CHUNK 9 - Testing + Caching Layer
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

from __future__ import annotations

import asyncio
import base64
import copy
import functools
import hashlib
import importlib
import inspect
import json
import logging
import time
from collections import OrderedDict
from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Dict, Iterable, List, Optional

from app import config

try:  # pragma: no cover - optional dependency
    redis_async = importlib.import_module("redis.asyncio")  # type: ignore[assignment]
except ModuleNotFoundError:  # pragma: no cover - optional dependency
    redis_async = None  # type: ignore[assignment]

try:  # pragma: no cover - optional dependency
    aioredis = importlib.import_module("aioredis")  # type: ignore[assignment]
except ModuleNotFoundError:  # pragma: no cover - optional dependency
    aioredis = None  # type: ignore[assignment]


logger = logging.getLogger(__name__)


@dataclass(slots=True)
class _Entry:
    value: Any
    expires_at: float
    hits: int = 0


class Cache:
    """Thread-safe in-memory TTL cache implementing LRU eviction."""

    def __init__(self, ttl: int = 600, max_items: int = 1024) -> None:
        self._default_ttl = max(1, int(ttl))
        self._max_items = max(1, int(max_items))
        self._lock = asyncio.Lock()
        self._store: OrderedDict[str, _Entry] = OrderedDict()

    @property
    def default_ttl(self) -> int:
        return self._default_ttl

    @property
    def max_items(self) -> int:
        return self._max_items

    async def get(self, key: str) -> Optional[Any]:
        async with self._lock:
            self._purge_expired_locked()
            entry = self._store.get(key)
            if entry is None:
                return None
            entry.hits += 1
            self._store.move_to_end(key)
            return _clone(entry.value)

    async def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        ttl_seconds = self._resolve_ttl(ttl)
        expires_at = time.monotonic() + ttl_seconds
        async with self._lock:
            self._purge_expired_locked()
            self._store[key] = _Entry(value=_clone(value), expires_at=expires_at)
            self._store.move_to_end(key)
            while len(self._store) > self._max_items:
                popped_key, _ = self._store.popitem(last=False)
                logger.debug("Cache LRU eviction - key=%s", popped_key)

    async def delete(self, key: str) -> None:
        async with self._lock:
            self._store.pop(key, None)

    async def clear(self) -> None:
        async with self._lock:
            self._store.clear()

    def _resolve_ttl(self, ttl: Optional[int]) -> int:
        if ttl is None or ttl <= 0:
            return self._default_ttl
        return int(ttl)

    def _purge_expired_locked(self) -> None:
        now = time.monotonic()
        expired: List[str] = [key for key, entry in self._store.items() if entry.expires_at <= now]
        for key in expired:
            self._store.pop(key, None)


class RedisCache:
    """Redis-backed cache adapter with optional LRU trimming."""

    def __init__(self, client: Any, ttl: int = 600, namespace: str = "cache", max_items: Optional[int] = None) -> None:
        self._client = client
        self._namespace = namespace.rstrip(":") or "cache"
        self._default_ttl = max(1, int(ttl))
        self._max_items = int(max_items) if max_items else None
        self._index_key = f"{self._namespace}:keys"

    @property
    def default_ttl(self) -> int:
        return self._default_ttl

    @property
    def max_items(self) -> Optional[int]:
        return self._max_items

    async def get(self, key: str) -> Optional[Any]:
        namespaced = self._namespaced(key)
        raw = await self._client.get(namespaced)
        if raw is None:
            return None
        if self._max_items:
            await self._client.zadd(self._index_key, {namespaced: time.time()})
        try:
            return json.loads(raw)
        except json.JSONDecodeError:  # pragma: no cover - defensive guard
            logger.warning("Redis cache value for key=%s is not valid JSON; clearing entry.", key)
            await self.delete(key)
            return None

    async def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        payload = json.dumps(value, default=_json_fallback)
        ttl_seconds = self._resolve_ttl(ttl)
        namespaced = self._namespaced(key)
        await self._client.set(namespaced, payload, ex=ttl_seconds)
        if self._max_items:
            await self._client.zadd(self._index_key, {namespaced: time.time()})
            await self._trim()

    async def delete(self, key: str) -> None:
        namespaced = self._namespaced(key)
        await self._client.delete(namespaced)
        if self._max_items:
            await self._client.zrem(self._index_key, namespaced)

    async def clear(self) -> None:
        if self._max_items:
            keys = await self._client.zrange(self._index_key, 0, -1)
            if keys:
                await self._client.delete(*keys)
            await self._client.delete(self._index_key)
        else:
            pattern = f"{self._namespace}:*"
            keys = [key async for key in self._client.scan_iter(match=pattern)]
            if keys:
                await self._client.delete(*keys)

    def _namespaced(self, key: str) -> str:
        return f"{self._namespace}:{key}"

    def _resolve_ttl(self, ttl: Optional[int]) -> int:
        if ttl is None or ttl <= 0:
            return self._default_ttl
        return int(ttl)

    async def _trim(self) -> None:
        if not self._max_items:
            return
        count = await self._client.zcard(self._index_key)
        if count <= self._max_items:
            return
        overflow = count - self._max_items
        stale = await self._client.zrange(self._index_key, 0, overflow - 1)
        if stale:
            await self._client.delete(*stale)
            await self._client.zrem(self._index_key, *stale)


CacheLike = Any

_REGISTERED_CACHES: List[CacheLike] = []
_REDIS_CLIENT: Optional[Any] = None


def create_cache(namespace: str, *, ttl: int, max_items: Optional[int] = None) -> CacheLike:
    backend: CacheLike
    if _redis_enabled():
        client = _ensure_redis_client()
        if client is not None:
            backend = RedisCache(client, ttl=ttl, namespace=namespace, max_items=max_items)
        else:
            backend = Cache(ttl=ttl, max_items=max_items or config.CACHE_MAX_ITEMS)
    else:
        backend = Cache(ttl=ttl, max_items=max_items or config.CACHE_MAX_ITEMS)

    _REGISTERED_CACHES.append(backend)
    return backend


def cached(
    *,
    ttl: Optional[int] = None,
    key_func: Optional[Callable[..., str]] = None,
    cache: Optional[CacheLike] = None,
    namespace: Optional[str] = None,
) -> Callable[[Callable[..., Awaitable[Any]]], Callable[..., Awaitable[Any]]]:
    """Decorator that wraps async functions with cache lookups."""

    def decorator(func: Callable[..., Awaitable[Any]]) -> Callable[..., Awaitable[Any]]:
        sig = inspect.signature(func)
        backend = cache or create_cache(namespace or f"{func.__module__}.{func.__qualname__}", ttl=ttl or config.CACHE_TTL_SECONDS)
        cache_namespace = namespace or f"{func.__module__}.{func.__qualname__}"
        ttl_value = ttl if ttl is not None else getattr(backend, "default_ttl", config.CACHE_TTL_SECONDS)

        @functools.wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            bound = sig.bind_partial(*args, **kwargs)
            force_refresh = bool(bound.arguments.get("force_refresh", False))
            key = _build_cache_key(cache_namespace, key_func, sig, args, kwargs)
            if not force_refresh:
                cached_value = await backend.get(key)
                if cached_value is not None:
                    return cached_value
            result = await func(*args, **kwargs)
            await backend.set(key, result, ttl=ttl_value)
            return result

        async def invalidate(*invalidate_args: Any, **invalidate_kwargs: Any) -> None:
            key = _build_cache_key(cache_namespace, key_func, sig, invalidate_args, invalidate_kwargs)
            await backend.delete(key)

        wrapper.invalidate = invalidate  # type: ignore[attr-defined]
        wrapper.cache_backend = backend  # type: ignore[attr-defined]
        wrapper.cache_namespace = cache_namespace  # type: ignore[attr-defined]
        return wrapper

    return decorator


def make_key(namespace: str, *parts: Any) -> str:
    serialised = "|".join(str(part) for part in parts)
    digest = hashlib.sha256(serialised.encode("utf-8")).digest()
    encoded = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
    return f"{namespace}:{encoded}"


async def clear_registered_caches() -> None:
    for backend in _REGISTERED_CACHES:
        try:
            await backend.clear()
        except Exception as exc:  # pragma: no cover - defensive guard
            logger.warning("Failed to clear cache backend %s: %s", backend, exc)


def is_redis_available() -> bool:
    return _redis_enabled() and _ensure_redis_client() is not None


def _redis_enabled() -> bool:
    return bool(config.USE_REDIS and config.REDIS_URL)


def _ensure_redis_client() -> Optional[Any]:
    global _REDIS_CLIENT
    if _REDIS_CLIENT is not None:
        return _REDIS_CLIENT
    if not _redis_enabled():
        return None
    url = config.REDIS_URL
    assert url is not None
    client: Optional[Any] = None
    if redis_async is not None:  # pragma: no branch - prefer redis>=4
        try:
            client = redis_async.from_url(url, encoding="utf-8", decode_responses=True)
        except Exception as exc:  # pragma: no cover - defensive guard
            logger.warning("Failed to initialise redis.asyncio client: %s", exc)
            client = None
    if client is None and aioredis is not None:
        try:
            client = aioredis.from_url(url, encoding="utf-8", decode_responses=True)
        except Exception as exc:  # pragma: no cover - defensive guard
            logger.warning("Failed to initialise aioredis client: %s", exc)
    if client is None:
        logger.warning("Redis requested but no compatible client available; falling back to in-memory cache.")
        return None
    _REDIS_CLIENT = client
    return _REDIS_CLIENT


def _build_cache_key(
    namespace: str,
    key_func: Optional[Callable[..., str]],
    sig: inspect.Signature,
    args: Iterable[Any],
    kwargs: Dict[str, Any],
) -> str:
    if key_func is not None:
        return key_func(*args, **kwargs)
    bound = sig.bind_partial(*args, **kwargs)
    bound.arguments.pop("force_refresh", None)
    serialisable = _normalise_arguments(bound.arguments)
    payload = json.dumps(serialisable, sort_keys=True, separators=(",", ":"))
    return make_key(namespace, payload)


def _normalise_arguments(arguments: Dict[str, Any]) -> Dict[str, Any]:
    return {key: _serialise(value) for key, value in sorted(arguments.items(), key=lambda item: item[0])}


def _serialise(value: Any) -> Any:
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if isinstance(value, dict):
        return {str(k): _serialise(v) for k, v in sorted(value.items(), key=lambda item: str(item[0]))}
    if isinstance(value, (list, tuple, set)):
        return [_serialise(item) for item in value]
    return repr(value)


def _clone(value: Any) -> Any:
    try:
        return copy.deepcopy(value)
    except Exception:  # pragma: no cover - fallback for uncopyable payloads
        return value


def _json_fallback(value: Any) -> Any:  # pragma: no cover - fallback for json dumps
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if isinstance(value, (list, tuple, set)):
        return [_json_fallback(item) for item in value]
    if isinstance(value, dict):
        return {str(key): _json_fallback(val) for key, val in value.items()}
    return repr(value)


__all__ = [
    "Cache",
    "RedisCache",
    "cached",
    "create_cache",
    "make_key",
    "clear_registered_caches",
    "is_redis_available",
]
