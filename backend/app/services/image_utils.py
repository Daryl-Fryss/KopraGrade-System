"""Image checks and preprocessing (Pillow + OpenCV), done on the server."""
import io

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

MODEL_SIZE = 224  # MobileNetV2 input: 224 x 224 pixels

# Refuse absurdly large pictures (decompression-bomb protection). Pillow raises an error
# for images above twice this number of pixels.
Image.MAX_IMAGE_PIXELS = 40_000_000


class ImageProcessingError(Exception):
    """The bytes could not be read as a normal picture."""


def detect_image_type(data: bytes) -> tuple[str, str] | None:
    """Looks at the first bytes, so a renamed .txt file cannot pass as an image.

    Returns (mime type, file extension) or None.
    """
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg", ".jpg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png", ".png"
    return None


def preprocess_image(data: bytes) -> np.ndarray:
    """Image bytes -> float32 array of shape (1, 224, 224, 3), RGB, pixel values 0-255.

    Pillow opens the file, fixes the phone's rotation (EXIF) and converts to RGB.
    OpenCV resizes to 224 x 224. The values stay 0-255 on purpose: the model itself
    rescales them to -1..1 (see training/model_def.py), exactly as during training.
    """
    try:
        with Image.open(io.BytesIO(data)) as img:
            img.load()
            rgb = ImageOps.exif_transpose(img).convert("RGB")
            pixels = np.asarray(rgb, dtype=np.uint8)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise ImageProcessingError("Could not read this image.") from exc

    if pixels.ndim != 3 or pixels.shape[2] != 3 or pixels.shape[0] < 1 or pixels.shape[1] < 1:
        raise ImageProcessingError("Could not read this image.")

    # INTER_LINEAR is the same kind of resize that Keras uses while training.
    resized = cv2.resize(pixels, (MODEL_SIZE, MODEL_SIZE), interpolation=cv2.INTER_LINEAR)
    return np.expand_dims(resized.astype("float32"), axis=0)
