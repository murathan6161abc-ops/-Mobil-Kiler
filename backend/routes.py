from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date
from database import get_db
import models
import schemas
from services.ai_service import get_recipe_suggestion

router = APIRouter()

@router.post("/inventory/", response_model=schemas.InventoryItemResponse)
def add_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    db_item = models.InventoryItem(**item.model_dump())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@router.get("/inventory/", response_model=list[schemas.InventoryItemResponse])
def get_inventory(db: Session = Depends(get_db)):
    return db.query(models.InventoryItem).all()

@router.get("/inventory/expiring/", response_model=list[schemas.InventoryItemResponse])
def get_expiring_items(days: int = 7, db: Session = Depends(get_db)):
    # Bu basit bir tarih filtresidir. İleride daha gelişmiş yapılabilir.
    # Şimdilik sadece tüm listeyi dönüyoruz, gelişmiş sorgu eklenecektir.
    items = db.query(models.InventoryItem).all()
    # Basit filtre: SKT'si 7 gün içinde dolacaklar (Bunu DB seviyesinde yapmak daha iyidir)
    return items

@router.post("/suggest-recipe/")
def suggest_recipe(request: schemas.RecipeRequest):
    suggestion = get_recipe_suggestion(request.available_ingredients)
    return {"recipe": suggestion}

@router.post("/chat/")
def chat_with_ai(request: dict):
    messages = request.get("messages", [])
    if not messages:
        return {"reply": "Merhaba! Size yemek ve mutfak hakkinda yardimci olabilirim."}

    from services.ai_service import chat_with_gemini
    reply = chat_with_gemini(messages)
    return {"reply": reply}

@router.delete("/inventory/{item_id}")
def delete_inventory_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(models.InventoryItem).filter(models.InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Urun bulunamadi")
    db.delete(item)
    db.commit()
    return {"message": "Urun silindi"}

@router.put("/inventory/{item_id}", response_model=schemas.InventoryItemResponse)
def update_inventory_item(item_id: int, updated: schemas.InventoryItemCreate, db: Session = Depends(get_db)):
    item = db.query(models.InventoryItem).filter(models.InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Urun bulunamadi")
    item.barcode = updated.barcode
    item.name = updated.name
    item.category = updated.category
    item.expiry_date = updated.expiry_date
    db.commit()
    db.refresh(item)
    return item
