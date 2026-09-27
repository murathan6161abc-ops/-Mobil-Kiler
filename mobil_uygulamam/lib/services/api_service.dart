import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobil_uygulamam/models/api_models.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/app_settings.dart';

/// Kullanıcıya doğrudan gösterilebilecek mesaj taşıyan hata.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;

  /// Sunucuya hiç ulaşılamadıysa null.
  final int? statusCode;

  bool get isConnectionError => statusCode == null;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    required this.settings,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.aiTimeout = const Duration(seconds: 75),
  }) : _client = client ?? http.Client();

  final AppSettings settings;
  final http.Client _client;
  final Duration timeout;

  /// Yapay zekâ yanıtları daha uzun sürebilir.
  final Duration aiTimeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${settings.baseUrl}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration? requestTimeout,
  }) async {
    final limit = requestTimeout ?? timeout;
    final http.Response response;
    try {
      final request = http.Request(method, _uri(path, query));
      request.headers['Content-Type'] = 'application/json';
      if (settings.apiKey.isNotEmpty) request.headers['X-API-Key'] = settings.apiKey;
      if (body != null) request.body = json.encode(body);
      final streamed = await _client.send(request).timeout(limit);
      response = await http.Response.fromStream(streamed).timeout(limit);
    } on TimeoutException {
      throw const ApiException('Sunucu zamanında yanıt vermedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
    } on FormatException {
      throw ApiException('Sunucu adresi geçersiz: ${settings.baseUrl}. Ayarlar sekmesinden düzeltin.');
    } catch (_) {
      throw ApiException(
        'Sunucuya bağlanılamadı (${settings.baseUrl}). Sunucunun açık olduğundan ve '
        'Ayarlar sekmesindeki adresin doğru olduğundan emin olun.',
      );
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = json.decode(text);
      } on FormatException {
        data = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw ApiException(_errorMessage(response.statusCode, data), statusCode: response.statusCode);
  }

  static String _errorMessage(int statusCode, dynamic data) {
    final detail = data is Map ? data['detail'] : null;
    if (statusCode == 401) return 'API anahtarı hatalı ya da eksik. Ayarlar sekmesinden kontrol edin.';
    if (detail is String && detail.isNotEmpty) return detail;
    if (statusCode == 422 && detail is List && detail.isNotEmpty) {
      final first = detail.first;
      final message = first is Map ? first['msg'] : null;
      return 'Girilen bilgiler geçersiz${message != null ? ': $message' : '.'}';
    }
    if (statusCode == 404) return 'İstenen kayıt bulunamadı.';
    return 'Sunucu hatası (HTTP $statusCode). Lütfen tekrar deneyin.';
  }

  // ------------------------------------------------------------ Genel

  /// Bağlantı testi. Yapay zekânın yapılandırılıp yapılandırılmadığını da döner.
  Future<bool> checkHealth() async {
    final data = await _send('GET', '/health') as Map<String, dynamic>;
    return data['ai_configured'] == true;
  }

  // ------------------------------------------------------------ Envanter

  Future<List<InventoryItem>> getInventory({String status = 'active'}) async {
    final data = await _send('GET', '/inventory/', query: {'status': status}) as List;
    return [for (final item in data) InventoryItem.fromJson(item as Map<String, dynamic>)];
  }

  Future<InventoryItem> addItem(InventoryItemDraft draft) async {
    final data = await _send('POST', '/inventory/', body: draft.toJson());
    return InventoryItem.fromJson(data as Map<String, dynamic>);
  }

  Future<InventoryItem> updateItem(int id, InventoryItemDraft draft) async {
    final data = await _send('PATCH', '/inventory/$id', body: draft.toJson());
    return InventoryItem.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteItem(int id) => _send('DELETE', '/inventory/$id');

  /// outcome: "consumed" (tüketildi) ya da "wasted" (çöpe gitti)
  Future<void> closeItem(int id, String outcome) => _send('POST', '/inventory/$id/close', body: {'outcome': outcome});

  Future<InventoryStats> getStats() async {
    final data = await _send('GET', '/stats');
    return InventoryStats.fromJson(data as Map<String, dynamic>);
  }

  /// Barkoda ait ürün bilgisi; bulunamazsa null.
  Future<ProductInfo?> lookupProduct(String barcode) async {
    try {
      final data = await _send('GET', '/products/lookup', query: {'barcode': barcode});
      return ProductInfo.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  // ------------------------------------------------------------ Yapay zekâ

  /// Sunucu, dolaptaki ürünleri SKT'si en yakın olandan başlayarak kullanır.
  Future<RecipeResult> suggestRecipe() async {
    final data = await _send('POST', '/suggest-recipe/', body: const {}, requestTimeout: aiTimeout) as Map;
    return RecipeResult(
      recipe: data['recipe'] as String,
      usedItems: [for (final name in (data['used_items'] as List? ?? const [])) name as String],
    );
  }

  static const int maxChatMessages = 100;

  Future<String> chat(List<ChatMessage> messages) async {
    final history = messages.where((message) => !message.isLocal).toList();
    final trimmed = history.length > maxChatMessages ? history.sublist(history.length - maxChatMessages) : history;
    final data =
        await _send(
              'POST',
              '/chat/',
              body: {
                'messages': [for (final message in trimmed) message.toJson()],
              },
              requestTimeout: aiTimeout,
            )
            as Map;
    return data['reply'] as String;
  }
}
