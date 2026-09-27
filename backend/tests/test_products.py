from unittest import mock

from services import product_service
from tests.conftest import add_item


def off_response(payload, status_code=200):
    response = mock.Mock(status_code=status_code)
    response.json.return_value = payload
    return response


def test_lookup_returns_product_added_by_user(client, off):
    add_item(client, "Pınar Süt", barcode="8690504012011", category="Süt Ürünleri")
    response = client.get("/api/products/lookup", params={"barcode": "8690504012011"})
    assert response.status_code == 200
    assert response.json() == {
        "barcode": "8690504012011",
        "name": "Pınar Süt",
        "category": "Süt Ürünleri",
        "brand": None,
        "source": "user",
    }
    off.assert_not_called()


def test_lookup_uses_open_food_facts_and_caches_result(client, off):
    off.return_value = off_response(
        {
            "status": 1,
            "product": {
                "product_name": "Whole milk",
                "product_name_tr": "Tam Yağlı Süt",
                "brands": "Pınar, Yörsan",
                "categories_tags": ["en:beverages", "en:dairies", "en:milks"],
            },
        }
    )
    response = client.get("/api/products/lookup", params={"barcode": "8690504012011"})
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Tam Yağlı Süt"
    assert body["brand"] == "Pınar"
    assert body["category"] == "Süt Ürünleri"
    assert body["source"] == "openfoodfacts"
    assert off.call_args.kwargs["headers"]["User-Agent"].startswith("MobilKiler")

    # İkinci sorgu kendi kataloğumuzdan gelir
    client.get("/api/products/lookup", params={"barcode": "8690504012011"})
    assert off.call_count == 1


def test_lookup_not_found(client, off):
    off.return_value = off_response({"status": 0})
    response = client.get("/api/products/lookup", params={"barcode": "8690000000000"})
    assert response.status_code == 404


def test_lookup_skips_open_food_facts_for_qr_text(client, off):
    response = client.get("/api/products/lookup", params={"barcode": "https://ornek.com/urun?id=5"})
    assert response.status_code == 404
    off.assert_not_called()


def test_lookup_survives_network_error(client, off):
    off.side_effect = product_service.requests.ConnectionError()
    response = client.get("/api/products/lookup", params={"barcode": "8690000000000"})
    assert response.status_code == 404


def test_user_edit_updates_catalog(client, off):
    item = add_item(client, "Süt", barcode="123456789")
    client.patch(f"/api/inventory/{item['id']}", json={"name": "Keçi sütü", "category": "Süt Ürünleri"})
    body = client.get("/api/products/lookup", params={"barcode": "123456789"}).json()
    assert body["name"] == "Keçi sütü"
    assert body["category"] == "Süt Ürünleri"


def test_map_category_prefers_specific_tags():
    assert product_service.map_category(["en:beverages", "en:dairies"]) == "Süt Ürünleri"
    assert product_service.map_category(["en:frozen-foods", "en:vegetables"]) == "Dondurulmuş"
    assert product_service.map_category(["en:unknown"]) is None
