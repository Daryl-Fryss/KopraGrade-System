"""POST /api/classification/predict  (farmers only)

Image preprocessing -> MobileNetV2 inference -> quality classification -> confidence score
-> database storage. Everything happens inside this FastAPI application.
"""
import logging
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..constants import NOT_COPRA, SAMPLE_CODE_LOCK
from ..database import get_db
from ..deps import CurrentUser, require_role
from ..models import ClassificationResult, CopraImage, CopraSample, QualityClass
from ..schemas import GradingResponse
from ..services.classifier import CopraClassifier, ModelNotAvailable
from ..services.grading_queries import find_grading_by_id
from ..services.image_utils import ImageProcessingError, detect_image_type, preprocess_image

logger = logging.getLogger("kopragrade")
router = APIRouter(prefix="/api/classification", tags=["classification"])


def _remove_file(path) -> None:
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass


@router.post("/predict", status_code=201, response_model=GradingResponse)
async def predict(
    request: Request,
    image: UploadFile = File(...),
    user: CurrentUser = Depends(require_role("farmer")),
    db: AsyncSession = Depends(get_db),
):
    classifier: CopraClassifier = request.app.state.classifier

    # 1. read the upload (at most the limit + 1 byte, so we can tell it was too big)
    data = await image.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        mb = round(settings.max_upload_bytes / 1024 / 1024)
        raise HTTPException(413, f"Image is too large (max {mb} MB).")
    if not data:
        raise HTTPException(400, 'Please attach one copra image in the "image" field.')

    # 2. make sure the bytes really are a JPG/PNG
    kind = detect_image_type(data)
    if kind is None:
        raise HTTPException(415, "The file is not a real JPG or PNG image.")
    _, extension = kind

    if not classifier.loaded:
        raise HTTPException(503, "The grading model is not available right now. Please try again later.")

    # 3. preprocess (Pillow + OpenCV), then run the model (nothing is saved if this fails)
    try:
        batch = await run_in_threadpool(preprocess_image, data)
    except ImageProcessingError:
        raise HTTPException(422, "Could not read this image. Please choose another photo.") from None
    try:
        label, confidence = await run_in_threadpool(classifier.predict, batch)
    except ModelNotAvailable:
        raise HTTPException(503, "The grading model is not available right now. Please try again later.") from None
    except Exception:
        logger.exception("Prediction failed")
        raise HTTPException(500, "The grading model could not process this image.") from None

    # 3b. no copra in the photo -> fail, save nothing, and ask for another photo.
    #     (a) the model has a "Not Copra" output and chose it, or
    #     (b) the model is too unsure about every grade (REJECT_BELOW_CONFIDENCE in .env, 0 turns this off)
    if label == NOT_COPRA or confidence < settings.reject_below_confidence:
        raise HTTPException(
            422,
            "No copra detected in this photo. Please take a clear, close photo of the copra "
            "in good daylight, or choose another photo.",
        )

    # 4. save the photo, then sample + image + result in ONE transaction
    filename = uuid.uuid4().hex + extension  # random name: the client's file name is never used
    file_path = settings.images_dir / filename
    await run_in_threadpool(file_path.write_bytes, data)

    try:
        quality_class_id = await db.scalar(
            select(QualityClass.quality_class_id).where(QualityClass.class_name == label)
        )
        if quality_class_id is None:
            raise HTTPException(
                500, "Quality classes are not set up in the database. Run: python -m app.db_setup"
            )

        await db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": SAMPLE_CODE_LOCK})
        today = datetime.now(ZoneInfo(settings.app_timezone)).date()
        year = datetime.now(ZoneInfo("UTC")).year
        next_number = await db.scalar(
            text(
                "SELECT COALESCE(MAX(CAST(SUBSTRING(sample_code FROM 12) AS INTEGER)), 0) + 1 "
                "FROM kopragrade.copra_samples WHERE sample_code ~ :pattern"
            ),
            {"pattern": f"^COPRA-{year}-[0-9]+$"},
        )
        sample = CopraSample(user_id=user.id, sample_code=f"COPRA-{year}-{next_number:03d}", date_collected=today)
        db.add(sample)
        await db.flush()

        image_row = CopraImage(sample_id=sample.sample_id, image_path=f"uploaded_images/{filename}")
        db.add(image_row)
        await db.flush()

        result = ClassificationResult(
            image_id=image_row.image_id, quality_class_id=quality_class_id, confidence_score=confidence
        )
        db.add(result)
        await db.flush()
        result_id = result.result_id
        await db.commit()
    except Exception:
        await db.rollback()
        await run_in_threadpool(_remove_file, file_path)  # do not keep photos that have no database record
        raise

    grading = await find_grading_by_id(db, result_id)
    return {"grading": grading}
