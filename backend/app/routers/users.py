"""GET /api/users/me and PUT /api/users/me"""
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..deps import CurrentUser, get_current_user
from ..models import User
from ..schemas import ProfileIn, UserOut, UserResponse

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def read_me(user: CurrentUser = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    row = await db.scalar(select(User).where(User.user_id == user.id))
    return {"user": UserOut.model_validate(row)}


@router.put("/me", response_model=UserResponse)
async def update_me(
    body: ProfileIn, user: CurrentUser = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    row = await db.scalar(select(User).where(User.user_id == user.id))
    row.name = body.name
    row.contact = body.contact
    await db.commit()
    return {"user": UserOut.model_validate(row)}
