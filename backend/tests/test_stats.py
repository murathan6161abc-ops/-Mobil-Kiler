from tests.conftest import add_item


def test_stats_empty(client):
    stats = client.get("/api/stats").json()
    assert stats["active_count"] == 0
    assert stats["saved_rate"] is None
    assert stats["most_wasted_categories"] == []


def test_stats_counts(client):
    add_item(client, "Süt", days=-1)
    add_item(client, "Yumurta", days=0)
    add_item(client, "Peynir", days=3)
    add_item(client, "Pirinç", days=30)
    consumed = [add_item(client, f"Elma {i}", days=10) for i in range(3)]
    wasted = add_item(client, "Marul", days=1, category="Sebze")
    wasted2 = add_item(client, "Ekmek", days=1)

    for item in consumed:
        client.post(f"/api/inventory/{item['id']}/close", json={"outcome": "consumed"})
    client.post(f"/api/inventory/{wasted['id']}/close", json={"outcome": "wasted"})
    client.post(f"/api/inventory/{wasted2['id']}/close", json={"outcome": "wasted"})

    stats = client.get("/api/stats").json()
    assert stats["active_count"] == 4
    assert stats["expired_count"] == 1
    assert stats["expiring_soon_count"] == 2  # bugün + 3 gün sonra
    assert stats["consumed_count"] == 3
    assert stats["wasted_count"] == 2
    assert stats["consumed_this_month"] == 3
    assert stats["wasted_this_month"] == 2
    assert stats["saved_rate"] == 0.6
    categories = {entry["category"]: entry["count"] for entry in stats["most_wasted_categories"]}
    assert categories == {"Sebze": 1, "Kategorisiz": 1}
