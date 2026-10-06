import os
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import pytest

from .conftest import make_jpeg, make_png, new_user, upload


def stored_files(client):
    return sorted(p.name for p in client.images_dir.iterdir() if p.is_file())


def test_farmer_grades_a_photo_and_everything_is_saved(client, farmer, fake, db):
    before = stored_files(client)
    res = upload(client, farmer)
    assert res.status_code == 201, res.text
    g = res.json()["grading"]

    assert g["grade"] == "Well-Dried"
    assert g["confidence_score"] == 93.4
    assert g["needs_review"] is False
    assert g["sample_code"].startswith("COPRA-")
    assert g["image_url"].startswith("/images/")
    assert g["farmer"] == {"user_id": farmer["id"], "name": "Juan Dela Cruz"}
    assert g["grade_description"]
    assert "well dried" in g["recommendation"]  # created by the API, not read from the database
    assert g["classified_at"].endswith("Z")  # UTC marker, so the Flutter app converts it correctly

    # the model received a 224x224 RGB float batch with raw 0-255 pixels
    assert fake.last_batch.shape == (1, 224, 224, 3)
    assert fake.last_batch.dtype == np.float32
    assert 0 <= fake.last_batch.min() and fake.last_batch.max() <= 255

    # database: one sample, one image (path stored in copra_images), one result
    row = db(
        """SELECT i.image_path, r.confidence_score, q.class_name
             FROM kopragrade.classification_results r
             JOIN kopragrade.copra_images i ON i.image_id = r.image_id
             JOIN kopragrade.quality_classes q ON q.quality_class_id = r.quality_class_id
            WHERE r.result_id = $1""",
        g["id"],
    )[0]
    assert row["class_name"] == "Well-Dried"
    assert float(row["confidence_score"]) == 93.4
    assert row["image_path"].startswith("uploaded_images/") and row["image_path"].endswith(".jpg")

    # the photo file exists on disk and can be opened through /images/...
    new_files = set(stored_files(client)) - set(before)
    assert new_files == {row["image_path"].split("/")[-1]}
    shown = client.get(g["image_url"])
    assert shown.status_code == 200 and shown.content[:3] == b"\xff\xd8\xff"


def test_png_is_accepted(client, farmer, fake):
    res = upload(client, farmer, make_png(), "copra.png", "image/png")
    assert res.status_code == 201
    assert res.json()["grading"]["image_url"].endswith(".png")


def test_low_confidence_is_flagged_and_recommendation_has_note(client, farmer, fake):
    fake.label, fake.confidence = "Poorly Dried", 55.5
    g = upload(client, farmer).json()["grading"]
    assert g["grade"] == "Poorly Dried"
    assert g["needs_review"] is True
    assert "not very sure" in g["recommendation"]


def test_buyer_cannot_grade_and_login_is_required(client, buyer, fake):
    assert upload(client, buyer).status_code == 403
    res = client.post("/api/classification/predict", files={"image": ("a.jpg", make_jpeg(), "image/jpeg")})
    assert res.status_code == 401


def test_missing_image_field(client, farmer, fake):
    res = client.post("/api/classification/predict", headers=farmer["headers"])
    assert res.status_code == 400
    assert res.json() == {"error": 'Please attach one copra image in the "image" field.'}


def test_fake_image_is_rejected_and_nothing_saved(client, farmer, fake, db):
    before_files = stored_files(client)
    before = db("SELECT count(*) AS n FROM kopragrade.copra_samples")[0]["n"]
    res = upload(client, farmer, b"this is just text, not a picture", "copra.jpg", "image/jpeg")
    assert res.status_code == 415
    assert res.json() == {"error": "The file is not a real JPG or PNG image."}
    assert stored_files(client) == before_files
    assert db("SELECT count(*) AS n FROM kopragrade.copra_samples")[0]["n"] == before


