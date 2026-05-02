from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional

class InventoryItemBase(BaseModel):
    barcode: str
    name: str
    category: Optional[str] = None
    expiry_date: date

class InventoryItemCreate(InventoryItemBase):
    pass

class InventoryItemResponse(InventoryItemBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

class RecipeRequest(BaseModel):
    available_ingredients: list[str]
