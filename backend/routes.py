from datetime import date, datetime, time, timedelta, timezone
from typing import Literal, Optional
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

import config
import models
import schemas
from database import get_db
from security import limit_ai_requests, verify_api_key
from services import ai_service, product_service

router = APIRouter(dependencies=[Depends(verify_api_key)])

EXPIRING_SOON_DAYS = 3


def today() -> date:
    return datetime.now(ZoneInfo(config.APP_TIMEZONE)).date()


def _get_item_or_404(db: Session, item_id: int) -> models.InventoryItem:
    item = db.get(models.InventoryItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı")
    return item


def _remember_product(db: Session, barcode: str, name: str, category: Optional[str]):
    """Kullanıcının girdiği barkod-ürün eşleşmesini kataloğa kaydeder."""
    if not barcode:
        return
    product = db.get(models.Product, barcode)
    if product is None:
        db.add(models.Product(barcode=barcode, name=name, category=category, source="user"))
    else:
        product.name = name
        if category:
            product.category = category
        product.source = "user"


def _pantry_for_ai(db: Session, limit: int = 40) -> list[ai_service.PantryItem]:
    """
    Yapay zekâya gönderilecek malzemeler: dolaptaki ürünler, SKT'si en yakın olan önce.
    SKT'si geçmiş ürünler gıda güvenliği nedeniyle asla gönderilmez.
    """
    current = today()
    rows = (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.status == "active")
        .order_by(models.InventoryItem.expiry_date, models.InventoryItem.id)
        .all()
    )
    pantry: list[ai_service.PantryItem] = []
    seen: set[str] = set()
    for row in rows:
        days_left = (row.expiry_date - current).days
        if days_left < 0 and row.date_type != "TETT":
            continue
        key = row.name.casefold()
        if key in seen:
            continue
        seen.add(key)
        pantry.append(ai_service.PantryItem(name=row.name, days_left=days_left, date_type=row.date_type))
        if len(pantry) >= limit:
            break
    return pantry


@router.get("/health")
def health():
    return {"status": "ok", "ai_configured": bool(config.GEMINI_API_KEY), "today": today().isoformat()}


# ---------------------------------------------------------------- Envanter


@router.get("/inventory/", response_model=list[schemas.InventoryItemResponse])
def get_inventory(
    status: Literal["active", "consumed", "wasted", "all"] = "active",
    db: Session = Depends(get_db),
):
    query = db.query(models.InventoryItem)
    if status != "all":
        query = query.filter(models.InventoryItem.status == status)
    return query.order_by(models.InventoryItem.expiry_date, models.InventoryItem.id).all()


@router.post("/inventory/", response_model=schemas.InventoryItemResponse, status_code=201)
def add_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    db_item = models.InventoryItem(**item.model_dump(), status="active")
    db.add(db_item)
    _remember_product(db, item.barcode, item.name, item.category)
    db.commit()
    db.refresh(db_item)
    return db_item


@router.get("/inventory/expiring/", response_model=list[schemas.InventoryItemResponse])
def get_expiring_items(days: int = Query(default=7, ge=0, le=365), db: Session = Depends(get_db)):
    """Dolaptaki, önümüzdeki `days` gün içinde süresi dolacak (ya da dolmuş) ürünler."""
    last_day = today() + timedelta(days=days)
    return (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.status == "active", models.InventoryItem.expiry_date <= last_day)
        .order_by(models.InventoryItem.expiry_date, models.InventoryItem.id)
        .all()
    )


@router.get("/inventory/{item_id}", response_model=schemas.InventoryItemResponse)
def get_inventory_item(item_id: int, db: Session = Depends(get_db)):
    return _get_item_or_404(db, item_id)


@router.put("/inventory/{item_id}", response_model=schemas.InventoryItemResponse)
@router.patch("/inventory/{item_id}", response_model=schemas.InventoryItemResponse)
def update_inventory_item(item_id: int, updated: schemas.InventoryItemUpdate, db: Session = Depends(get_db)):
    item = _get_item_or_404(db, item_id)
    changes = updated.model_dump(exclude_unset=True)
    for field, value in changes.items():
        # Kategori bilerek boşaltılabilir; zorunlu alanlara None yazılamaz
        if value is None and field != "category":
            continue
        setattr(item, field, value)
    if "barcode" in changes or "name" in changes or "category" in changes:
        _remember_product(db, item.barcode, item.name, item.category)
    db.commit()
    db.refresh(item)
    return item


