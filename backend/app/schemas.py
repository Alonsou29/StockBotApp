from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict


class ProductBase(BaseModel):
    name: str
    category: str


class ProductCreate(ProductBase):
    pass


class ProductResponse(ProductBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: Optional[datetime] = None


class DailyListItemBase(BaseModel):
    product_id: int
    hay: str = ""
    action: str = "NO"
    quantity_to_bring: Optional[str] = None


class DailyListItemCreate(DailyListItemBase):
    pass


class DailyListItemUpdate(BaseModel):
    hay: Optional[str] = None
    action: Optional[str] = None
    quantity_to_bring: Optional[str] = None


class DailyListItemResponse(DailyListItemBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    product: Optional[ProductResponse] = None


class DailyListBase(BaseModel):
    list_date: date
    notes: Optional[str] = None


class DailyListCreate(DailyListBase):
    items: List[DailyListItemCreate]


class DailyListUpdate(BaseModel):
    notes: Optional[str] = None
    items: List[DailyListItemCreate]


class DailyListResponse(DailyListBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    items: List[DailyListItemResponse] = []


class DailyListSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    list_date: date
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


# --------------------------
# Deudas de empleados
# --------------------------
class DebtEmployeeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    odoo_employee_id: int
    company_id: int
    company_name: Optional[str] = None
    name: str
    identification: Optional[str] = None
    job_title: Optional[str] = None
    active: bool
    synced_at: Optional[datetime] = None


class DebtItemCreate(BaseModel):
    odoo_product_id: int
    product_name: str
    product_code: Optional[str] = None
    unit_price: Decimal
    quantity: Decimal = Decimal("1")


class DebtItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    debt_id: int
    odoo_product_id: int
    product_name: str
    product_code: Optional[str] = None
    unit_price: Decimal
    quantity: Decimal
    subtotal: Decimal


class DebtCreate(BaseModel):
    odoo_employee_id: int
    company_id: int
    company_name: Optional[str] = None
    employee_name: str
    identification: Optional[str] = None
    job_title: Optional[str] = None
    debt_date: date
    notes: Optional[str] = None
    items: List[DebtItemCreate]


class DebtResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    employee_id: int
    company_id: int
    debt_date: date
    notes: Optional[str] = None
    total: Decimal
    created_at: Optional[datetime] = None
    employee: Optional[DebtEmployeeResponse] = None
    items: List[DebtItemResponse] = []


class DebtItemAdd(BaseModel):
    items: List[DebtItemCreate]


class DebtItemUpdateExisting(BaseModel):
    odoo_product_id: Optional[int] = None
    product_name: Optional[str] = None
    product_code: Optional[str] = None
    unit_price: Optional[Decimal] = None
    quantity: Optional[Decimal] = None


class DebtUpdate(BaseModel):
    debt_date: Optional[date] = None
    notes: Optional[str] = None
    items: Optional[List[DebtItemUpdateExisting]] = None


class DebtPaymentCreate(BaseModel):
    odoo_employee_id: int
    company_id: int
    company_name: Optional[str] = None
    employee_name: str
    identification: Optional[str] = None
    job_title: Optional[str] = None
    amount: Decimal
    payment_date: date
    notes: Optional[str] = None


class DebtPaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    employee_id: int
    company_id: int
    amount: Decimal
    payment_date: date
    notes: Optional[str] = None
    created_at: Optional[datetime] = None


class DebtorSummary(BaseModel):
    employee: DebtEmployeeResponse
    total_charged: Decimal
    total_paid: Decimal
    balance: Decimal


class EmployeeAccount(BaseModel):
    employee: DebtEmployeeResponse
    balance: Decimal
    total_charged: Decimal
    total_paid: Decimal
    debts: List[DebtResponse] = []
    payments: List[DebtPaymentResponse] = []
