import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_uygulamam/main.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/screens/chat_screen.dart';
import 'package:mobil_uygulamam/screens/product_form_screen.dart';
import 'package:mobil_uygulamam/screens/recipe_screen.dart';
import 'package:mobil_uygulamam/screens/settings_screen.dart';

import 'helpers.dart';

/// Ekranı bir düğmeyle açar; ekranın döndürdüğü sonucu [result] içine yazar.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.screen, required this.result});

  final Widget screen;
  final List<Object?> result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async => result.add(await Navigator.push(context, MaterialPageRoute(builder: (_) => screen))),
          child: const Text('Aç'),
        ),
      ),
    );
  }
}

void main() {
  usePhoneScreen();

  testWidgets('barkodla ürün ekleme: bilgi otomatik dolar, TETT seçilir, kaydedilir', (tester) async {
    final backend = FakeBackend()
      ..product = {
        'barcode': '8690504012011',
        'name': 'Tam Yağlı Süt',
        'category': 'Süt Ürünleri',
        'brand': 'Pınar',
        'source': 'openfoodfacts',
      };
    final result = <Object?>[];
    await tester.pumpWidget(
      MyApp(
        services: await buildServices(backend),
        home: _Launcher(
          screen: const ProductFormScreen(barcode: '8690504012011'),
          result: result,
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('Tam Yağlı Süt'), findsOneWidget);
    expect(find.textContaining('Open Food Facts'), findsOneWidget);

    await tester.tap(find.text('TETT (tavsiye)'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Buzdolabı'));
    await tester.pump();
    await tester.ensureVisible(find.text('Envantere Ekle'));
    await tester.tap(find.text('Envantere Ekle'));
    await tester.pumpAndSettle();

    final body = backend.lastBody('POST', '/api/inventory/');
    expect(body['name'], 'Tam Yağlı Süt');
    expect(body['barcode'], '8690504012011');
    expect(body['category'], 'Süt Ürünleri');
    expect(body['date_type'], 'TETT');
    expect(body['location'], 'buzdolabi');
    expect(result, [true]);
  });

  testWidgets('boş isimle kaydedilemez', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(MyApp(services: await buildServices(backend), home: const ProductFormScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Envantere Ekle'));
    await tester.tap(find.text('Envantere Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Lütfen ürün adını girin.'), findsOneWidget);
    expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('süresi geçmiş ürün düzenlenirken tarih seçici açılır (eski çökme)', (tester) async {
    final backend = FakeBackend();
    final item = InventoryItem(
      id: 5,
      name: 'Yoğurt',
      category: 'Süt Ürünleri',
      expiryDate: DateTime.now().subtract(const Duration(days: 10)),
    );
    await tester.pumpWidget(
      MyApp(
        services: await buildServices(backend),
        home: ProductFormScreen(item: item),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Değiştir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('İptal'), findsOneWidget); // Türkçe tarih seçici
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Güncelle'));
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    final body = backend.lastBody('PATCH', '/api/inventory/5');
    expect(body['category'], 'Süt Ürünleri'); // kategori artık silinmiyor
  });

  testWidgets('tarif ekranı Markdown gösterir', (tester) async {
    await tester.pumpWidget(MyApp(services: await buildServices(FakeBackend()), home: const RecipeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Menemen'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.text('Domates'), findsWidgets);
  });

  testWidgets('tarif hatası anlaşılır şekilde gösterilir', (tester) async {
    final backend = FakeBackend()..recipeResponse = jsonResponse({'detail': 'Yapay zekâ kullanım kotası doldu.'}, 429);
    await tester.pumpWidget(MyApp(services: await buildServices(backend), home: const RecipeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Yapay zekâ kullanım kotası doldu.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('sohbet', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(MyApp(services: await buildServices(backend), home: const ChatScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Menemene soğan konur mu?');
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Menemene soğan konur mu?'), findsOneWidget);
    expect(find.textContaining('eklenebilir'), findsOneWidget);
    // Karşılama mesajı sunucuya gönderilmez
    expect(backend.lastBody('POST', '/api/chat/')['messages'], [
      {'role': 'user', 'text': 'Menemene soğan konur mu?'},
    ]);
  });

  testWidgets('ayarlar: adres kaydedilir ve bağlantı test edilir', (tester) async {
    final backend = FakeBackend()..aiConfigured = false;
    final services = await buildServices(backend);
    await tester.pumpWidget(MyApp(services: services, home: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Sunucu adresi'), '10.0.0.7:8000');
    await tester.tap(find.text('Kaydet ve bağlantıyı test et'));
    await tester.pumpAndSettle();

    expect(services.settings.baseUrl, 'http://10.0.0.7:8000/api');
    expect(backend.requests.last.url.toString(), 'http://10.0.0.7:8000/api/health');
    expect(find.textContaining('GEMINI_API_KEY'), findsOneWidget);
  });
}
