import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobil_uygulamam/models/api_models.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(json.encode(body)), status, headers: {'content-type': 'application/json'});

Future<AppSettings> makeSettings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AppSettings(await SharedPreferences.getInstance());
}

void main() {
  test('istekler ayarlardaki adrese ve API anahtarıyla gider', () async {
    final settings = await makeSettings({'base_url': 'http://10.0.0.5:8000/api', 'api_key': 'gizli'});
    late http.Request captured;
    final api = ApiService(
      settings: settings,
      client: MockClient((request) async {
        captured = request;
        return jsonResponse([
          {'id': 1, 'barcode': '', 'name': 'Süt', 'expiry_date': '2027-01-01'},
        ]);
      }),
    );

    final items = await api.getInventory();
    expect(items.single.name, 'Süt');
    expect(captured.url.toString(), 'http://10.0.0.5:8000/api/inventory/?status=active');
    expect(captured.headers['X-API-Key'], 'gizli');
  });

  test('ürün ekleme gövdesi', () async {
    final settings = await makeSettings();
    late Map<String, dynamic> body;
    final api = ApiService(
      settings: settings,
      client: MockClient((request) async {
        body = json.decode(request.body) as Map<String, dynamic>;
        return jsonResponse({...body, 'id': 7, 'status': 'active'}, 201);
      }),
    );
    final created = await api.addItem(
      InventoryItemDraft(
        name: 'Makarna',
        expiryDate: DateTime(2027, 5, 31),
        dateType: DateType.tett,
        location: StorageLocation.dolap,
        quantity: 2,
        unit: 'paket',
      ),
    );
    expect(created.id, 7);
    expect(body['date_type'], 'TETT');
    expect(body['expiry_date'], '2027-05-31');
    expect(body['unit'], 'paket');
  });

  test('sunucunun hata mesajı kullanıcıya iletilir', () async {
    final settings = await makeSettings();
    final api = ApiService(
      settings: settings,
      client: MockClient((_) async => jsonResponse({'detail': 'Yapay zekâ kullanım kotası doldu.'}, 429)),
    );
    expect(
      () => api.suggestRecipe(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Yapay zekâ kullanım kotası doldu.')
            .having((e) => e.statusCode, 'statusCode', 429),
      ),
    );
  });

  test('401 anlaşılır mesaja çevrilir', () async {
    final settings = await makeSettings();
    final api = ApiService(settings: settings, client: MockClient((_) async => jsonResponse({'detail': 'x'}, 401)));
    expect(
      () => api.getStats(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('API anahtarı'))),
    );
  });

  test('bağlantı hatası isConnectionError olarak işaretlenir', () async {
    final settings = await makeSettings();
    final api = ApiService(
      settings: settings,
      client: MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    expect(
      () => api.getInventory(),
      throwsA(isA<ApiException>().having((e) => e.isConnectionError, 'isConnectionError', isTrue)),
    );
  });

  test('zaman aşımı', () async {
    final settings = await makeSettings();
    final api = ApiService(
      settings: settings,
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    expect(
      () => api.getInventory(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('zamanında'))),
    );
  });

  test('bilinmeyen barkod null döner', () async {
    final settings = await makeSettings();
    final api = ApiService(
      settings: settings,
      client: MockClient((_) async => jsonResponse({'detail': 'Bulunamadı'}, 404)),
    );
    expect(await api.lookupProduct('123'), isNull);
  });

  test('sohbette yerel mesajlar gönderilmez', () async {
    final settings = await makeSettings();
    late Map<String, dynamic> body;
    final api = ApiService(
      settings: settings,
      client: MockClient((request) async {
        body = json.decode(request.body) as Map<String, dynamic>;
        return jsonResponse({'reply': 'Tabii!'});
      }),
    );
    final reply = await api.chat(const [
      ChatMessage(role: 'model', text: 'Merhaba!', isLocal: true),
      ChatMessage(role: 'user', text: 'Menemen tarifi?'),
    ]);
    expect(reply, 'Tabii!');
    expect(body['messages'], [
      {'role': 'user', 'text': 'Menemen tarifi?'},
    ]);
  });
}
