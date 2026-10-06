"""Test setup. The tests use a REAL PostgreSQL database (never your normal one).

Before running, set TEST_DATABASE_URL to an empty test database, for example:
  Windows (cmd):   set TEST_DATABASE_URL=postgresql+asyncpg://postgres:PASSWORD@localhost:5432/kopragrade_test
  Mac/Linux:       export TEST_DATABASE_URL=postgresql+asyncpg://postgres:PASSWORD@localhost:5432/kopragrade_test
The database is created automatically if it does not exist.
"""
import asyncio
import io
import os
import uuid

import numpy as np
import pytest
from PIL import Image


class FakeClassifier:
    """Stands in for the real model so most tests are fast."""

    def __init__(self) -> None:
        self.loaded = True
        self.error = None
        self.label = "Well-Dried"
        self.confidence = 93.4
        self.raise_error = False
        self.last_batch = None

    def predict(self, batch):
        self.last_batch = batch
        if self.raise_error:
            raise RuntimeError("boom")
        return self.label, self.confidence


@pytest.fixture(scope="session")
def client(tmp_path_factory):
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set TEST_DATABASE_URL to run the API tests (see tests/conftest.py).")

    images_dir = tmp_path_factory.mktemp("uploaded_images")
    os.environ["DATABASE_URL"] = url
    os.environ["JWT_SECRET"] = "test-secret-" + "x" * 40
    os.environ["IMAGES_DIR"] = str(images_dir)
    os.environ["MAX_UPLOAD_MB"] = "1"
    os.environ["APP_TIMEZONE"] = "Asia/Manila"
    os.environ["LOW_CONFIDENCE_THRESHOLD"] = "70"
    os.environ["MODEL_PATH"] = str(images_dir / "no-model.keras")
    os.environ["CLASS_NAMES_PATH"] = str(images_dir / "no-names.json")

    from app.db_setup import setup_database

    asyncio.run(setup_database(url))

    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app, raise_server_exceptions=False) as test_client:
        test_client.images_dir = images_dir
        test_client.database_url = url
        yield test_client


@pytest.fixture()
def fake(client):
    """The fake model, reset for every test."""
    classifier = FakeClassifier()
    original = client.app.state.classifier
    client.app.state.classifier = classifier
    yield classifier
    client.app.state.classifier = original


@pytest.fixture()
def db(client):
    """db(sql, *args) runs SQL straight on the test database and returns the rows."""
    import asyncpg
    from sqlalchemy.engine import make_url

    url = make_url(client.database_url)

    def run(sql, *args):
        async def go():
            conn = await asyncpg.connect(
                user=url.username, password=url.password, host=url.host, port=url.port or 5432, database=url.database
            )
            try:
                return await conn.fetch(sql, *args)
            finally:
                await conn.close()

        return asyncio.run(go())

    return run


def make_jpeg(color=(200, 190, 170), size=(300, 200)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color).save(buffer, format="JPEG")
    return buffer.getvalue()


def make_png(color=(120, 110, 90), size=(120, 90)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color).save(buffer, format="PNG")
    return buffer.getvalue()


def new_user(client, role="farmer", name="Juan Dela Cruz", password="password123"):
    email = f"{role}-{uuid.uuid4().hex[:10]}@example.com"
    res = client.post("/api/auth/register", json={"name": name, "email": email, "password": password, "role": role})
    assert res.status_code == 201, res.text
    login = client.post("/api/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200, login.text
    data = login.json()
    return {
        "email": email,
        "password": password,
        "id": data["user"]["user_id"],
        "token": data["token"],
        "headers": {"Authorization": f"Bearer {data['token']}"},
    }


def upload(client, user, data=None, filename="copra.jpg", content_type="image/jpeg"):
    data = data if data is not None else make_jpeg()
    return client.post(
        "/api/classification/predict",
        headers=user["headers"],
        files={"image": (filename, data, content_type)},
    )


@pytest.fixture()
def farmer(client):
    return new_user(client, "farmer")


@pytest.fixture()
def buyer(client):
    return new_user(client, "buyer", name="Maria Buyer")


__all__ = ["np"]
