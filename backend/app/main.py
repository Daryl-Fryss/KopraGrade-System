"""KopraGrade REST API (FastAPI). One Python application: API + image processing + ML model.

Run from the backend folder:   uvicorn app.main:app --reload
"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from .config import settings
from .database import engine
from .errors import install_error_handlers
from .routers import auth, classification, gradings, history, users
from .services.classifier import CopraClassifier

logging.basicConfig(level=logging.INFO, format="%(levelname)s:     %(name)s: %(message)s")
logger = logging.getLogger("kopragrade")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. PostgreSQL must be reachable
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as exc:
        logger.error("Cannot connect to PostgreSQL: %s", exc)
        logger.error("Check DATABASE_URL in backend/.env and run: python -m app.db_setup")
        raise

    # 2. load the trained model once (the API still starts if the model files are missing)
    classifier = CopraClassifier(settings.model_path, settings.class_names_path)
    await asyncio.to_thread(classifier.load)
    app.state.classifier = classifier

    logger.info("KopraGrade API is ready. Images folder: %s", settings.images_dir)
    yield
    await engine.dispose()


app = FastAPI(
    title="KopraGrade API",
    version="1.0.0",
    description="Copra drying-quality grading: JWT login, farmer/buyer roles, MobileNetV2 classification.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)
install_error_handlers(app)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(classification.router)
app.include_router(gradings.router)
app.include_router(history.router)


@app.get("/api/health", tags=["health"])
async def health(request: Request):
    classifier: CopraClassifier = request.app.state.classifier
    return {"status": "ok", "model_loaded": classifier.loaded, "model_problem": classifier.error}


# Uploaded copra photos (random file names, so the addresses cannot be guessed).
app.mount("/images", StaticFiles(directory=str(settings.images_dir)), name="images")
