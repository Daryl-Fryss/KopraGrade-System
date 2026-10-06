"""Values shared by several files."""

ROLES = ("farmer", "buyer")

# The three drying-quality classes, best to worst.
# Must match the quality_classes table (database/seed.sql) and the training script.
GRADES = ("Well-Dried", "Moderately Dried", "Poorly Dried")

# Optional 4th model output for photos that do not show copra. It is NOT a grade: it is never
# saved, the farmer is simply asked to take another photo. Only used if the model was trained with it.
NOT_COPRA = "Not Copra"

# Advisory-lock id so two uploads at the same time never get the same sample code.
SAMPLE_CODE_LOCK = 7201
