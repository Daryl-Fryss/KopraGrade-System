"""Login check (JWT) and role check (farmer / buyer). Both are enforced here, on the server."""
from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .database import get_db
from .models import User
from .security import decode_access_token

bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    id: int
    role: str


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> CurrentUser:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Please log in first.")

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, ValueError, KeyError):
        raise HTTPException(
            status_code=401, detail="Your session is invalid or has expired. Please log in again."
        ) from None

    if user_id > 2147483647:  # larger than a PostgreSQL INTEGER: cannot be a real user
        raise HTTPException(status_code=401, detail="This account no longer exists.")
    role = await db.scalar(select(User.role).where(User.user_id == user_id))
    if role is None:
        raise HTTPException(status_code=401, detail="This account no longer exists.")
    return CurrentUser(id=user_id, role=role)


def require_role(*roles: str):
    """Use as a dependency, e.g.  Depends(require_role("farmer"))."""

    async def checker(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="Your account type is not allowed to do this.")
        return user

    return checker
