"""
Rate limiting utility for FastAPI endpoints.
"""

import time
import logging
from fastapi import HTTPException, Request, status
from app.utils import cache

logger = logging.getLogger(__name__)

# Configuration
RATE_LIMIT_WINDOW = 60  # seconds
RATE_LIMIT_MAX_REQUESTS = 20  # requests per window

# Get the cache backend
_cache = cache.create_cache("rate_limit", ttl=RATE_LIMIT_WINDOW)

async def check_rate_limit(request: Request):
    """
    Dependency to check if the client has exceeded the rate limit.
    Uses the client's IP address as the identifier.
    """
    client_ip = request.client.host if request.client else "unknown"

    # Create a unique key for this IP window
    # We use a sliding window approximation by bucketing time
    # For a strictly precise sliding window, we'd need a sorted set (Redis ZSET).
    # Here, we'll use a simple bucket approach for simplicity given the cache abstraction.
    # Key format: rate_limit:{ip}:{window_timestamp}
    current_window = int(time.time() // RATE_LIMIT_WINDOW)
    key = f"ip:{client_ip}:{current_window}"

    try:
        # Get current count
        # Note: app.utils.cache.get deserializes JSON, so we expect an int if it exists
        count = await _cache.get(key)

        if count is None:
            count = 0

        if isinstance(count, str):
            try:
                count = int(count)
            except ValueError:
                count = 0

        if count >= RATE_LIMIT_MAX_REQUESTS:
            logger.warning(f"Rate limit exceeded for IP: {client_ip}")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later.",
            )

        # Increment count
        # app.utils.cache doesn't seem to have an atomic INCR, so we GET and SET.
        # This has a race condition but is acceptable for this level of strictness.
        new_count = count + 1
        await _cache.set(key, new_count, ttl=RATE_LIMIT_WINDOW)

    except HTTPException:
        raise
    except Exception as e:
        # Fail open if cache errors
        logger.error(f"Rate limit check failed: {e}")
        pass
