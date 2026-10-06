-- KopraGrade database schema (PostgreSQL 16 / 18)
-- Schema name: kopragrade
-- Tables: users, copra_samples, copra_images, quality_classes, classification_results
-- (There is NO recommendations table. The recommendation text is created by the
--  FastAPI code from the grade, so nothing about it is stored in the database.)

CREATE SCHEMA IF NOT EXISTS kopragrade;

-- Users: farmers and buyers only (no admin).
CREATE TABLE IF NOT EXISTS kopragrade.users (
    user_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username  VARCHAR(50)  NOT NULL UNIQUE,
    password  VARCHAR(255) NOT NULL,              -- stores a bcrypt hash, never plain text
    name      VARCHAR(100) NOT NULL,
    email     VARCHAR(255) NOT NULL UNIQUE,       -- used to log in
    role      VARCHAR(10)  NOT NULL
              CONSTRAINT chk_users_role CHECK (role IN ('farmer', 'buyer')),
    contact   VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS kopragrade.copra_samples (
    sample_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        INTEGER NOT NULL REFERENCES kopragrade.users(user_id),
    sample_code    VARCHAR(30) NOT NULL UNIQUE,
    date_collected DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS kopragrade.copra_images (
    image_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sample_id  INTEGER NOT NULL REFERENCES kopragrade.copra_samples(sample_id),
    image_path VARCHAR(255) NOT NULL              -- example: uploaded_images/3f2a....jpg
);

-- The three drying-quality classes.
CREATE TABLE IF NOT EXISTS kopragrade.quality_classes (
    quality_class_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_name       VARCHAR(50) NOT NULL UNIQUE
                     CONSTRAINT chk_class_name
                     CHECK (class_name IN ('Well-Dried', 'Moderately Dried', 'Poorly Dried')),
    description      TEXT
);

CREATE TABLE IF NOT EXISTS kopragrade.classification_results (
    result_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    image_id         INTEGER NOT NULL REFERENCES kopragrade.copra_images(image_id),
    quality_class_id INTEGER NOT NULL REFERENCES kopragrade.quality_classes(quality_class_id),
    confidence_score NUMERIC(5,2) NOT NULL
                     CONSTRAINT chk_confidence_range CHECK (confidence_score BETWEEN 0 AND 100),
    classified_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP   -- always saved in UTC by the API
);

CREATE INDEX IF NOT EXISTS idx_samples_user  ON kopragrade.copra_samples(user_id);
CREATE INDEX IF NOT EXISTS idx_images_sample ON kopragrade.copra_images(sample_id);
CREATE INDEX IF NOT EXISTS idx_results_image ON kopragrade.classification_results(image_id);
CREATE INDEX IF NOT EXISTS idx_results_class ON kopragrade.classification_results(quality_class_id);
CREATE INDEX IF NOT EXISTS idx_results_time  ON kopragrade.classification_results(classified_at DESC);

-- Clean-up: the earlier version of this project had a "recommendations" table.
-- It is removed on purpose. This line does nothing if the table never existed.
DROP TABLE IF EXISTS kopragrade.recommendations;
