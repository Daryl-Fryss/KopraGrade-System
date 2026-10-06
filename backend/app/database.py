"""Async SQLAlchemy engine (asyncpg driver) and the per-request session."""
from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from .config import settings

# timezone=UTC: every connection works in UTC, so stored timestamps are unambiguous.
engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,
    connect_args={"server_settings": {"timezone": "UTC"}},
)

SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
