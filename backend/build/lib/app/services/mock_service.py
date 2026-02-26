"""NEWS CHUNK 7 — Integrate RapidAPI Fake-News Classifier
Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
Behavior: Full write access. Create files, run checks, save results.

Mock analysis service used during the early online phase. The implementation is
intentionally deterministic so that frontend and automated tests can rely on a
stable contract until live integrations are wired in.
"""

from typing import Any, Dict

MOCK_RESPONSE: Dict[str, Any] = {
    "verdict": "unsure",
    "confidence": 0.5,
    "evidence": [],
    "sources": [],
    "claim_reviews": [],
    "classifier": {
        "provider": "local",
        "score": 0.5,
        "explanation": "Mock classifier response from NEWS CHUNK 7.",
    },
    "notes": (
        "This is a mock response from NEWS CHUNK 7. Fact-check and classifier "
        "verdicts are promoted when live integrations are active."
    ),
}


def analyze_text_mock(_: str) -> Dict[str, Any]:
    """Return the static response without inspecting the input text."""
    # Returning a shallow copy avoids accidental mutation by callers.
    return dict(MOCK_RESPONSE)