def test_other_image_types_are_rejected(client, farmer, fake):
    gif = b"GIF89a" + b"\x00" * 50
    assert upload(client, farmer, gif, "a.gif", "image/gif").status_code == 415


def test_corrupt_jpeg_is_422(client, farmer, fake):
    res = upload(client, farmer, b"\xff\xd8\xff\xe0" + b"garbage" * 20)
    assert res.status_code == 422
    assert res.json()["error"].startswith("Could not read this image")


def test_too_large_is_413(client, farmer, fake):
    res = upload(client, farmer, b"\xff\xd8\xff" + b"\x00" * (1024 * 1024 + 10))  # limit is 1 MB in tests
    assert res.status_code == 413
    assert res.json() == {"error": "Image is too large (max 1 MB)."}


def test_model_not_available_is_503_and_nothing_saved(client, farmer, fake, db):
    fake.loaded = False
    before_files = stored_files(client)
    res = upload(client, farmer)
    assert res.status_code == 503
    assert stored_files(client) == before_files


def test_model_crash_is_500_and_nothing_saved(client, farmer, fake, db):
    fake.raise_error = True
    before_files = stored_files(client)
    before = db("SELECT count(*) AS n FROM kopragrade.classification_results")[0]["n"]
    res = upload(client, farmer)
    assert res.status_code == 500
    assert res.json() == {"error": "The grading model could not process this image."}
    assert stored_files(client) == before_files
    assert db("SELECT count(*) AS n FROM kopragrade.classification_results")[0]["n"] == before


def test_database_failure_after_inserts_rolls_everything_back(client, farmer, fake, db):
    """The sample and image rows are inserted first; the result row then fails the 0-100 CHECK."""
    before_files = stored_files(client)
    counts = lambda: [  # noqa: E731
        db(f"SELECT count(*) AS n FROM kopragrade.{t}")[0]["n"]
        for t in ("copra_samples", "copra_images", "classification_results")
    ]
    before = counts()
    fake.confidence = 150.0  # impossible value -> database refuses it
    res = upload(client, farmer)
    assert res.status_code == 500
    assert res.json() == {"error": "Something went wrong on the server."}
    assert counts() == before  # nothing half-saved
    assert stored_files(client) == before_files  # the photo was deleted again

    fake.confidence = 80.0  # and the next upload works normally
    assert upload(client, farmer).status_code == 201


def test_missing_quality_class_is_500_and_cleans_up(client, farmer, fake, db):
    before_files = stored_files(client)
    before = db("SELECT count(*) AS n FROM kopragrade.copra_samples")[0]["n"]
    fake.label = "Not A Real Grade"
    res = upload(client, farmer)
    assert res.status_code == 500
    assert "Quality classes are not set up" in res.json()["error"]
    assert stored_files(client) == before_files
    assert db("SELECT count(*) AS n FROM kopragrade.copra_samples")[0]["n"] == before


def test_sample_codes_are_unique_even_with_parallel_uploads(client, farmer, fake):
    def one(_):
        return upload(client, farmer)

    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(one, range(6)))
    assert all(r.status_code == 201 for r in results), [r.text for r in results]
    codes = [r.json()["grading"]["sample_code"] for r in results]
    assert len(set(codes)) == 6


def test_get_grading_rules(client, farmer, buyer, fake):
    other_farmer = new_user(client, "farmer", name="Other Farmer")
    gid = upload(client, farmer).json()["grading"]["id"]

    assert client.get(f"/api/gradings/{gid}", headers=farmer["headers"]).status_code == 200
    assert client.get(f"/api/gradings/{gid}", headers=buyer["headers"]).status_code == 200  # buyers can view any
    denied = client.get(f"/api/gradings/{gid}", headers=other_farmer["headers"])
    assert denied.status_code == 403
    assert denied.json() == {"error": "You can only view your own gradings."}

    assert client.get("/api/gradings/99999999", headers=farmer["headers"]).status_code == 404
    assert client.get("/api/gradings/99999999999", headers=farmer["headers"]).status_code == 404
    bad = client.get("/api/gradings/abc", headers=farmer["headers"])
    assert bad.status_code == 400
    assert bad.json() == {"error": "The id in the address must be a number."}
    assert client.get(f"/api/gradings/{gid}").status_code == 401


