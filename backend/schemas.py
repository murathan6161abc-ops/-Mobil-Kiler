from datetime import date, datetime
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

DateType = Literal["SKT", "TETT"]
Unit = Literal["adet", "kg", "g", "L", "ml", "paket"]
Location = Literal["dolap", "buzdolabi", "dondurucu"]
Status = Literal["active", "consumed", "wasted"]

MIN_EXPIRY = date(2000, 1, 1)
MAX_EXPIRY = date(2100, 12, 31)


def _check_expiry(value: Optional[date]) -> Optional[date]:
    if value is not None and not (MIN_EXPIRY <= value <= MAX_EXPIRY):
        raise ValueError("Son kullanma tarihi 2000 ile 2100 arasında olmalı")
    return value


class InventoryItemCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    barcode: str = Field(default="", max_length=64)
    name: str = Field(min_length=1, max_length=120)
    category: Optional[str] = Field(default=None, max_length=60)
    expiry_date: date
    date_type: DateType = "SKT"
    quantity: float = Field(default=1, gt=0, le=10000)
    unit: Unit = "adet"
    location: Location = "dolap"

    _validate_expiry = field_validator("expiry_date")(_check_expiry)


class InventoryItemUpdate(BaseModel):
    """Sadece gönderilen alanlar güncellenir (gönderilmeyen kategori vb. silinmez)."""

    model_config = ConfigDict(str_strip_whitespace=True)

    barcode: Optional[str] = Field(default=None, max_length=64)
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    category: Optional[str] = Field(default=None, max_length=60)
    expiry_date: Optional[date] = None
    date_type: Optional[DateType] = None
    quantity: Optional[float] = Field(default=None, gt=0, le=10000)
    unit: Optional[Unit] = None
    location: Optional[Location] = None

    _validate_expiry = field_validator("expiry_date")(_check_expiry)


class InventoryItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    barcode: str
    name: str
    category: Optional[str] = None
    expiry_date: date
    date_type: str = "SKT"
    quantity: float = 1
    unit: str = "adet"
    location: str = "dolap"
    status: str = "active"
    created_at: Optional[datetime] = None
    closed_at: Optional[datetime] = None


class CloseItemRequest(BaseModel):
    outcome: Literal["consumed", "wasted"]


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    barcode: str
    name: str
    category: Optional[str] = None
    brand: Optional[str] = None
    source: str


class CategoryCount(BaseModel):
    category: str
    count: int


class StatsResponse(BaseModel):
    active_count: int
    expiring_soon_count: int
    expired_count: int
    consumed_count: int
    wasted_count: int
    consumed_this_month: int
    wasted_this_month: int
    # Kapatılan ürünlerin yüzde kaçı tüketildi (hiç kapatılan yoksa None)
    saved_rate: Optional[float] = None
    most_wasted_categories: list[CategoryCount] = []


class RecipeRequest(BaseModel):
    # Boş bırakılırsa sunucu, dolaptaki (süresi geçmemiş) ürünleri
    # SKT'si en yakın olandan başlayarak kendisi kullanır.
    available_ingredients: Optional[list[Annotated[str, Field(max_length=120)]]] = Field(
        default=None, max_length=100
    )


class RecipeResponse(BaseModel):
    recipe: str
    used_items: list[str]


class ChatMessage(BaseModel):
    role: Literal["user", "model"]
    text: str = Field(min_length=1, max_length=8000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=200)
    # True ise asistan, dolaptaki ürünleri bilerek yanıt verir
    include_inventory: bool = True


class ChatResponse(BaseModel):
    reply: str
