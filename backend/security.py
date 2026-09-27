import secrets
import threading
import time
from collections import defaultdict, deque
from typing import Optional

from fastapi import Header, HTTPException, Request

import config


def verify_api_key(x_api_key: Optional[str] = Header(default=None)):
    """APP_API_KEY tanımlıysa, isteklerin X-API-Key başlığında aynı değeri göndermesini zorunlu kılar."""
    expected = config.APP_API_KEY
    if not expected:
        return
    if not x_api_key or not secrets.compare_digest(x_api_key, expected):
        raise HTTPException(status_code=401, detail="Geçersiz ya da eksik API anahtarı.")


class RateLimiter:
    """Basit bellek içi kayan pencere sınırlayıcı (tek sunucu süreci için yeterli)."""

    def __init__(self, window_seconds: float = 60.0):
        self.window_seconds = window_seconds
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = threading.Lock()

    def reset(self):
        with self._lock:
            self._hits.clear()

    def check(self, key: str, limit: int):
        if limit <= 0:
            return
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > self.window_seconds:
                hits.popleft()
            if len(hits) >= limit:
                raise HTTPException(
                    status_code=429,
                    detail="Çok fazla yapay zekâ isteği gönderildi. Lütfen bir dakika sonra tekrar deneyin.",
                )
            hits.append(now)


ai_rate_limiter = RateLimiter()


def limit_ai_requests(request: Request):
    client = request.client.host if request.client else "unknown"
    ai_rate_limiter.check(client, config.AI_RATE_LIMIT_PER_MINUTE)