def test_history_roles_and_filters(client, buyer, fake, db):
    farmer_a = new_user(client, "farmer", name="Farmer A")
    farmer_b = new_user(client, "farmer", name="Farmer B")
    fake.label, fake.confidence = "Well-Dried", 90.0
    a1 = upload(client, farmer_a).json()["grading"]["id"]
    fake.label, fake.confidence = "Poorly Dried", 80.0
    a2 = upload(client, farmer_a).json()["grading"]["id"]
    b1 = upload(client, farmer_b).json()["grading"]["id"]

    mine = client.get("/api/history", headers=farmer_a["headers"]).json()
    assert {i["id"] for i in mine["items"]} == {a1, a2}
    assert mine["total"] == 2 and mine["limit"] == 50 and mine["offset"] == 0
    assert mine["items"][0]["id"] == a2  # newest first

    everyone = client.get("/api/history", headers=buyer["headers"], params={"limit": 100}).json()
    assert {a1, a2, b1} <= {i["id"] for i in everyone["items"]}

    poor = client.get("/api/history", headers=farmer_a["headers"], params={"grade": "Poorly Dried"}).json()
    assert [i["id"] for i in poor["items"]] == [a2]

    page = client.get("/api/history", headers=farmer_a["headers"], params={"limit": 1, "offset": 1}).json()
    assert page["total"] == 2 and [i["id"] for i in page["items"]] == [a1]

    # date filter works on the calendar day in Manila (UTC+8): 2026-09-30 16:30 UTC is 2026-10-01 00:30 there
    db("UPDATE kopragrade.classification_results SET classified_at = '2026-09-30 16:30:00' WHERE result_id = $1", a1)
    day = lambda f, t: client.get(  # noqa: E731
        "/api/history", headers=farmer_a["headers"], params={"from": f, "to": t}
    ).json()
    assert a1 in [i["id"] for i in day("2026-10-01", "2026-10-01")["items"]]
    assert a1 not in [i["id"] for i in day("2026-09-30", "2026-09-30")["items"]]
    assert a1 in [i["id"] for i in day("2026-09-30", "2026-10-01")["items"]]
    only_from = client.get("/api/history", headers=farmer_a["headers"], params={"from": "2026-10-01"}).json()
    assert {a1, a2} <= {i["id"] for i in only_from["items"]}
    only_to = client.get("/api/history", headers=farmer_a["headers"], params={"to": "2026-09-30"}).json()
    assert a1 not in [i["id"] for i in only_to["items"]]
    assert client.get("/api/history", headers=farmer_a["headers"]).json()["items"][-1]["classified_at"] == "2026-09-30T16:30:00Z"


def test_history_input_validation(client, farmer):
    h = farmer["headers"]
    cases = [
        ({"grade": "Excellent"}, "grade must be one of: Well-Dried, Moderately Dried, Poorly Dried."),
        ({"from": "2026-13-45"}, "from must be a date like 2026-09-30."),
        ({"to": "yesterday"}, "to must be a date like 2026-09-30."),
        ({"from": "2026-10-02", "to": "2026-10-01"}, '"from" must not be after "to".'),
        ({"limit": "0"}, "limit must be 1 to 100."),
        ({"limit": "101"}, "limit must be 1 to 100."),
        ({"limit": "abc"}, "limit must be 1 to 100."),
        ({"offset": "-1"}, "offset must be 0 or more."),
    ]
    for params, message in cases:
        res = client.get("/api/history", headers=h, params=params)
        assert res.status_code == 400, params
        assert res.json() == {"error": message}


