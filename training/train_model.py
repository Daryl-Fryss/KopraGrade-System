"""Train the KopraGrade copra-drying classifier (3 classes) with transfer learning (MobileNetV2).

Dataset layout (folder names = class names), inside the training/ folder:
  dataset/train/Well-Dried/*.jpg       dataset/val/...      dataset/test/...
  dataset/train/Moderately Dried/*.jpg
  dataset/train/Poorly Dried/*.jpg
  dataset/train/Not Copra/*.jpg        (OPTIONAL: photos that are not copra; needs train, val and test)
Split by SAMPLE, not by photo: all photos of one copra sample must stay in the same split.

Run (from the training folder):   python train_model.py
Output (saved in backend/model/): kopragrade_model.keras  and  class_names.json

Options:  --epochs 15   --batch-size 16   --no-pretrained (quick test without downloading weights)
"""
import argparse
import json
import os
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix

from model_def import CLASS_NAMES as GRADE_NAMES
from model_def import CLASS_NAMES_FILE, IMG_SIZE, MODEL_DIR, MODEL_FILE, NOT_COPRA, build_model

DATA = Path(__file__).resolve().parent / "dataset"

# Optional 4th class: if a "Not Copra" folder exists in train, val AND test, the model also learns
# to recognise photos that are not copra (the API then answers "No copra detected").
CLASS_NAMES = list(GRADE_NAMES)
if all((DATA / split / NOT_COPRA).is_dir() for split in ("train", "val", "test")):
    CLASS_NAMES.append(NOT_COPRA)
    print(f"Found a '{NOT_COPRA}' folder: training with {len(CLASS_NAMES)} classes.")
else:
    print("No 'Not Copra' folder in train, val and test: training with the 3 grades only.")


def load(split: str, batch_size: int, shuffle: bool):
    folder = DATA / split
    if not folder.is_dir():
        raise SystemExit(f"Dataset folder not found: {folder}\nSee the instructions at the top of train_model.py.")
    ds = tf.keras.utils.image_dataset_from_directory(
        folder,
        class_names=CLASS_NAMES,
        image_size=IMG_SIZE,
        batch_size=batch_size,
        shuffle=shuffle,
        seed=42,
    )
    return ds.prefetch(tf.data.AUTOTUNE)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=15, help="epochs for each of the two phases")
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--no-pretrained", action="store_true", help="do not download ImageNet weights (tests only)")
    args = parser.parse_args()

    train_ds = load("train", args.batch_size, True)
    val_ds = load("val", args.batch_size, False)
    test_ds = load("test", args.batch_size, False)

    # Class weights help when one class has fewer photos than the others.
    counts = np.zeros(len(CLASS_NAMES))
    for _, labels in train_ds:
        for label in labels.numpy():
            counts[label] += 1
    weights = {i: float(counts.sum() / (len(CLASS_NAMES) * c)) for i, c in enumerate(counts) if c > 0}
    print("Photos per class in train:", {name: int(n) for name, n in zip(CLASS_NAMES, counts)})

    model, base = build_model(pretrained=not args.no_pretrained, num_classes=len(CLASS_NAMES))
    stop = tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=4, restore_best_weights=True)

    # Phase 1: train only the new top layers
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, class_weight=weights, callbacks=[stop])

    # Phase 2: fine-tune the last layers of MobileNetV2 with a small learning rate
    base.trainable = True
    for layer in base.layers[:-30]:
        layer.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, class_weight=weights, callbacks=[stop])

    # Final check on photos the model has never seen (scikit-learn)
    y_true, y_pred = [], []
    for images, labels in test_ds:
        y_true += labels.numpy().tolist()
        y_pred += np.argmax(model.predict(images, verbose=0), axis=1).tolist()
    label_ids = list(range(len(CLASS_NAMES)))
    print("\nConfusion matrix (rows = real, columns = predicted), order:", CLASS_NAMES)
    print(confusion_matrix(y_true, y_pred, labels=label_ids))
    print(classification_report(y_true, y_pred, labels=label_ids, target_names=CLASS_NAMES, zero_division=0))
    print("Well-Dried mistaken for Poorly Dried (or the reverse) is the worst kind of mistake - check those cells.")

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model.save(MODEL_FILE)
    CLASS_NAMES_FILE.write_text(json.dumps(CLASS_NAMES), encoding="utf-8")
    print(f"\nSaved {MODEL_FILE}\nSaved {CLASS_NAMES_FILE}\nRestart the API so it loads the new model.")


if __name__ == "__main__":
    main()
