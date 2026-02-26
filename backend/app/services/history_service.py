"""
Services for managing and retrieving search history.
"""

import json
import logging
from typing import List

from app import config
from app.utils import cache

logger = logging.getLogger(__name__)

# Key for storing the global history list
_HISTORY_CACHE_KEY = "global_search_history"
_HISTORY_MAX_ITEMS = 10  # Store last 10 searches

# Get the cache backend
_cache = cache.create_cache("history", ttl=86400)

async def get_recent_searches(limit: int = 5) -> List[str]:
    """
    Retrieve the most recent unique search queries.
    """
    try:
        # Try to get the list from cache
        # Since cache.get returns deserialized value if json, we expect a list
        raw_data = await _cache.get(_HISTORY_CACHE_KEY)
        if not raw_data:
            return []

        # If it's a string, try to parse it (though cache.get should handle it)
        if isinstance(raw_data, str):
             try:
                 history = json.loads(raw_data)
             except json.JSONDecodeError:
                 return []
        elif isinstance(raw_data, list):
            history = raw_data
        else:
            return []

        return history[:limit]
    except Exception as e:
        logger.error(f"Error retrieving search history: {e}")
        return []

async def add_to_history(text: str) -> None:
    """
    Add a search query to the history.
    Maintains a unique list of recent searches, trimming older entries.
    """
    if not text or not text.strip():
        return

    cleaned_text = text.strip()
    # Limit stored text length to keep it readable
    if len(cleaned_text) > 100:
        cleaned_text = cleaned_text[:97] + "..."

    try:
        current_history = await get_recent_searches(limit=_HISTORY_MAX_ITEMS)

        # Remove if exists to move to top
        if cleaned_text in current_history:
            current_history.remove(cleaned_text)

        # Insert at beginning
        current_history.insert(0, cleaned_text)

        # Trim to max size
        if len(current_history) > _HISTORY_MAX_ITEMS:
            current_history = current_history[:_HISTORY_MAX_ITEMS]

        # Store back to cache
        await _cache.set(_HISTORY_CACHE_KEY, current_history, ttl=86400) # 24 hours

    except Exception as e:
        logger.error(f"Error adding to search history: {e}")
