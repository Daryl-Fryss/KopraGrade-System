"""Creates the database (if missing), then applies database/schema.sql and database/seed.sql.

Run from the backend folder:   python -m app.db_setup
Safe to run more than once.
"""
import asyncio
import os
import re
import sys

import asyncpg
from dotenv import load_dotenv
from sqlalchemy.engine import make_url

from .dburl import normalize_database_url
from .paths import BACKEND_DIR, PROJECT_DIR


async def setup_database(database_url: str) -> list[str]:
    """Returns the names of the quality classes that now exist."""
    url = make_url(normalize_database_url(database_url))
    db_name = url.database or ""
    if not re.fullmatch(r"[A-Za-z0-9_]+", db_name):
        raise RuntimeError(f"The database name must use only letters, numbers and _ (got: {db_name!r}).")

    connection = dict(
        user=url.username,
        password=url.password,
        host=url.host or "localhost",
        port=url.port or 5432,
    )

    # 1. create the database if needed (connect to the default "postgres" database first)
    admin = await asyncpg.connect(database="postgres", **connection)
    try:
        exists = await admin.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", db_name)
        if not exists:
            await admin.execute(f'CREATE DATABASE "{db_name}"')
            print(f"Created database {db_name}")
    finally:
        await admin.close()

    # 2. tables and reference data
    sql_dir = PROJECT_DIR / "database"
    schema_sql = (sql_dir / "schema.sql").read_text(encoding="utf-8")
    seed_sql = (sql_dir / "seed.sql").read_text(encoding="utf-8")
    conn = await asyncpg.connect(database=db_name, **connection)
    try:
        await conn.execute(schema_sql)
        await conn.execute(seed_sql)
        rows = await conn.fetch("SELECT class_name FROM kopragrade.quality_classes ORDER BY quality_class_id")
    finally:
        await conn.close()
    return [r["class_name"] for r in rows]


def main() -> None:
    # Only DATABASE_URL is needed here (JWT_SECRET etc. are not required for this step).
    load_dotenv(BACKEND_DIR / ".env")
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if not database_url:
        print("DATABASE_URL is missing. Copy .env.example to .env and fill it in.")
        sys.exit(1)
    try:
        classes = asyncio.run(setup_database(database_url))
    except asyncpg.InvalidPasswordError:
        print("Database setup failed: wrong PostgreSQL user or password. Check DATABASE_URL in backend/.env")
        sys.exit(1)
    except (OSError, asyncpg.PostgresConnectionError):
        print("Database setup failed: cannot reach PostgreSQL. Is it running? Check host and port in DATABASE_URL.")
        sys.exit(1)
    except Exception as exc:  # noqa: BLE001
        print(f"Database setup failed: {exc}")
        sys.exit(1)
    print("Database ready. Quality classes:", ", ".join(classes))


if __name__ == "__main__":
    main()
