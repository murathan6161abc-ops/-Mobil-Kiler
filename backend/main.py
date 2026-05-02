from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
import models
from routes import router

# Veritabanı tablolarını oluştur
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Gıda Envanteri ve AI Tarif Sistemi")

# CORS (Tarayıcı üzerinden erişim) İzinleri
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tüm portlardan gelen isteklere izin ver (Chrome testi için gerekli)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")

@app.get("/")
def read_root():
    return {"message": "Sistem aktif."}
