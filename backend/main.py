import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

import config
from database import init_db
from routes import router
from services.ai_service import AIServiceError

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Veritabanı tablolarını oluştur / eksik kolonları ekle
    init_db()
    yield


app = FastAPI(title="Mobil Kiler API", version="2.0.0", lifespan=lifespan)

# Mobil uygulama CORS'a takılmaz; bu ayar yalnızca tarayıcıdan (Flutter web) erişim içindir.
# Kimlik bilgisi (cookie) kullanılmadığı için allow_credentials kapalı.
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "X-API-Key"],
)


@app.exception_handler(AIServiceError)
async def ai_service_error_handler(request: Request, exc: AIServiceError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})


app.include_router(router, prefix="/api")


@app.get("/")
def read_root():
    return {"message": "Sistem aktif."}
