import logging
from dataclasses import dataclass
from typing import Optional

import requests

import config

logger = logging.getLogger(__name__)

GEMINI_URL_TEMPLATE = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# Sohbette Gemini'ye gönderilen en fazla mesaj sayısı (maliyeti sınırlı tutar)
MAX_CHAT_HISTORY = 20


class AIServiceError(Exception):
    """Kullanıcıya gösterilebilir mesaj ve HTTP durum kodu taşıyan hata."""

    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


@dataclass
class PantryItem:
    name: str
    days_left: Optional[int] = None
    date_type: str = "SKT"


RECIPE_SYSTEM_PROMPT = (
    "Sen gıda israfını önlemeye odaklanan, Türk mutfağını iyi bilen bir aşçısın. "
    "Kullanıcının dolabındaki malzemelerle yapılabilecek pratik ve lezzetli tek bir tarif önerirsin. "
    "Kurallar:\n"
    "1. Son tüketim tarihi en yakın olan malzemeleri öncelikle kullan.\n"
    "2. Ana malzemeler kullanıcının listesinden olsun; sıvı yağ, tuz, baharat gibi temel "
    "yardımcı malzemeleri ekleyebilirsin.\n"
    "3. 'TETT geçmiş' diye işaretlenen malzemeler için kullanıcıya önce koku, görünüm ve "
    "tadına bakarak kontrol etmesini hatırlat.\n"
    "4. Yanıtı Türkçe ve Markdown biçiminde ver: '## Tarif adı', ardından '**Süre:**' ve "
    "'**Porsiyon:**' satırları, '### Malzemeler' (madde işaretli), '### Hazırlanışı' "
    "(numaralı adımlar) ve son olarak '### Neden bu tarif?' başlığı altında hangi "
    "malzemeleri israftan kurtardığını tek cümleyle yaz.\n"
    "5. Kısa ve öz ol."
)

CHAT_SYSTEM_PROMPT = (
    "Sen 'Mobil Kiler' uygulamasının mutfak asistanısın. Kullanıcıya yemek tarifleri, "
    "mutfak ipuçları, gıda saklama yöntemleri ve gıda israfını azaltma konusunda yardımcı "
    "olursun. SKT (son tüketim tarihi) geçmiş ürünlerin tüketilmemesi gerektiğini, TETT "
    "(tavsiye edilen tüketim tarihi) geçmiş ürünlerin ise kontrol edilerek çoğu zaman "
    "tüketilebileceğini bilirsin. Yanıtların kısa, samimi ve Türkçe olsun. Gıda güvenliği "
    "konusunda emin olmadığın durumda temkinli davran."
)


def describe_item(item: PantryItem) -> str:
    if item.days_left is None:
        return item.name
    if item.days_left < 0:
        return f"{item.name} ({item.date_type} geçmiş, kontrol edilmeli)"
    if item.days_left == 0:
        return f"{item.name} ({item.date_type} bugün doluyor)"
    return f"{item.name} ({item.date_type}: {item.days_left} gün kaldı)"


def build_recipe_prompt(items: list[PantryItem]) -> str:
    lines = "\n".join(f"- {describe_item(item)}" for item in items)
    return (
        "Dolabımdaki malzemeler (son tüketim tarihi en yakın olan en üstte):\n"
        f"{lines}\n\n"
        "Bu malzemelerle yapabileceğim en uygun 1 tarifi öner."
    )


def _extract_text(data: dict) -> str:
    candidates = data.get("candidates") or []
    if not candidates:
        return ""
    parts = (candidates[0].get("content") or {}).get("parts") or []
    return "".join(part.get("text", "") for part in parts if not part.get("thought")).strip()


