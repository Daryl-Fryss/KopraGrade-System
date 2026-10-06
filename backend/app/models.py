"""SQLAlchemy models. They match database/schema.sql (schema "kopragrade")."""
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Identity, Integer, MetaData, Numeric, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    metadata = MetaData(schema="kopragrade")


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True)
    password: Mapped[str] = mapped_column(String(255))  # bcrypt hash
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True)
    role: Mapped[str] = mapped_column(String(10))
    contact: Mapped[str | None] = mapped_column(String(50), nullable=True)


class CopraSample(Base):
    __tablename__ = "copra_samples"

    sample_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("kopragrade.users.user_id"))
    sample_code: Mapped[str] = mapped_column(String(30), unique=True)
    date_collected: Mapped[date] = mapped_column(Date, server_default=func.current_date())


class CopraImage(Base):
    __tablename__ = "copra_images"

    image_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    sample_id: Mapped[int] = mapped_column(ForeignKey("kopragrade.copra_samples.sample_id"))
    image_path: Mapped[str] = mapped_column(String(255))


class QualityClass(Base):
    __tablename__ = "quality_classes"

    quality_class_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    class_name: Mapped[str] = mapped_column(String(50), unique=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)


class ClassificationResult(Base):
    __tablename__ = "classification_results"

    result_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    image_id: Mapped[int] = mapped_column(ForeignKey("kopragrade.copra_images.image_id"))
    quality_class_id: Mapped[int] = mapped_column(ForeignKey("kopragrade.quality_classes.quality_class_id"))
    confidence_score: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    classified_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.current_timestamp())
