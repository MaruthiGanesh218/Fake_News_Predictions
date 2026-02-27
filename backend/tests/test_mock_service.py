from __future__ import annotations

from app.services.mock_service import analyze_text_mock

EXPECTED_KEYS = {"verdict", "confidence", "evidence", "sources", "claim_reviews", "classifier", "notes"}
EXPECTED_CLASSIFIER_KEYS = {"provider", "score", "explanation"}


def test_analyze_text_mock_returns_expected_keys() -> None:
    """The mock service must return all keys required by the CheckNewsResponse contract."""
    response = analyze_text_mock("Any text")

    assert EXPECTED_KEYS.issubset(response.keys())
    assert isinstance(response["classifier"], dict)
    assert EXPECTED_CLASSIFIER_KEYS.issubset(response["classifier"].keys())


def test_analyze_text_mock_is_deterministic() -> None:
    """The mock service should return the same content regardless of input."""
    res1 = analyze_text_mock("First query")
    res2 = analyze_text_mock("Second query")

    assert res1 == res2


def test_analyze_text_mock_returns_shallow_copy() -> None:
    """The mock service must return a copy to prevent callers from mutating the base mock."""
    res1 = analyze_text_mock("Mutation test")

    # Mutate the returned dictionary
    res1["verdict"] = "mutated"

    res2 = analyze_text_mock("Second call")

    # The second call should still have the original verdict
    assert res2["verdict"] == "unsure"
    assert res1["verdict"] != res2["verdict"]