def generate(contents: list[dict], system_instruction: str) -> str:
    if not config.GEMINI_API_KEY:
        raise AIServiceError(
            "Yapay zekâ servisi yapılandırılmamış. backend/.env dosyasına GEMINI_API_KEY ekleyin.",
            status_code=503,
        )

    try:
        response = requests.post(
            GEMINI_URL_TEMPLATE.format(model=config.GEMINI_MODEL),
            headers={"Content-Type": "application/json", "x-goog-api-key": config.GEMINI_API_KEY},
            json={
                "systemInstruction": {"parts": [{"text": system_instruction}]},
                "contents": contents,
            },
            timeout=config.AI_TIMEOUT_SECONDS,
        )
    except requests.Timeout:
        raise AIServiceError("Yapay zekâ servisi zamanında yanıt vermedi. Lütfen tekrar deneyin.", 504)
    except requests.RequestException:
        logger.exception("Gemini isteği gönderilemedi")
        raise AIServiceError("Yapay zekâ servisine ulaşılamadı. İnternet bağlantısını kontrol edin.", 502)

    if response.status_code == 429:
        raise AIServiceError("Yapay zekâ kullanım kotası doldu. Biraz sonra tekrar deneyin.", 429)
    if response.status_code != 200:
        # Ayrıntı sadece sunucu loguna yazılır, kullanıcıya gönderilmez
        logger.error("Gemini HTTP %s: %s", response.status_code, response.text[:500])
        raise AIServiceError("Yapay zekâ servisi bir hata döndürdü. Lütfen tekrar deneyin.", 502)

    try:
        data = response.json()
    except ValueError:
        logger.error("Gemini geçersiz JSON döndürdü: %s", response.text[:500])
        raise AIServiceError("Yapay zekâ servisinden geçersiz yanıt alındı.", 502)

    text = _extract_text(data)
    if not text:
        finish_reason = (data.get("candidates") or [{}])[0].get("finishReason")
        block_reason = (data.get("promptFeedback") or {}).get("blockReason")
        logger.warning("Gemini boş yanıt döndürdü (finishReason=%s, blockReason=%s)", finish_reason, block_reason)
        raise AIServiceError(
            "Yapay zekâ bu isteğe yanıt veremedi. Sorunuzu farklı şekilde sormayı deneyin.", 422
        )
    return text


def get_recipe_suggestion(items: list[PantryItem]) -> str:
    """Envanterdeki malzemelerle, SKT'si yaklaşanları önceleyen bir tarif üretir."""
    if not items:
        raise AIServiceError(
            "Tarif için uygun malzeme yok. Dolabınıza ürün ekleyin (süresi geçmiş ürünler kullanılmaz).",
            status_code=422,
        )
    contents = [{"role": "user", "parts": [{"text": build_recipe_prompt(items)}]}]
    return generate(contents, RECIPE_SYSTEM_PROMPT)


def build_chat_contents(messages: list[dict]) -> tuple[list[dict], list[str]]:
    """
    Sohbet geçmişini Gemini formatına çevirir.
    - Baştaki asistan mesajları (karşılama / önerilen tarif) bağlam olarak ayrılır.
    - Art arda gelen aynı rollü mesajlar birleştirilir (Gemini sıralı rol bekler).
    - Sadece son MAX_CHAT_HISTORY mesaj gönderilir.
    """
    leading_context: list[str] = []
    index = 0
    while index < len(messages) and messages[index]["role"] == "model":
        leading_context.append(messages[index]["text"])
        index += 1

    contents: list[dict] = []
    for message in messages[index:]:
        if contents and contents[-1]["role"] == message["role"]:
            contents[-1]["parts"][0]["text"] += "\n\n" + message["text"]
        else:
            contents.append({"role": message["role"], "parts": [{"text": message["text"]}]})

    contents = contents[-MAX_CHAT_HISTORY:]
    if contents and contents[0]["role"] == "model":
        contents = contents[1:]
    return contents, leading_context


def chat(messages: list[dict], pantry: Optional[list[PantryItem]] = None) -> str:
    """messages: [{"role": "user" | "model", "text": "..."}]"""
    contents, leading_context = build_chat_contents(messages)
    if not contents or contents[-1]["role"] != "user":
        raise AIServiceError("Son mesaj kullanıcıdan gelmeli.", status_code=422)

    system_instruction = CHAT_SYSTEM_PROMPT
    if pantry:
        items = "\n".join(f"- {describe_item(item)}" for item in pantry)
        system_instruction += f"\n\nKullanıcının dolabında şu anda şunlar var:\n{items}"
    if leading_context:
        context = "\n\n".join(leading_context)[-6000:]
        system_instruction += f"\n\nSohbetin başında kullanıcıya şunu yazdın:\n{context}"

    return generate(contents, system_instruction)
