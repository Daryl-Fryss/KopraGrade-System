"""GET /api/history?grade=&from=YYYY-MM-DD&to=YYYY-MM-DD&limit=&offset=

Farmers get their own gradings; buyers get everyone's (read-only).
"""
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..constants import GRADES
from ..database import get_db
from ..deps import CurrentUser, get_current_user
from ..models import ClassificationResult, CopraSample, QualityClass
from ..schemas import HistoryResponse
from ..services.grading_queries import count_select, grading_select, to_grading

router = APIRouter(prefix="/api/history", tags=["history"])


def _parse_date(value: str, name: str) -> date:
    try:
        if len(value) != 10:
            raise ValueError
        return date.fromisoformat(value)
    except ValueError:
        raise HTTPException(400, f"{name} must be a date like 2026-09-30.") from None


def _parse_int(value: str | None, name: str, default: int, minimum: int, maximum: int | None, message: str) -> int:
    if value is None:
        return default
    try:
        number = int(value)
    except ValueError:
        raise HTTPException(400, message) from None
    if number < minimum or (maximum is not None and number > maximum):
        raise HTTPException(400, message)
    return number


def _day_start_utc(day: date) -> datetime:
    """Midnight of this calendar day in the app's time zone, as naive UTC (how timestamps are stored)."""
    local = datetime.combine(day, time.min, tzinfo=ZoneInfo(settings.app_timezone))
    return local.astimezone(timezone.utc).replace(tzinfo=None)


@router.get("", response_model=HistoryResponse)
async def history(
    grade: str | None = Query(None),
    date_from: str | None = Query(None, alias="from"),
    date_to: str | None = Query(None, alias="to"),
    limit: str | None = Query(None),
    offset: str | None = Query(None),
    user: CurrentUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conditions = []

    if user.role == "farmer":
        conditions.append(CopraSample.user_id == user.id)
    if grade is not None:
        if grade not in GRADES:
            raise HTTPException(400, f"grade must be one of: {', '.join(GRADES)}.")
        conditions.append(QualityClass.class_name == grade)

    start = end = None
    if date_from is not None:
        start = _parse_date(date_from, "from")
    if date_to is not None:
        end = _parse_date(date_to, "to")
    if start and end and start > end:
        raise HTTPException(400, '"from" must not be after "to".')
    if start:
        conditions.append(ClassificationResult.classified_at >= _day_start_utc(start))
    if end:
        conditions.append(ClassificationResult.classified_at < _day_start_utc(end + timedelta(days=1)))

    page_size = _parse_int(limit, "limit", 50, 1, 100, "limit must be 1 to 100.")
    skip = _parse_int(offset, "offset", 0, 0, None, "offset must be 0 or more.")

    total = await db.scalar(count_select().where(*conditions))
    rows = await db.execute(
        grading_select()
        .where(*conditions)
        .order_by(ClassificationResult.classified_at.desc(), ClassificationResult.result_id.desc())
        .limit(page_size)
        .offset(skip)
    )
    return {"total": total, "limit": page_size, "offset": skip, "items": [to_grading(r) for r in rows]}