# ---------- the real Keras model path (TensorFlow + OpenCV + Pillow) ----------
@pytest.fixture(scope="module")
def tiny_model_files(tmp_path_factory):
    tf = pytest.importorskip("tensorflow")
    import json

    folder = tmp_path_factory.mktemp("model")
    inputs = tf.keras.Input(shape=(224, 224, 3))
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(inputs)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    outputs = tf.keras.layers.Dense(3, activation="softmax")(x)
    tf.keras.Model(inputs, outputs).save(folder / "m.keras")
    (folder / "names.json").write_text(json.dumps(["Well-Dried", "Moderately Dried", "Poorly Dried"]))
    return folder / "m.keras", folder / "names.json"


def test_real_classifier_loads_and_predicts(tiny_model_files):
    from app.services.classifier import CopraClassifier
    from app.services.image_utils import preprocess_image

    classifier = CopraClassifier(*tiny_model_files)
    classifier.load()
    assert classifier.loaded and classifier.error is None
    label, confidence = classifier.predict(preprocess_image(make_jpeg()))
    assert label in ("Well-Dried", "Moderately Dried", "Poorly Dried")
    assert 0 <= confidence <= 100


def test_full_api_with_real_keras_model(client, farmer, tiny_model_files):
    from app.services.classifier import CopraClassifier

    classifier = CopraClassifier(*tiny_model_files)
    classifier.load()
    original = client.app.state.classifier
    client.app.state.classifier = classifier
    try:
        res = upload(client, farmer)
        assert res.status_code == 201, res.text
        g = res.json()["grading"]
        assert g["grade"] in ("Well-Dried", "Moderately Dried", "Poorly Dried")
        assert 0 <= g["confidence_score"] <= 100
        assert client.get("/api/health").json()["model_loaded"] is True
    finally:
        client.app.state.classifier = original


def test_classifier_reports_missing_and_wrong_files(tmp_path, tiny_model_files):
    from app.services.classifier import CopraClassifier, ModelNotAvailable

    missing = CopraClassifier(tmp_path / "nope.keras", tmp_path / "nope.json")
    missing.load()
    assert not missing.loaded and "not found" in missing.error
    with pytest.raises(ModelNotAvailable):
        missing.predict(np.zeros((1, 224, 224, 3), dtype="float32"))

    model_path, _ = tiny_model_files
    wrong_names = tmp_path / "names.json"
    wrong_names.write_text('["A", "B", "C"]')
    broken = CopraClassifier(model_path, wrong_names)
    broken.load()
    assert not broken.loaded and "class_names.json" in broken.error


def test_preprocess_handles_rotation_png_and_grayscale():
    import io

    from PIL import Image

    from app.services.image_utils import ImageProcessingError, preprocess_image

    gray = io.BytesIO()
    Image.new("L", (50, 80), 128).save(gray, format="PNG")
    assert preprocess_image(gray.getvalue()).shape == (1, 224, 224, 3)

    rgba = io.BytesIO()
    Image.new("RGBA", (50, 80), (10, 20, 30, 40)).save(rgba, format="PNG")
    assert preprocess_image(rgba.getvalue()).shape == (1, 224, 224, 3)

    with pytest.raises(ImageProcessingError):
        preprocess_image(b"not an image")


def test_not_copra_label_is_rejected_and_nothing_is_saved(client, farmer, fake):
    before = stored_files(client)
    fake.label, fake.confidence = "Not Copra", 97.0
    res = upload(client, farmer)
    assert res.status_code == 422
    assert "No copra detected" in res.json()["error"]
    assert stored_files(client) == before  # no photo kept


def test_very_unsure_photo_is_rejected(client, farmer, fake):
    before = stored_files(client)
    fake.label, fake.confidence = "Poorly Dried", 38.0  # below REJECT_BELOW_CONFIDENCE (50)
    res = upload(client, farmer)
    assert res.status_code == 422
    assert "No copra detected" in res.json()["error"]
    assert stored_files(client) == before
