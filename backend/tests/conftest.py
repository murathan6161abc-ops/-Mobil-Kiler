import os
import tempfile
from datetime import date
from pathlib import Path
from unittest import mock

import pytest

# Ortam değişkenleri, uygulama modülleri içe aktarılmadan ÖNCE ayarlanmalı
_tmp_dir = tempfile.mkdtemp(prefix="mobil-kiler-test-")
os.environ["DATABASE_URL"] = f"sqlite:///{Path(_tmp_dir) / 'test.db'}"
os.environ["GEMINI_API_KEY"] = ""
os.environ["APP_API_KEY"] = ""
os.environ["OPEN_FOOD_FACTS_ENABLED"] = "0"

import config  # noqa: E402
import database  # noqa: E402
import routes  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from main import app  # noqa: E402
from security import ai_rate_limiter  # noqa: E402
from services import ai_service, product_service  # noqa: E402

TODAY = date(2026, 9, 27)


@pytest.fixture(autouse=True)
def clean_state(monkeypatch):
    database.Base.metadata.drop_all(bind=database.engine)
    database.init_db()
    ai_rate_limiter.reset()
    monkeypatch.setattr(config, "APP_API_KEY", "")
    monkeypatch.setattr(config, "GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(config, "OPEN_FOOD_FACTS_ENABLED", True)
    monkeypatch.setattr(routes, "today", lambda: TODAY)
    yield


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def gemini_response(text="## Menemen\nHazır!", status_code=200, payload=None):
    response = mock.Mock(status_code=status_code, text=str(payload or text))
    if payload is None:
        payload = {"candidates": [{"content": {"parts": [{"text": text}]}}]}
    response.json.return_value = payload
    return response


@pytest.fixture
def gemini(monkeypatch):
    """Gemini'ye giden istekleri yakalar; dönüş değeri gemini.return_value ile değiştirilebilir."""
    fake = mock.Mock(return_value=gemini_response())
    monkeypatch.setattr(ai_service.requests, "post", fake)
    return fake


@pytest.fixture
def off(monkeypatch):
    """Open Food Facts isteklerini yakalar."""
    fake = mock.Mock()
    monkeypatch.setattr(product_service.requests, "get", fake)
    return fake


def add_item(client, name="Süt", days=5, **extra):
    from datetime import timedelta

    body = {"barcode": extra.pop("barcode", ""), "name": name, "expiry_date": (TODAY + timedelta(days=days)).isoformat()}
    body.update(extra)
    response = client.post("/api/inventory/", json=body)
    assert response.status_code == 201, response.text
    return response.json()
