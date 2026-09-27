import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_uygulamam/main.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';

import 'helpers.dart';

void main() {
  usePhoneScreen();

  testWidgets('envanter doğru etiketlerle listelenir', (tester) async {
    final backend = FakeBackend(
      items: [
        itemJson(1, 'Süt', -2),
        itemJson(2, 'Makarna', -5, type: 'TETT'),
        itemJson(3, 'Yoğurt', 0),
        itemJson(4, 'Peynir', 1, location: 'buzdolabi'),
        itemJson(5, 'Pirinç', 200),
      ],
    );
    await tester.pumpWidget(MyApp(services: await buildServices(backend)));
    await tester.pumpAndSettle();

    expect(find.text('Süresi doldu'), findsOneWidget);
    expect(find.text('TETT geçti'), findsOneWidget);
    expect(find.text('Son gün!'), findsOneWidget);
    // Yarın bitecek ürün "0 gün" ya da "Son gün" görünmemeli
    expect(find.text('1 gün'), findsOneWidget);
    expect(find.text('200 gün'), findsOneWidget);
    expect(find.textContaining('1 ürünün son tüketim tarihi geçti'), findsOneWidget);

    // Konum filtresi
    await tester.tap(find.widgetWithText(ChoiceChip, 'Buzdolabı'));
    await tester.pumpAndSettle();
    expect(find.text('Peynir'), findsOneWidget);
    expect(find.text('Pirinç'), findsNothing);
  });

  testWidgets('boş dolap', (tester) async {
    await tester.pumpWidget(MyApp(services: await buildServices(FakeBackend())));
    await tester.pumpAndSettle();
    expect(find.text('Dolabınız Boş'), findsOneWidget);
  });

  testWidgets('sunucuya ulaşılamazsa önbellekteki liste gösterilir', (tester) async {
    final services = await buildServices(
      FakeBackend(offline: true),
      cached: [InventoryItem(id: 1, name: 'Kaşar', expiryDate: DateTime.now().add(const Duration(days: 10)))],
    );
    await tester.pumpWidget(MyApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('Kaşar'), findsOneWidget);
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
  });

  testWidgets('sunucu yoksa ve önbellek boşsa hata ve çözüm gösterilir', (tester) async {
    await tester.pumpWidget(MyApp(services: await buildServices(FakeBackend(offline: true))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayarlar sekmesindeki adresin'), findsWidgets);
    expect(find.text('Tekrar dene'), findsWidgets);
  });

  testWidgets('ürün "Tükettim" olarak kapatılır', (tester) async {
    final backend = FakeBackend(items: [itemJson(7, 'Yumurta', 2)]);
    await tester.pumpWidget(MyApp(services: await buildServices(backend)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yumurta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tükettim'));
    await tester.pumpAndSettle();

    expect(backend.closed, ['7:consumed']);
    expect(find.text('Dolabınız Boş'), findsOneWidget);
  });

  testWidgets('etki paneli', (tester) async {
    await tester.pumpWidget(MyApp(services: await buildServices(FakeBackend(items: [itemJson(1, 'Süt', 3)]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Etki'));
    await tester.pumpAndSettle();
    expect(find.text('%60'), findsOneWidget);
    expect(find.textContaining('5 üründen 3 tanesi tüketildi'), findsOneWidget);
    expect(find.text('Sebze'), findsOneWidget);
  });
}
