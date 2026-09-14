import datetime
from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey, Text, UniqueConstraint, Numeric, Boolean
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


class DebtEmployee(Base):
    __tablename__ = "debt_employees"

    id = Column(Integer, primary_key=True, index=True)
    odoo_employee_id = Column(Integer, nullable=False, index=True)
    company_id = Column(Integer, nullable=False, index=True)
    company_name = Column(String(200), nullable=True)
    name = Column(String(200), nullable=False, index=True)
    identification = Column(String(50), nullable=True)
    job_title = Column(String(200), nullable=True)
    active = Column(Boolean, nullable=False, default=True)
    synced_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    __table_args__ = (UniqueConstraint("odoo_employee_id", "company_id", name="uq_debt_employee_company"),)

    debts = relationship("Debt", back_populates="employee", lazy="selectin")
    payments = relationship("DebtPayment", back_populates="employee", lazy="selectin")


class Debt(Base):
    __tablename__ = "debts"

    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("debt_employees.id", ondelete="CASCADE"), nullable=False, index=True)
    company_id = Column(Integer, nullable=False, index=True)
    debt_date = Column(Date, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    total = Column(Numeric(12, 2), nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    employee = relationship("DebtEmployee", back_populates="debts")
    items = relationship("DebtItem", back_populates="debt", lazy="selectin", cascade="all, delete-orphan")


class DebtItem(Base):
    __tablename__ = "debt_items"

    id = Column(Integer, primary_key=True, index=True)
    debt_id = Column(Integer, ForeignKey("debts.id", ondelete="CASCADE"), nullable=False, index=True)
    odoo_product_id = Column(Integer, nullable=False, index=True)
    product_name = Column(String(200), nullable=False)
    product_code = Column(String(100), nullable=True)
    unit_price = Column(Numeric(12, 2), nullable=False, default=0)
    quantity = Column(Numeric(12, 3), nullable=False, default=1)
    subtotal = Column(Numeric(12, 2), nullable=False, default=0)

    debt = relationship("Debt", back_populates="items")


class DebtPayment(Base):
    __tablename__ = "debt_payments"

    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(Integer, ForeignKey("debt_employees.id", ondelete="CASCADE"), nullable=False, index=True)
    company_id = Column(Integer, nullable=False, index=True)
    amount = Column(Numeric(12, 2), nullable=False)
    payment_date = Column(Date, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    employee = relationship("DebtEmployee", back_populates="payments")