@router.post("/inventory/{item_id}/close", response_model=schemas.InventoryItemResponse)
def close_inventory_item(item_id: int, request: schemas.CloseItemRequest, db: Session = Depends(get_db)):
    """Ürünü dolaptan çıkarır: tüketildi (consumed) ya da çöpe gitti (wasted)."""
    item = _get_item_or_404(db, item_id)
    if item.status != "active":
        raise HTTPException(status_code=409, detail="Bu ürün zaten dolaptan çıkarılmış.")
    item.status = request.outcome
    item.closed_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/inventory/{item_id}")
def delete_inventory_item(item_id: int, db: Session = Depends(get_db)):
    item = _get_item_or_404(db, item_id)
    db.delete(item)
    db.commit()
    return {"message": "Ürün silindi"}


# ---------------------------------------------------------------- İstatistik


@router.get("/stats", response_model=schemas.StatsResponse)
def get_stats(db: Session = Depends(get_db)):
    current = today()
    item = models.InventoryItem
    active = db.query(item).filter(item.status == "active")

    def count_status(status: str, since: Optional[datetime] = None) -> int:
        query = db.query(func.count(item.id)).filter(item.status == status)
        if since is not None:
            query = query.filter(item.closed_at >= since)
        return query.scalar() or 0

    month_start = datetime.combine(current.replace(day=1), time.min, tzinfo=ZoneInfo(config.APP_TIMEZONE))
    month_start_utc = month_start.astimezone(timezone.utc)

    consumed = count_status("consumed")
    wasted = count_status("wasted")
    closed = consumed + wasted

    wasted_categories = (
        db.query(func.coalesce(item.category, "Kategorisiz"), func.count(item.id))
        .filter(item.status == "wasted")
        .group_by(func.coalesce(item.category, "Kategorisiz"))
        .order_by(func.count(item.id).desc())
        .limit(5)
        .all()
    )

    return schemas.StatsResponse(
        active_count=active.count(),
        expiring_soon_count=active.filter(
            item.expiry_date >= current,
            item.expiry_date <= current + timedelta(days=EXPIRING_SOON_DAYS),
        ).count(),
        # TETT'i geçmiş ürünler "süresi dolmuş" sayılmaz (kontrol edilerek tüketilebilir)
        expired_count=active.filter(item.expiry_date < current, item.date_type != "TETT").count(),
        consumed_count=consumed,
        wasted_count=wasted,
        consumed_this_month=count_status("consumed", month_start_utc),
        wasted_this_month=count_status("wasted", month_start_utc),
        saved_rate=round(consumed / closed, 3) if closed else None,
        most_wasted_categories=[
            schemas.CategoryCount(category=category, count=count) for category, count in wasted_categories
        ],
    )


# ---------------------------------------------------------------- Ürün kataloğu


@router.get("/products/lookup", response_model=schemas.ProductResponse)
def lookup_product(barcode: str = Query(min_length=1, max_length=64), db: Session = Depends(get_db)):
    """
    Barkoda ait ürün bilgisini döner: önce kendi kataloğumuza, bulunamazsa
    Open Food Facts'e bakar ve bulduğunu kataloğa kaydeder.
    """
    barcode = barcode.strip()
    product = db.get(models.Product, barcode)
    if product:
        return product

    found = product_service.lookup_open_food_facts(barcode)
    if not found:
        raise HTTPException(status_code=404, detail="Bu barkod için ürün bilgisi bulunamadı.")
    product = models.Product(barcode=barcode, source="openfoodfacts", **found)
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


# ---------------------------------------------------------------- Yapay zekâ


@router.post(
    "/suggest-recipe/",
    response_model=schemas.RecipeResponse,
    dependencies=[Depends(limit_ai_requests)],
)
def suggest_recipe(request: schemas.RecipeRequest, db: Session = Depends(get_db)):
    if request.available_ingredients is not None:
        names = list(dict.fromkeys(name.strip() for name in request.available_ingredients if name.strip()))
        pantry = [ai_service.PantryItem(name=name) for name in names]
    else:
        pantry = _pantry_for_ai(db)
    recipe = ai_service.get_recipe_suggestion(pantry)
    return {"recipe": recipe, "used_items": [entry.name for entry in pantry]}


@router.post("/chat/", response_model=schemas.ChatResponse, dependencies=[Depends(limit_ai_requests)])
def chat_with_ai(request: schemas.ChatRequest, db: Session = Depends(get_db)):
    pantry = _pantry_for_ai(db) if request.include_inventory else None
    reply = ai_service.chat([message.model_dump() for message in request.messages], pantry)
    return {"reply": reply}
