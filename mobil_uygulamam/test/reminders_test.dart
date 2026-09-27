import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/notification_service.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';

InventoryItem item(int id, String name, DateTime expiry, {DateType type = DateType.skt, String status = 'active'}) =>
    InventoryItem(id: id, name: name, expiryDate: expiry, dateType: type, status: status);

void main() {
  final now = DateTime(2026, 9, 27, 8);

  test('SKT için 3 gün, 1 gün önce ve son gün; aynı gün tek bildirim', () {
    final plan = buildReminderPlan(
      [item(1, 'Süt', DateTime(2026, 9, 30)), item(2, 'Yoğurt', DateTime(2026, 9, 28))],
      now: now,
      hour: 9,
    );
    expect(plan.map((day) => day.fireAt).toList(), [
      DateTime(2026, 9, 27, 9),
      DateTime(2026, 9, 28, 9),
      DateTime(2026, 9, 29, 9),
      DateTime(2026, 9, 30, 9),
    ]);
    // 27 Eylül: Süt 3 gün kaldı + Yoğurt yarın son gün
    expect(plan.first.lines, ['Süt: 3 gün kaldı', 'Yoğurt: yarın son gün']);
    expect(plan.first.title, '2 ürün için hatırlatma');
    expect(plan[1].lines, ['Yoğurt: bugün son gün']);
  });

  test('geçmiş saatler, kapalı ürünler ve eski tarihler atlanır', () {
    final plan = buildReminderPlan(
      [
        item(1, 'Ekmek', DateTime(2026, 9, 27)),
        item(2, 'Peynir', DateTime(2026, 9, 29), status: 'consumed'),
        item(3, 'Süt', DateTime(2026, 9, 20)),
      ],
      now: DateTime(2026, 9, 27, 10),
      hour: 9,
    );
    expect(plan, isEmpty);
  });

  test('TETT için yalnızca son gün hatırlatılır', () {
    final plan = buildReminderPlan([item(1, 'Makarna', DateTime(2026, 10, 5), type: DateType.tett)], now: now, hour: 9);
    expect(plan.length, 1);
    expect(plan.single.fireAt, DateTime(2026, 10, 5, 9));
    expect(plan.single.body, contains('kontrol edip tüketebilirsiniz'));
  });

  test('en fazla maxDays bildirim', () {
    final items = [for (var i = 0; i < 40; i++) item(i, 'Ürün $i', DateTime(2026, 10, 10 + i))];
    expect(buildReminderPlan(items, now: now, hour: 9, maxDays: 30).length, 30);
  });

  test('sesli özet', () {
    final today = DateTime(2026, 9, 27);
    final text = buildInventorySpeech([
      item(1, 'Süt', DateTime(2026, 9, 25)),
      item(2, 'Makarna', DateTime(2026, 9, 20), type: DateType.tett),
      item(3, 'Yoğurt', DateTime(2026, 9, 27)),
      item(4, 'Peynir', DateTime(2026, 9, 29)),
      item(5, 'Pirinç', DateTime(2027, 9, 29)),
    ], today: today);
    expect(text, startsWith('Dolabınızda 5 ürün var.'));
    expect(text, contains('tüketmeyin: Süt'));
    expect(text, contains('kontrol edin: Makarna'));
    expect(text, contains('Bugün son gün: Yoğurt'));
    expect(text, contains('Üç gün içinde bitecek: Peynir'));
    expect(buildInventorySpeech(const []), 'Dolabınız boş.');
  });

  test('tarihin sesli ifadesi', () {
    final today = DateTime(2026, 9, 27);
    expect(
      buildDateSpeech(DateTime(2026, 10, 2), DateType.skt, today: today),
      'Son Tüketim Tarihi 2 Ekim 2026. 5 gün kaldı.',
    );
    expect(buildDateSpeech(DateTime(2026, 9, 25), DateType.skt, today: today), contains('tüketmeyin'));
    expect(buildDateSpeech(DateTime(2026, 9, 25), DateType.tett, today: today), contains('kontrol ederek'));
  });
}
