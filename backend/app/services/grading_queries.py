"""The query that builds a "grading" (sample + image + result + class + farmer)."""
from datetime import timezone
from pathlib import PurePosixPath

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import ClassificationResult, CopraImage, CopraSample, QualityClass, User
from .grading_rules import build_recommendation, needs_review


def _joined(stmt: Select) -> Select:
    return (
        stmt.select_from(ClassificationResult)
        .join(CopraImage, CopraImage.image_id == ClassificationResult.image_id)
        .join(CopraSample, CopraSample.sample_id == CopraImage.sample_id)
        .join(QualityClass, QualityClass.quality_class_id == ClassificationResult.quality_class_id)
        .join(User, User.user_id == CopraSample.user_id)
    )


def grading_select() -> Select:
    return _joined(
        select(
            ClassificationResult.result_id.label("id"),
            CopraSample.sample_code,
            CopraSample.date_collected,
            CopraSample.user_id.label("farmer_id"),
            User.name.label("farmer_name"),
            CopraImage.image_path,
            QualityClass.class_name.label("grade"),
            QualityClass.description.label("grade_description"),
            ClassificationResult.confidence_score,
            ClassificationResult.classified_at,
        )
    )


def count_select() -> Select:
    return _joined(select(func.count(ClassificationResult.result_id)))


def to_grading(row) -> dict:
    confidence = float(row.confidence_score)
    return {
        "id": row.id,
        "sample_code": row.sample_code,
        "date_collected": row.date_collected,
        "image_url": "/images/" + PurePosixPath(row.image_path).name,
        "grade": row.grade,
        "grade_description": row.grade_description,
        "confidence_score": confidence,
        "needs_review": needs_review(confidence),
        # stored as UTC without a time zone -> mark it as UTC so the app converts it correctly
        "classified_at": row.classified_at.replace(tzinfo=timezone.utc),
        "recommendation": build_recommendation(row.grade, confidence),
        "farmer": {"user_id": row.farmer_id, "name": row.farmer_name},
    }


async def find_grading_by_id(db: AsyncSession, result_id: int) -> dict | None:
    if not 1 <= result_id <= 2147483647:
        return None
    row = (await db.execute(grading_select().where(ClassificationResult.result_id == result_id))).first()
    return to_grading(row) if row else None
