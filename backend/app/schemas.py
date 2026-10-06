"""Request and response shapes (Pydantic)."""
import re
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, field_validator

from .constants import ROLES

EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
USERNAME_RE = re.compile(r"^[A-Za-z0-9_.-]{3,50}$")


def _clean_name(value: str) -> str:
    value = value.strip()
    if not 2 <= len(value) <= 100:
        raise ValueError("Name must be 2 to 100 characters.")
    return value


# ---------- requests ----------
class RegisterIn(BaseModel):
    name: str
    email: str
    password: str
    role: str
    username: str | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return _clean_name(v)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if len(v) > 255 or not EMAIL_RE.match(v):
            raise ValueError("Please enter a valid email address.")
        return v

    @field_validator("password")
    @classmethod
    def _password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters.")
        # bcrypt only uses the first 72 bytes, so longer passwords are rejected outright.
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password is too long (max 72 bytes).")
        return v

    @field_validator("role")
    @classmethod
    def _role(cls, v: str) -> str:
        if v not in ROLES:
            raise ValueError('Role must be "farmer" or "buyer".')
        return v

    @field_validator("username")
    @classmethod
    def _username(cls, v: str | None) -> str | None:
        if v is not None and not USERNAME_RE.match(v):
            raise ValueError("Username must be 3-50 characters: letters, numbers, dot, dash or underscore.")
        return v


class LoginIn(BaseModel):
    email: str = ""
    password: str = ""


class ProfileIn(BaseModel):
    name: str
    contact: str | None = None

    @field_validator("name")
    @classmethod
    def _name(cls, v: str) -> str:
        return _clean_name(v)

    @field_validator("contact")
    @classmethod
    def _contact(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if len(v) > 50:
            raise ValueError("Contact info must be text of at most 50 characters.")
        return v or None


# ---------- responses ----------
class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    username: str
    name: str
    email: str
    role: str
    contact: str | None = None


class UserResponse(BaseModel):
    user: UserOut


class LoginResponse(BaseModel):
    token: str
    user: UserOut


class FarmerOut(BaseModel):
    user_id: int
    name: str


class GradingOut(BaseModel):
    id: int
    sample_code: str
    date_collected: date
    image_url: str
    grade: str
    grade_description: str | None = None
    confidence_score: float
    needs_review: bool
    classified_at: datetime
    recommendation: str  # created from the grade by the API; not stored in the database
    farmer: FarmerOut


class GradingResponse(BaseModel):
    grading: GradingOut


class HistoryResponse(BaseModel):
    total: int
    limit: int
    offset: int
    items: list[GradingOut]
