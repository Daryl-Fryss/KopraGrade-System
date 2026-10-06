"""Reads the settings from backend/.env (python-dotenv) and from the environment."""
import os
from dataclasses import dataclass
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from dotenv import load_dotenv

from .dburl import normalize_database_url
from .paths import BACKEND_DIR, PROJECT_DIR  # noqa: F401  (PROJECT_DIR is re-exported)

# Values already set in the real environment win over the .env file.
load_dotenv(BACKEND_DIR / ".env")


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required setting {name}. Copy .env.example to .env and fill it in.")
    return value


def _number(name: str, default: str, kind=float):
    raw = os.environ.get(name, default).strip() or default
    try:
        return kind(raw)
    except ValueError:
        raise RuntimeError(f"Setting {name} must be a number, but it is: {raw!r}") from None


def _path(name: str, default: str) -> Path:
    raw = os.environ.get(name, "").strip() or default
    path = Path(raw)
    return (path if path.is_absolute() else BACKEND_DIR / path).resolve()


@dataclass(frozen=True)
class Settings:
    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int
    images_dir: Path
    max_upload_bytes: int
    low_confidence_threshold: float
    reject_below_confidence: float
    cors_origins: list[str]
    app_timezone: str
    model_path: Path
    class_names_path: Path


def load_settings() -> Settings:
    jwt_secret = _required("JWT_SECRET")
    if len(jwt_secret) < 32 or jwt_secret.startswith("PASTE_"):
        raise RuntimeError(
            "JWT_SECRET is too short or still the example value. Create a real one with:\n"
            '  python -c "import secrets; print(secrets.token_hex(32))"'
        )

    timezone_name = os.environ.get("APP_TIMEZONE", "Asia/Manila").strip() or "Asia/Manila"
    try:
        ZoneInfo(timezone_name)
    except (ZoneInfoNotFoundError, ValueError):
        raise RuntimeError(f"APP_TIMEZONE {timezone_name!r} is not a valid time zone name.") from None

    origins_raw = os.environ.get("CORS_ORIGINS", "*").strip() or "*"
    origins = ["*"] if origins_raw == "*" else [o.strip() for o in origins_raw.split(",") if o.strip()]

    settings = Settings(
        database_url=normalize_database_url(_required("DATABASE_URL")),
        jwt_secret=jwt_secret,
        jwt_expire_minutes=_number("JWT_EXPIRE_MINUTES", "1440", int),
        images_dir=_path("IMAGES_DIR", "../uploaded_images"),
        max_upload_bytes=int(_number("MAX_UPLOAD_MB", "5", float) * 1024 * 1024),
        low_confidence_threshold=_number("LOW_CONFIDENCE_THRESHOLD", "70", float),
        reject_below_confidence=_number("REJECT_BELOW_CONFIDENCE", "50", float),
        cors_origins=origins,
        app_timezone=timezone_name,
        model_path=_path("MODEL_PATH", "model/kopragrade_model.keras"),
        class_names_path=_path("CLASS_NAMES_PATH", "model/class_names.json"),
    )
    settings.images_dir.mkdir(parents=True, exist_ok=True)
    return settings


settings = load_settings()
