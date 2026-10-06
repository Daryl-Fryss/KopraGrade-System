import uuid
from datetime import datetime, timedelta, timezone

import jwt

from .conftest import new_user


def test_health(client):
    res = client.get("/api/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"
    assert "model_loaded" in res.json()


def test_database_has_exactly_the_five_tables_and_no_recommendations(db):
    rows = db("SELECT table_name FROM information_schema.tables WHERE table_schema = 'kopragrade'")
    assert {r["table_name"] for r in rows} == {
        "users",
        "copra_samples",
        "copra_images",
        "quality_classes",
        "classification_results",
    }


def test_three_quality_classes_are_seeded(db):
    rows = db("SELECT class_name FROM kopragrade.quality_classes ORDER BY quality_class_id")
    assert [r["class_name"] for r in rows] == ["Well-Dried", "Moderately Dried", "Poorly Dried"]


def test_register_creates_user_and_hashes_password(client, db):
    email = f"ana-{uuid.uuid4().hex[:8]}@example.com"
    res = client.post(
        "/api/auth/register",
        json={"name": "  Ana Santos ", "email": email.upper(), "password": "password123", "role": "farmer"},
    )
    assert res.status_code == 201
    user = res.json()["user"]
    assert user["email"] == email  # lower-cased
    assert user["name"] == "Ana Santos"  # trimmed
    assert user["role"] == "farmer"
    assert "password" not in user
    stored = db("SELECT password FROM kopragrade.users WHERE email = $1", email)[0]["password"]
    assert stored.startswith("$2") and stored != "password123"  # bcrypt hash


def test_register_duplicate_email_is_409(client):
    user = new_user(client)
    res = client.post(
        "/api/auth/register",
        json={"name": "Someone", "email": user["email"].upper(), "password": "password123", "role": "buyer"},
    )
    assert res.status_code == 409
    assert res.json() == {"error": "An account with this email already exists."}


def test_register_validation_errors_are_400_with_error_message(client):
    base = {"name": "Ana Santos", "email": "ana@example.com", "password": "password123", "role": "farmer"}
    cases = [
        ({**base, "name": "A"}, "Name must be 2 to 100 characters."),
        ({**base, "email": "not-an-email"}, "Please enter a valid email address."),
        ({**base, "password": "short"}, "Password must be at least 8 characters."),
        ({**base, "password": "x" * 73}, "Password is too long (max 72 bytes)."),
        ({**base, "role": "admin"}, 'Role must be "farmer" or "buyer".'),
        ({**base, "username": "a b"}, "Username must be 3-50 characters: letters, numbers, dot, dash or underscore."),
    ]
    for body, message in cases:
        res = client.post("/api/auth/register", json=body)
        assert res.status_code == 400, body
        assert res.json() == {"error": message}


def test_register_missing_field_and_bad_json(client):
    res = client.post("/api/auth/register", json={"email": "a@b.co", "password": "password123", "role": "farmer"})
    assert res.status_code == 400
    assert "error" in res.json()
    bad = client.post("/api/auth/register", content=b"{not json", headers={"Content-Type": "application/json"})
    assert bad.status_code == 400
    assert bad.json() == {"error": "Request body is not valid JSON."}


def test_register_same_email_prefix_gets_unique_usernames(client):
    prefix = f"same{uuid.uuid4().hex[:6]}"
    names = set()
    for domain in ("one.com", "two.com", "three.com"):
        res = client.post(
            "/api/auth/register",
            json={"name": "Same Prefix", "email": f"{prefix}@{domain}", "password": "password123", "role": "farmer"},
        )
        assert res.status_code == 201, res.text
        names.add(res.json()["user"]["username"])
    assert len(names) == 3


def test_login_success_and_failures(client):
    user = new_user(client)
    ok = client.post("/api/auth/login", json={"email": user["email"].upper(), "password": user["password"]})
    assert ok.status_code == 200
    assert ok.json()["token"] and ok.json()["user"]["email"] == user["email"]

    wrong = client.post("/api/auth/login", json={"email": user["email"], "password": "wrong-password"})
    assert wrong.status_code == 401
    assert wrong.json() == {"error": "Invalid email or password."}

    unknown = client.post("/api/auth/login", json={"email": "nobody@example.com", "password": "password123"})
    assert unknown.status_code == 401

    empty = client.post("/api/auth/login", json={"email": "", "password": ""})
    assert empty.status_code == 400
    assert empty.json() == {"error": "Email and password are required."}


def test_token_is_a_real_jwt_with_role(client):
    user = new_user(client, "buyer")
    payload = jwt.decode(user["token"], options={"verify_signature": False})
    assert payload["sub"] == str(user["id"]) and payload["role"] == "buyer" and "exp" in payload


def test_protected_routes_need_a_valid_token(client, farmer):
    assert client.get("/api/history").status_code == 401
    assert client.get("/api/users/me").status_code == 401
    assert client.get("/api/history", headers={"Authorization": "Bearer garbage"}).status_code == 401
    assert client.get("/api/history", headers={"Authorization": "Basic abc"}).status_code == 401

    from app.config import settings

    expired = jwt.encode(
        {"sub": str(farmer["id"]), "role": "farmer", "exp": datetime.now(timezone.utc) - timedelta(minutes=1)},
        settings.jwt_secret,
        algorithm="HS256",
    )
    res = client.get("/api/history", headers={"Authorization": f"Bearer {expired}"})
    assert res.status_code == 401
    assert "expired" in res.json()["error"]

    forged = jwt.encode(
        {"sub": str(farmer["id"]), "role": "farmer", "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        "a-different-secret-that-is-long-enough-1234567890",
        algorithm="HS256",
    )
    assert client.get("/api/history", headers={"Authorization": f"Bearer {forged}"}).status_code == 401


def test_token_of_deleted_user_is_rejected(client, db):
    user = new_user(client)
    db("DELETE FROM kopragrade.users WHERE user_id = $1", user["id"])
    res = client.get("/api/users/me", headers=user["headers"])
    assert res.status_code == 401
    assert res.json() == {"error": "This account no longer exists."}


def test_profile_get_and_update(client, farmer):
    me = client.get("/api/users/me", headers=farmer["headers"])
    assert me.status_code == 200 and me.json()["user"]["email"] == farmer["email"]

    upd = client.put("/api/users/me", headers=farmer["headers"], json={"name": " Juan D. ", "contact": " 0917 123 4567 "})
    assert upd.status_code == 200
    assert upd.json()["user"]["name"] == "Juan D."
    assert upd.json()["user"]["contact"] == "0917 123 4567"

    cleared = client.put("/api/users/me", headers=farmer["headers"], json={"name": "Juan D.", "contact": ""})
    assert cleared.json()["user"]["contact"] is None

    assert client.put("/api/users/me", headers=farmer["headers"], json={"name": "J"}).status_code == 400
    too_long = client.put("/api/users/me", headers=farmer["headers"], json={"name": "Juan", "contact": "9" * 51})
    assert too_long.status_code == 400
    assert too_long.json() == {"error": "Contact info must be text of at most 50 characters."}


def test_unknown_route_and_cors(client):
    res = client.get("/api/nothing-here")
    assert res.status_code == 404
    assert res.json() == {"error": "Route not found."}

    pre = client.options(
        "/api/classification/predict",
        headers={
            "Origin": "http://localhost:5555",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    assert pre.status_code == 200
    assert pre.headers["access-control-allow-origin"] == "*"
    assert "authorization" in pre.headers["access-control-allow-headers"].lower()
