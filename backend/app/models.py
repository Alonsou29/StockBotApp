import datetime
from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, index=True)
    category = Column(String(20), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    items = relationship("DailyListItem", back_populates="product", lazy="selectin")


class DailyList(Base):
    __tablename__ = "daily_lists"

    id = Column(Integer, primary_key=True, index=True)
    list_date = Column(Date, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    __table_args__ = (UniqueConstraint("list_date", name="uq_daily_list_date"),)

    items = relationship("DailyListItem", back_populates="daily_list", lazy="selectin", cascade="all, delete-orphan")


class DailyListItem(Base):
    __tablename__ = "daily_list_items"

    id = Column(Integer, primary_key=True, index=True)
    daily_list_id = Column(Integer, ForeignKey("daily_lists.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    hay = Column(String(50), nullable=False, default="")
    action = Column(String(20), nullable=False, default="NO")
    quantity_to_bring = Column(String(50), nullable=True, default=None)

    daily_list = relationship("DailyList", back_populates="items")
    product = relationship("Product", back_populates="items")
