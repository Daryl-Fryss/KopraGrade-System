"""Loads the trained Keras model (MobileNetV2 transfer learning) and runs predictions.

The model runs inside this same FastAPI application. If the model files do not exist yet,
the API still starts (login, history, ... work) but grading answers 503 until you train the
model (training/train_model.py) or create a demo model (training/make_demo_model.py).
"""
import json
import logging
import os
import threading
from pathlib import Path

import numpy as np

from ..constants import GRADES, NOT_COPRA

logger = logging.getLogger("kopragrade")


class ModelNotAvailable(Exception):
    """The trained model is not loaded."""


class CopraClassifier:
    def __init__(self, model_path: Path, class_names_path: Path) -> None:
        self.model_path = model_path
        self.class_names_path = class_names_path
        self.error: str | None = None
        self._model = None
        self._class_names: list[str] = []
        self._lock = threading.Lock()

    @property
    def loaded(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        """Never raises: on a problem it stores the reason in self.error and logs it."""
        self._model = None
        self.error = None
        if not self.model_path.is_file() or not self.class_names_path.is_file():
            self.error = (
                f"Model files not found ({self.model_path.name}, {self.class_names_path.name}). "
                "Train the model with training/train_model.py first."
            )
            logger.warning(self.error)
            return
        try:
            os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")  # quieter TensorFlow
            import tensorflow as tf  # imported here because it takes a few seconds

            names = json.loads(self.class_names_path.read_text(encoding="utf-8"))
            allowed = (sorted(GRADES), sorted([*GRADES, NOT_COPRA]))  # "Not Copra" is optional
            if not isinstance(names, list) or sorted(names) not in allowed:
                raise ValueError(
                    f"class_names.json must contain exactly these names: {list(GRADES)} "
                    f'(optionally plus "{NOT_COPRA}")'
                )

            model = tf.keras.models.load_model(self.model_path, compile=False)
            if int(model.output_shape[-1]) != len(names):
                raise ValueError("The model output size does not match class_names.json.")

            # warm-up run, so the first real request is not slow
            model(np.zeros((1, 224, 224, 3), dtype="float32"), training=False)

            self._class_names = names
            self._model = model
            logger.info("Model loaded from %s", self.model_path)
        except Exception as exc:  # noqa: BLE001 - any problem means "model not available"
            self.error = f"The model could not be loaded: {exc}"
            logger.exception("Model loading failed")

    def predict(self, batch: np.ndarray) -> tuple[str, float]:
        """batch: (1, 224, 224, 3) float32, values 0-255. Returns (class name, confidence 0-100)."""
        if self._model is None:
            raise ModelNotAvailable(self.error or "The model is not loaded.")
        with self._lock:  # one prediction at a time keeps TensorFlow simple and safe
            probabilities = np.asarray(self._model(batch, training=False))[0]
        if not np.all(np.isfinite(probabilities)):
            raise RuntimeError("The model returned an invalid result.")
        best = int(np.argmax(probabilities))
        confidence = round(float(probabilities[best]) * 100, 2)
        return self._class_names[best], min(max(confidence, 0.0), 100.0)
