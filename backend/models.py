from sqlalchemy import Column, Date, DateTime, Float, Integer, String, func

from database import Base


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String, index=True, nullable=False)
    name = Column(String, nullable=False)
    category = Column(String, nullable=True)
    expiry_date = Column(Date, nullable=False)
    # SKT: son tüketim tarihi (geçince tüketilmez)
    # TETT: tavsiye edilen tüketim tarihi (geçince kalite düşebilir, çoğu zaman tüketilebilir)
    date_type = Column(String, nullable=False, server_default="SKT")
    quantity = Column(Float, nullable=False, server_default="1")
    unit = Column(String, nullable=False, server_default="adet")
    location = Column(String, nullable=False, server_default="dolap")
    # active: dolapta | consumed: tüketildi | wasted: çöpe gitti
    status = Column(String, nullable=False, server_default="active", index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    closed_at = Column(DateTime(timezone=True), nullable=True)


class Product(Base):
    """
    Barkod -> ürün bilgisi kataloğu. Kullanıcıların eklediği ürünler burada
    saklanır; böylece aynı barkod bir daha okutulduğunda ad ve kategori
    otomatik dolar (topluluk katkılı yerli ürün veritabanı).
    """

    __tablename__ = "products"

    barcode = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    category = Column(String, nullable=True)
    brand = Column(String, nullable=True)
    # user: kullanıcı ekledi | openfoodfacts: Open Food Facts'ten geldi
    source = Column(String, nullable=False, server_default="user")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
