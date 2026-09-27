import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent

# backend/.env dosyasını, sunucu hangi klasörden başlatılırsa başlatılsın yükle
load_dotenv(BASE_DIR / ".env")


def _csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


# Varsayılan olarak veritabanı her zaman backend/ klasöründe oluşur
DATABASE_URL = os.getenv("DATABASE_URL") or f"sqlite:///{BASE_DIR / 'inventory.db'}"

# "Bugün"ün hesaplandığı saat dilimi (sunucu bulutta UTC'de çalışsa bile)
APP_TIMEZONE = os.getenv("APP_TIMEZONE", "Europe/Istanbul")

# Boş bırakılırsa kimlik doğrulama kapalıdır. Doluysa her /api isteği
# "X-API-Key" başlığında bu değeri göndermek zorundadır.
APP_API_KEY = os.getenv("APP_API_KEY", "")

CORS_ORIGINS = _csv(os.getenv("CORS_ORIGINS", "*"))

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
AI_TIMEOUT_SECONDS = float(os.getenv("AI_TIMEOUT_SECONDS", "45"))

# Yapay zekâ uç noktaları için IP başına dakikalık istek sınırı (0 = sınırsız)
AI_RATE_LIMIT_PER_MINUTE = int(os.getenv("AI_RATE_LIMIT_PER_MINUTE", "10"))

OPEN_FOOD_FACTS_ENABLED = os.getenv("OPEN_FOOD_FACTS_ENABLED", "1") != "0"
OPEN_FOOD_FACTS_TIMEOUT_SECONDS = float(os.getenv("OPEN_FOOD_FACTS_TIMEOUT_SECONDS", "6"))
