import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/services/app_settings.dart';
import 'package:mobil_uygulamam/services/inventory_cache.dart';
import 'package:mobil_uygulamam/services/label_scanner.dart';
import 'package:mobil_uygulamam/services/notification_service.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';
import 'package:mobil_uygulamam/utils/dates.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(json.encode(body)), status, headers: {'content-type': 'application/json'});

String inDays(int days) => toIsoDate(dateOnly(DateTime.now()).add(Duration(days: days)));

Map<String, Object?> itemJson(int id, String name, int days, {String type = 'SKT', String location = 'dolap'}) => {
  'id': id,
  'barcode': '',
  'name': name,
  'category': null,
  'expiry_date': inDays(days),
  'date_type': type,
  'quantity': 1,
  'unit': 'adet',
  'location': location,
  'status': 'active',
};

const statsJson = {
  'active_count': 4,
  'expiring_soon_count': 2,
  'expired_count': 1,
  'consumed_count': 3,
  'wasted_count': 2,
  'consumed_this_month': 3,
  'wasted_this_month': 1,
  'saved_rate': 0.6,
  'most_wasted_categories': [
    {'category': 'Sebze', 'count': 2},
  ],
};

/// Testlerde sunucunun yerine geçen basit sahte arka uç.
class FakeBackend {
  FakeBackend({List<Map<String, Object?>>? items, this.offline = false}) : items = items ?? [];

  final List<Map<String, Object?>> items;
  bool offline;
  final List<http.Request> requests = [];
  final List<String> closed = [];
  Map<String, Object?>? product;
  http.Response recipeResponse = jsonResponse({
    'recipe': '## Menemen\n**Süre:** 15 dk\n\n### Malzemeler\n- Yumurta\n- Domates',
    'used_items': ['Yumurta', 'Domates'],
  });
  http.Response chatResponse = jsonResponse({'reply': 'Elbette, **soğan** eklenebilir.'});
  bool aiConfigured = true;

  MockClient get client => MockClient((request) async {
    if (offline) throw http.ClientException('Connection refused');
    requests.add(request);
    final path = request.url.path;
    final method = request.method;
    if (method == 'GET' && path == '/api/health') return jsonResponse({'status': 'ok', 'ai_configured': aiConfigured});
    if (method == 'GET' && path == '/api/inventory/') return jsonResponse(items);
    if (method == 'GET' && path == '/api/stats') return jsonResponse(statsJson);
    if (method == 'GET' && path == '/api/products/lookup') {
      return product == null ? jsonResponse({'detail': 'Bulunamadı'}, 404) : jsonResponse(product);
    }
    if (method == 'POST' && path == '/api/inventory/') {
      final body = json.decode(request.body) as Map<String, dynamic>;
      return jsonResponse({...body, 'id': 99, 'status': 'active'}, 201);
    }
    if (method == 'PATCH' && path.startsWith('/api/inventory/')) {
      final body = json.decode(request.body) as Map<String, dynamic>;
      return jsonResponse({...body, 'id': int.parse(request.url.pathSegments[2]), 'status': 'active'});
    }
    if (method == 'POST' && path.endsWith('/close')) {
      final id = int.parse(request.url.pathSegments[2]);
      closed.add('$id:${(json.decode(request.body) as Map)['outcome']}');
      items.removeWhere((item) => item['id'] == id);
      return jsonResponse({...itemJson(id, 'x', 0), 'status': 'consumed'});
    }
    if (method == 'POST' && path == '/api/suggest-recipe/') return recipeResponse;
    if (method == 'POST' && path == '/api/chat/') return chatResponse;
    return jsonResponse({'detail': 'Bulunamadı'}, 404);
  });

  Map<String, dynamic> lastBody(String method, String path) {
    final request = requests.lastWhere((r) => r.method == method && r.url.path == path);
    return json.decode(request.body) as Map<String, dynamic>;
  }
}

Future<AppServices> buildServices(FakeBackend backend, {List<InventoryItem>? cached}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final cache = InventoryCache(prefs);
  if (cached != null) await cache.save(cached);
  return AppServices(
    settings: settings,
    api: ApiService(settings: settings, client: backend.client),
    cache: cache,
    notifications: NotificationService.disabled(),
    speech: SpeechService(),
    labelScanner: LabelScanner(),
  );
}

/// Testler dar bir telefon ekranında (360 x 1200) çalışır; taşmalar yakalanır.
void usePhoneScreen() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 3600);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
