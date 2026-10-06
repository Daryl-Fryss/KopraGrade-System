"""The model: MobileNetV2 with transfer learning. Shared by train_model.py and make_demo_model.py.

The picture goes in as raw pixels (0-255). Scaling to -1..1 happens INSIDE the model, so the
FastAPI server only has to resize the photo to 224 x 224 and send the pixels as they are.
"""
from pathlib import Path

import tensorflow as tf

IMG_SIZE = (224, 224)

# Fixed order, best to worst. Predictions are always mapped back to names with this list,
# never by folder sort order, so they always match the quality_classes table names.
CLASS_NAMES = ["Well-Dried", "Moderately Dried", "Poorly Dried"]

# Optional extra class for photos that are not copra. Used only if dataset/train/Not Copra exists.
NOT_COPRA = "Not Copra"

# train_model.py and make_demo_model.py save the trained model here, where the API looks for it.
MODEL_DIR = Path(__file__).resolve().parent.parent / "backend" / "model"
MODEL_FILE = MODEL_DIR / "kopragrade_model.keras"
CLASS_NAMES_FILE = MODEL_DIR / "class_names.json"


def build_model(pretrained: bool = True, num_classes: int = len(CLASS_NAMES)):
    """Returns (model, base). `base` is the MobileNetV2 part that is fine-tuned in phase 2."""
    base = tf.keras.applications.MobileNetV2(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights="imagenet" if pretrained else None,
    )
    base.trainable = False

    augment = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal_and_vertical"),
            tf.keras.layers.RandomRotation(0.1),
            tf.keras.layers.RandomZoom(0.1),
            tf.keras.layers.RandomBrightness(0.15),
            tf.keras.layers.RandomContrast(0.15),
        ],
        name="augment",
    )

    inputs = tf.keras.Input(shape=IMG_SIZE + (3,))             # raw pixels 0-255
    x = augment(inputs)                                        # only active while training
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1)(x)     # MobileNetV2 preprocessing
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    return tf.keras.Model(inputs, outputs), base
