"""Recommendation text and the low-confidence rule.

The recommendation is NOT stored in the database. It is created here from the grade and
the confidence every time a grading is sent to the app.
"""
from ..config import settings

# DRAFT wording: please review with your instructor / a copra grader.
RECOMMENDATIONS = {
    "Well-Dried": (
        "This copra is well dried and ready for sale or storage. "
        "Keep it in a dry, well-ventilated place to protect its quality."
    ),
    "Moderately Dried": (
        "This copra is only partly dried. "
        "Dry it a little longer, turning it regularly, before selling or storing it."
    ),
    "Poorly Dried": (
        "This copra is not dried enough. Keep drying it right away and check for mold. "
        "Do not store it until it is fully dry, because damp copra spoils quickly."
    ),
}

LOW_CONFIDENCE_NOTE = (
    " Note: the system is not very sure about this result. "
    "Please take a clearer photo in good daylight and check again before relying on it."
)


def needs_review(confidence: float) -> bool:
    return confidence < settings.low_confidence_threshold


def build_recommendation(grade: str, confidence: float) -> str:
    base = RECOMMENDATIONS.get(grade, "No recommendation is available for this grade.")
    return base + LOW_CONFIDENCE_NOTE if needs_review(confidence) else base
