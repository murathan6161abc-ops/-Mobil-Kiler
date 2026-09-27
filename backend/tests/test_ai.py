import config
import requests
from services import ai_service
from tests.conftest import add_item, gemini_response


def sent_payload(gemini):
    return gemini.call_args.kwargs["json"]


def test_recipe_uses_pantry_sorted_by_expiry_and_skips_expired_skt(client, gemini):
    add_item(client, "Pirinç", days=200)
    add_item(client, "Süt", days=-2)  # SKT geçmiş: gönderilmemeli
    add_item(client, "Ekmek", days=-1, date_type="TETT")  # TETT geçmiş: uyarıyla gönderilir
    add_item(client, "Yumurta", days=1)
    add_item(client, "yumurta", days=4)  # aynı isim tekrar gönderilmez

    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 200
    body = response.json()
    assert body["recipe"].startswith("## Menemen")
    assert body["used_items"] == ["Ekmek", "Yumurta", "Pirinç"]

    prompt = sent_payload(gemini)["contents"][0]["parts"][0]["text"]
    assert "Süt" not in prompt
    assert "Ekmek (TETT geçmiş, kontrol edilmeli)" in prompt
    assert "Yumurta (SKT: 1 gün kaldı)" in prompt
    assert prompt.index("Ekmek") < prompt.index("Yumurta") < prompt.index("Pirinç")


def test_api_key_is_sent_in_header_not_url(client, gemini):
    add_item(client, "Süt")
    client.post("/api/suggest-recipe/", json={})
    url = gemini.call_args.args[0]
    assert "key=" not in url
    assert gemini.call_args.kwargs["headers"]["x-goog-api-key"] == "test-key"
    assert config.GEMINI_MODEL in url
    assert "systemInstruction" in sent_payload(gemini)


def test_recipe_with_explicit_ingredients(client, gemini):
    response = client.post("/api/suggest-recipe/", json={"available_ingredients": ["Süt", " Süt ", "Un", ""]})
    assert response.status_code == 200
    assert response.json()["used_items"] == ["Süt", "Un"]


def test_recipe_with_empty_pantry_returns_422(client, gemini):
    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 422
    gemini.assert_not_called()


def test_missing_api_key_returns_503(client, gemini, monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "")
    add_item(client, "Süt")
    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 503
    assert "GEMINI_API_KEY" in response.json()["detail"]


def test_quota_error_returns_429_without_leaking_details(client, gemini):
    gemini.return_value = gemini_response(status_code=429, payload={"error": {"message": "Quota exceeded for project 1234"}})
    add_item(client, "Süt")
    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 429
    assert "1234" not in response.text


def test_server_error_returns_502_without_leaking_details(client, gemini):
    gemini.return_value = gemini_response(status_code=500, payload={"error": {"message": "internal secret"}})
    add_item(client, "Süt")
    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 502
    assert "secret" not in response.text


def test_safety_block_returns_422(client, gemini):
    gemini.return_value = gemini_response(payload={"candidates": [{"finishReason": "SAFETY"}]})
    add_item(client, "Süt")
    response = client.post("/api/suggest-recipe/", json={})
    assert response.status_code == 422


def test_timeout_returns_504(client, gemini):
    gemini.side_effect = requests.Timeout()
    add_item(client, "Süt")
    assert client.post("/api/suggest-recipe/", json={}).status_code == 504


def test_thought_parts_are_ignored(client, gemini):
    gemini.return_value = gemini_response(
        payload={"candidates": [{"content": {"parts": [{"text": "düşünce", "thought": True}, {"text": "Cevap"}]}}]}
    )
    add_item(client, "Süt")
    assert client.post("/api/suggest-recipe/", json={}).json()["recipe"] == "Cevap"


def test_chat_moves_leading_model_message_to_system_instruction(client, gemini):
    add_item(client, "Yumurta", days=2)
    response = client.post(
        "/api/chat/",
        json={
            "messages": [
                {"role": "model", "text": "## Menemen tarifi"},
                {"role": "user", "text": "Soğan eklenir mi?"},
                {"role": "user", "text": "Kaç kişilik?"},
            ]
        },
    )
    assert response.status_code == 200
    assert response.json()["reply"].startswith("## Menemen")

    payload = sent_payload(gemini)
    assert [content["role"] for content in payload["contents"]] == ["user"]
    assert payload["contents"][0]["parts"][0]["text"] == "Soğan eklenir mi?\n\nKaç kişilik?"
    system = payload["systemInstruction"]["parts"][0]["text"]
    assert "## Menemen tarifi" in system
    assert "Yumurta (SKT: 2 gün kaldı)" in system


def test_chat_without_inventory_context(client, gemini):
    add_item(client, "Yumurta")
    client.post("/api/chat/", json={"messages": [{"role": "user", "text": "Selam"}], "include_inventory": False})
    assert "Yumurta" not in sent_payload(gemini)["systemInstruction"]["parts"][0]["text"]


def test_chat_history_is_limited(client, gemini):
    messages = []
    for i in range(30):
        messages.append({"role": "user", "text": f"soru {i}"})
        messages.append({"role": "model", "text": f"cevap {i}"})
    messages.append({"role": "user", "text": "son soru"})
    client.post("/api/chat/", json={"messages": messages})
    contents = sent_payload(gemini)["contents"]
    assert len(contents) <= ai_service.MAX_CHAT_HISTORY
    assert contents[0]["role"] == "user"
    assert contents[-1]["parts"][0]["text"] == "son soru"


def test_chat_validation(client, gemini):
    assert client.post("/api/chat/", json={"messages": "merhaba"}).status_code == 422
    assert client.post("/api/chat/", json={"messages": []}).status_code == 422
    assert client.post("/api/chat/", json={"messages": [{"role": "system", "text": "x"}]}).status_code == 422
    assert client.post("/api/chat/", json={"messages": [{"role": "model", "text": "x"}]}).status_code == 422
    gemini.assert_not_called()


def test_ai_rate_limit(client, gemini, monkeypatch):
    monkeypatch.setattr(config, "AI_RATE_LIMIT_PER_MINUTE", 2)
    body = {"messages": [{"role": "user", "text": "Selam"}]}
    assert client.post("/api/chat/", json=body).status_code == 200
    assert client.post("/api/chat/", json=body).status_code == 200
    assert client.post("/api/chat/", json=body).status_code == 429
