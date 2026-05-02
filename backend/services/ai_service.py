import os
import requests
from dotenv import load_dotenv

# .env dosyasından ortam değişkenlerini yükle
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

def get_recipe_suggestion(ingredients: list[str]) -> str:
    """
    Google Gemini API'sini kullanarak envanterdeki malzemelerle tarif uretir.
    """
    if not ingredients:
        return "Malzeme listeniz bos. Lutfen envanterinize urun ekleyin."

    if not GEMINI_API_KEY:
        return "API anahtari bulunamadi. Lutfen backend/.env dosyasina GEMINI_API_KEY ekleyin."

    ingredient_list = ", ".join(ingredients)

    prompt = (
        f"Benim dolabimda su gida malzemeleri var: {ingredient_list}. "
        "Lutfen bu malzemeleri veya bazilarini kullanarak yapabilecegim pratik, lezzetli "
        "ve israfi onleyecek bir yemek tarifi oner. "
        "Tarifte bende olmayan birkac temel yardimci malzeme (sivi yag, tuz, karabiber gibi) "
        "varsa onlari ekleyebilirsin ama ana malzemeler benim listemden olmali. "
        "Bana sadece en uygun 1 tane tarif ver. Yanitin kisa ve oz olsun."
    )

    try:
        response = requests.post(
            f"{GEMINI_API_URL}?key={GEMINI_API_KEY}",
            headers={"Content-Type": "application/json"},
            json={
                "contents": [
                    {
                        "parts": [
                            {"text": prompt}
                        ]
                    }
                ]
            },
            timeout=30,
        )

        if response.status_code == 200:
            data = response.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]
        else:
            return f"Gemini API hatasi (HTTP {response.status_code}): {response.text[:200]}"

    except Exception as e:
        return f"Tarif uretilirken bir hata olustu: {str(e)}"


def chat_with_gemini(messages: list[dict]) -> str:
    """
    Kullanicinin sohbet gecmisiyle birlikte Gemini'ye mesaj gonderir.
    messages: [{"role": "user", "text": "..."}, {"role": "model", "text": "..."}]
    """
    if not GEMINI_API_KEY:
        return "API anahtari bulunamadi."

    # Sistem talimatı
    system_prompt = {
        "role": "user",
        "parts": [{"text": "Sen bir yemek ve mutfak uzmanisin. Kullaniciya yemek tarifleri, mutfak ipuclari ve gida saklama yontemleri hakkinda yardimci ol. Yanitlarin kisa, samimi ve Turkce olsun."}]
    }
    model_ack = {
        "role": "model",
        "parts": [{"text": "Tabii, size yemek ve mutfak konusunda yardimci olmaktan mutluluk duyarim! Sorunuzu bekliyorum."}]
    }

    # Sohbet gecmisini Gemini formatina cevir
    contents = [system_prompt, model_ack]
    for msg in messages:
        contents.append({
            "role": msg.get("role", "user"),
            "parts": [{"text": msg.get("text", "")}]
        })

    try:
        response = requests.post(
            f"{GEMINI_API_URL}?key={GEMINI_API_KEY}",
            headers={"Content-Type": "application/json"},
            json={"contents": contents},
            timeout=30,
        )

        if response.status_code == 200:
            data = response.json()
            return data["candidates"][0]["content"]["parts"][0]["text"]
        else:
            return f"Gemini API hatasi (HTTP {response.status_code}): {response.text[:200]}"

    except Exception as e:
        return f"Sohbet sirasinda bir hata olustu: {str(e)}"
