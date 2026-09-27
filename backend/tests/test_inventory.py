from tests.conftest import TODAY, add_item


def test_add_item_returns_201_with_defaults(client):
    item = add_item(client, "Süt", days=3, barcode="8690000000001", category="Süt Ürünleri")
    assert item["name"] == "Süt"
    assert item["status"] == "active"
    assert item["date_type"] == "SKT"
    assert item["quantity"] == 1
    assert item["unit"] == "adet"
    assert item["location"] == "dolap"
    assert item["category"] == "Süt Ürünleri"


def test_add_item_strips_whitespace(client):
    item = add_item(client, "  Yoğurt  ")
    assert item["name"] == "Yoğurt"


def test_add_item_without_barcode_is_allowed(client):
    item = add_item(client, "Domates", location="buzdolabi", quantity=1.5, unit="kg")
    assert item["barcode"] == ""
    assert item["quantity"] == 1.5


def test_add_item_rejects_invalid_input(client):
    base = {"barcode": "1", "name": "Süt", "expiry_date": "2027-01-01"}
    invalid = [
        {"name": ""},
        {"name": "   "},
        {"name": "A" * 121},
        {"barcode": "1" * 65},
        {"expiry_date": "1990-01-01"},
        {"expiry_date": "2150-01-01"},
        {"quantity": 0},
        {"location": "balkon"},
        {"date_type": "XYZ"},
        {"unit": "ton"},
    ]
    for override in invalid:
        response = client.post("/api/inventory/", json={**base, **override})
        assert response.status_code == 422, override


def test_inventory_is_sorted_by_expiry_and_hides_closed_items(client):
    add_item(client, "Pirinç", days=400)
    add_item(client, "Süt", days=-2)
    closed = add_item(client, "Ekmek", days=1)
    add_item(client, "Yumurta", days=2)
    client.post(f"/api/inventory/{closed['id']}/close", json={"outcome": "consumed"})

    names = [item["name"] for item in client.get("/api/inventory/").json()]
    assert names == ["Süt", "Yumurta", "Pirinç"]

    all_names = [item["name"] for item in client.get("/api/inventory/?status=all").json()]
    assert "Ekmek" in all_names


def test_expiring_filters_by_days(client):
    add_item(client, "Süt", days=-5)
    add_item(client, "Yumurta", days=2)
    add_item(client, "Peynir", days=7)
    add_item(client, "Pirinç", days=400)

    names = [item["name"] for item in client.get("/api/inventory/expiring/?days=7").json()]
    assert names == ["Süt", "Yumurta", "Peynir"]

    names = [item["name"] for item in client.get("/api/inventory/expiring/?days=3").json()]
    assert names == ["Süt", "Yumurta"]

    assert client.get("/api/inventory/expiring/?days=-1").status_code == 422


def test_partial_update_keeps_category(client):
    item = add_item(client, "Süt", category="Süt Ürünleri", location="buzdolabi")

    response = client.put(f"/api/inventory/{item['id']}", json={"name": "Yarım yağlı süt"})
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Yarım yağlı süt"
    assert body["category"] == "Süt Ürünleri"
    assert body["location"] == "buzdolabi"

    response = client.patch(f"/api/inventory/{item['id']}", json={"expiry_date": TODAY.isoformat(), "date_type": "TETT"})
    assert response.json()["expiry_date"] == TODAY.isoformat()
    assert response.json()["date_type"] == "TETT"


def test_update_can_clear_category_but_not_required_fields(client):
    item = add_item(client, "Süt", category="Süt Ürünleri")
    response = client.patch(f"/api/inventory/{item['id']}", json={"category": None, "name": None})
    assert response.status_code == 200
    assert response.json()["category"] is None
    assert response.json()["name"] == "Süt"


def test_update_and_delete_missing_item_returns_404(client):
    assert client.put("/api/inventory/999", json={"name": "X"}).status_code == 404
    assert client.delete("/api/inventory/999").status_code == 404
    assert client.get("/api/inventory/999").status_code == 404


def test_close_item(client):
    item = add_item(client, "Süt")
    response = client.post(f"/api/inventory/{item['id']}/close", json={"outcome": "wasted"})
    assert response.status_code == 200
    assert response.json()["status"] == "wasted"
    assert response.json()["closed_at"] is not None

    again = client.post(f"/api/inventory/{item['id']}/close", json={"outcome": "consumed"})
    assert again.status_code == 409

    bad = client.post(f"/api/inventory/{item['id']}/close", json={"outcome": "lost"})
    assert bad.status_code == 422


def test_delete_item(client):
    item = add_item(client, "Süt")
    assert client.delete(f"/api/inventory/{item['id']}").status_code == 200
    assert client.get("/api/inventory/").json() == []
