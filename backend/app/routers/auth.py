"""POST /api/auth/register and POST /api/auth/login"""
import secrets

from fastapi import APIRouter, Depends, HTTPException
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User
from ..schemas import LoginIn, LoginResponse, RegisterIn, UserOut, UserResponse
from ..security import DUMMY_HASH, create_access_token, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _username_from_email(email: str, attempt: int) -> str:
    """The register form only asks for name/email/password/role, so a username is made from the email."""
    base = "".join(c for c in email.split("@")[0] if c.isalnum() or c in "_.-")[:40] or "user"
    if len(base) < 3:
        base += "000"
    return base if attempt == 0 else f"{base[:40]}{secrets.randbelow(9900) + 100}"


@router.post("/register", status_code=201, response_model=UserResponse)
async def register(body: RegisterIn, db: AsyncSession = Depends(get_db)):
    if await db.scalar(select(User.user_id).where(User.email == body.email)):
        raise HTTPException(409, "An account with this email already exists.")

    password_hash = await run_in_threadpool(hash_password, body.password)

    for attempt in range(5):
        user = User(
            username=body.username or _username_from_email(body.email, attempt),
            password=password_hash,
            name=body.name,
            email=body.email,
            role=body.role,
        )
        db.add(user)
        try:
            await db.commit()
            return {"user": UserOut.model_validate(user)}
        except IntegrityError:
            await db.rollback()
            # someone registered the same email at the very same moment?
            if await db.scalar(select(User.user_id).where(User.email == body.email)):
                raise HTTPException(409, "An account with this email already exists.") from None
            if body.username:
                raise HTTPException(409, "That username is already taken.") from None
            # a generated username collided: loop and try another one

    raise HTTPException(409, "Could not create a unique username. Please try again.")


@router.post("/login", response_model=LoginResponse)
async def login(body: LoginIn, db: AsyncSession = Depends(get_db)):
    email = body.email.strip().lower()
    if not email or not body.password:
        raise HTTPException(400, "Email and password are required.")

    user = await db.scalar(select(User).where(User.email == email))
    ok = await run_in_threadpool(verify_password, body.password, user.password if user else DUMMY_HASH)
    if user is None or not ok:
        raise HTTPException(401, "Invalid email or password.")

    return {"token": create_access_token(user.user_id, user.role), "user": UserOut.model_validate(user)}
