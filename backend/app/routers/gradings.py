"""GET /api/gradings/{id} - farmers see their own, buyers can see any grading."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..deps import CurrentUser, get_current_user
from ..schemas import GradingResponse
from ..services.grading_queries import find_grading_by_id

router = APIRouter(prefix="/api/gradings", tags=["gradings"])


@router.get("/{grading_id}", response_model=GradingResponse)
async def get_grading(
    grading_id: int, user: CurrentUser = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    grading = await find_grading_by_id(db, grading_id)
    if grading is None:
        raise HTTPException(404, "Grading not found.")
    if user.role == "farmer" and grading["farmer"]["user_id"] != user.id:
        raise HTTPException(403, "You can only view your own gradings.")
    return {"grading": grading}
