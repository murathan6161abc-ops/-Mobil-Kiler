import logging
from typing import Optional

import requests

import config

logger = logging.getLogger(__name__)

OPEN_FOOD_FACTS_URL = "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
USER_AGENT = "MobilKiler/2.0 (Teknofest projesi; https://github.com/murathan6161abc-ops/-Mobil-Kiler)"

# Open Food Facts kategori etiketi -> uygulamadaki kategori
# Liste sırası önemlidir: ilk eşleşen kategori seçilir.
CATEGORY_MAP = [
    ("en:frozen-foods", "Dondurulmuş"),
    ("en:dairies", "Süt Ürünleri"),
    ("en:cheeses", "Süt Ürünleri"),
    ("en:yogurts", "Süt Ürünleri"),
    ("en:milks", "Süt Ürünleri"),
    ("en:eggs", "Kahvaltılık"),
    ("en:breakfasts", "Kahvaltılık"),
    ("en:spreads", "Kahvaltılık"),
    ("en:fishes", "Balık"),
    ("en:seafood", "Balık"),
    ("en:meats", "Et & Tavuk"),
    ("en:poultries", "Et & Tavuk"),
    ("en:canned-foods", "Konserve"),
    ("en:vegetables", "Sebze"),
    ("en:fruits", "Meyve"),
    ("en:breads", "Fırın"),
    ("en:biscuits-and-cakes", "Atıştırmalık"),
    ("en:legumes", "Bakliyat & Tahıl"),
    ("en:pastas", "Bakliyat & Tahıl"),
    ("en:rices", "Bakliyat & Tahıl"),
    ("en:cereals-and-potatoes", "Bakliyat & Tahıl"),
    ("en:beverages", "İçecek"),
    ("en:snacks", "Atıştırmalık"),
    ("en:condiments", "Sos & Baharat"),
    ("en:sauces", "Sos & Baharat"),
    ("en:spices", "Sos & Baharat"),
]


def map_category(tags: list[str]) -> Optional[str]:
    tag_set = set(tags or [])
    for tag, category in CATEGORY_MAP:
        if tag in tag_set:
            return category
    return None


def is_ean_like(barcode: str) -> bool:
    """Open Food Facts sadece EAN/UPC gibi sayısal barkodları tanır (QR kodları değil)."""
    return barcode.isdigit() and 6 <= len(barcode) <= 14


def lookup_open_food_facts(barcode: str) -> Optional[dict]:
    """Barkodu Open Food Facts'te arar. Bulamazsa ya da ulaşamazsa None döner."""
    if not config.OPEN_FOOD_FACTS_ENABLED or not is_ean_like(barcode):
        return None
    try:
        response = requests.get(
            OPEN_FOOD_FACTS_URL.format(barcode=barcode),
            params={"fields": "product_name,product_name_tr,brands,categories_tags"},
            headers={"User-Agent": USER_AGENT},
            timeout=config.OPEN_FOOD_FACTS_TIMEOUT_SECONDS,
        )
    except requests.RequestException:
        logger.warning("Open Food Facts'e ulaşılamadı (barkod %s)", barcode)
        return None

    if response.status_code != 200:
        return None
    try:
        data = response.json()
    except ValueError:
        return None
    if data.get("status") != 1:
        return None

    product = data.get("product") or {}
    name = (product.get("product_name_tr") or product.get("product_name") or "").strip()
    if not name:
        return None
    brand = (product.get("brands") or "").split(",")[0].strip() or None
    return {
        "name": name[:120],
        "brand": brand[:120] if brand else None,
        "category": map_category(product.get("categories_tags") or []),
    }
