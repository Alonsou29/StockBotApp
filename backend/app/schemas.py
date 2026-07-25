from datetime import date, datetime
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
