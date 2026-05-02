from sqlalchemy import Column, Integer, String, Date, DateTime, func
from database import Base

class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String, index=True, nullable=False)
    name = Column(String, nullable=False)
    category = Column(String, nullable=True)
    expiry_date = Column(Date, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
