"""Small helper with no side effects (so the database setup script can use it on its own)."""


def normalize_database_url(url: str) -> str:
    """Make sure the URL uses the asyncpg driver: postgresql+asyncpg://..."""
    url = url.strip()
    if url.startswith("postgresql+asyncpg://"):
        return url
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://"):]
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url[len("postgres://"):]
    raise RuntimeError(
        "DATABASE_URL must start with postgresql+asyncpg://  "
        "(example: postgresql+asyncpg://postgres:PASSWORD@localhost:5432/kopragrade_db)"
    )
