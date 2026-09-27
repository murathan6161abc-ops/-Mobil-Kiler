import config
from tests.conftest import add_item


def test_api_key_required_when_configured(client, monkeypatch):
    monkeypatch.setattr(config, "APP_API_KEY", "gizli")
    assert client.get("/api/inventory/").status_code == 401
    assert client.get("/api/inventory/", headers={"X-API-Key": "yanlis"}).status_code == 401
    assert client.get("/api/inventory/", headers={"X-API-Key": "gizli"}).status_code == 200
    assert client.get("/api/health", headers={"X-API-Key": "gizli"}).json()["status"] == "ok"
    # Kök adres sağlık kontrolü için açık kalır
    assert client.get("/").status_code == 200


def test_no_api_key_needed_by_default(client):
    add_item(client, "Süt")
    assert client.get("/api/inventory/").status_code == 200


def test_cors_does_not_allow_credentials(client):
    response = client.options(
        "/api/inventory/",
        headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "DELETE"},
    )
    assert response.headers.get("access-control-allow-credentials") is None
    response = client.get("/api/inventory/", headers={"Origin": "https://evil.example", "Cookie": "a=b"})
    assert response.headers.get("access-control-allow-origin") == "*"
