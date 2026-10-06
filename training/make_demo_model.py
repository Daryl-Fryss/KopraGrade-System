"""Creates an UNTRAINED demo model so you can test the whole app before you have a dataset.

  *** THE RESULTS OF THIS MODEL ARE NOT REAL. It has never seen copra photos. ***
  Its answers are close to random with a low confidence (so they show up as "needs review").
  Replace it by running train_model.py with your real dataset.

Run (from the training folder):   python make_demo_model.py
Option: --no-pretrained  (skip downloading the ImageNet weights)
"""
import argparse
import json
import os

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

from model_def import CLASS_NAMES, CLASS_NAMES_FILE, MODEL_DIR, MODEL_FILE, build_model


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-pretrained", action="store_true")
    args = parser.parse_args()

    model, _ = build_model(pretrained=not args.no_pretrained)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model.save(MODEL_FILE)
    CLASS_NAMES_FILE.write_text(json.dumps(CLASS_NAMES), encoding="utf-8")
    print(f"Saved {MODEL_FILE}\nSaved {CLASS_NAMES_FILE}")
    print("\n*** DEMO MODEL: NOT TRAINED. Do not present its results as real. ***")


if __name__ == "__main__":
    main()
