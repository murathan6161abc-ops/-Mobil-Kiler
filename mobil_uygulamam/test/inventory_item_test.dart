import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/app_settings.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

InventoryItem item(DateTime expiry, {DateType type = DateType.skt}) =>
    InventoryItem(id: 1, name: 'Süt', expiryDate: expiry, dateType: type);

void main() {
  group('daysBetween', () {
    test('saat farkı gün hesabını bozmaz (yarın bitecek ürün "0 gün" görünmemeli)', () {
      final afternoon = DateTime(2026, 9, 27, 14, 30);
      expect(daysBetween(afternoon, DateTime(2026, 9, 28)), 1);
      expect(daysBetween(afternoon, DateTime(2026, 9, 27)), 0);
      expect(daysBetween(afternoon, DateTime(2026, 9, 26)), -1);
      expect(daysBetween(DateTime(2026, 9, 27, 23, 59), DateTime(2026, 9, 30)), 3);
    });

    test('ay ve yıl geçişleri', () {
      expect(daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
      expect(daysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
    });
  });

  group('ExpiryLevel ve etiketler', () {
    final today = DateTime(2026, 9, 27, 15);

    test('SKT', () {
      expect(item(DateTime(2026, 9, 25)).level(today: today), ExpiryLevel.expired);
      expect(item(DateTime(2026, 9, 25)).statusLabel(today: today), 'Süresi doldu');
      expect(item(DateTime(2026, 9, 27)).statusLabel(today: today), 'Son gün!');
      expect(item(DateTime(2026, 9, 28)).statusLabel(today: today), '1 gün');
      expect(item(DateTime(2026, 9, 30)).level(today: today), ExpiryLevel.soon);
      expect(item(DateTime(2026, 10, 4)).level(today: today), ExpiryLevel.week);
      expect(item(DateTime(2026, 12, 1)).level(today: today), ExpiryLevel.fresh);
    });

    test('TETT geçmiş ürün "süresi doldu" sayılmaz', () {
      final tett = item(DateTime(2026, 9, 20), type: DateType.tett);
      expect(tett.level(today: today), ExpiryLevel.tettPassed);
      expect(tett.statusLabel(today: today), 'TETT geçti');
    });

    test('dikkat gerektirenler', () {
      expect(ExpiryLevel.expired.needsAttention, isTrue);
      expect(ExpiryLevel.tettPassed.needsAttention, isTrue);
      expect(ExpiryLevel.soon.needsAttention, isTrue);
      expect(ExpiryLevel.week.needsAttention, isFalse);
    });
  });

  test('JSON dönüşümü ve eski kayıtlar için varsayılanlar', () {
    final parsed = InventoryItem.fromJson({
      'id': 3,
      'barcode': '869',
      'name': 'Makarna',
      'category': null,
      'expiry_date': '2027-05-12',
    });
    expect(parsed.dateType, DateType.skt);
    expect(parsed.location, StorageLocation.dolap);
    expect(parsed.quantityLabel, '1 adet');
    expect(parsed.toJson()['expiry_date'], '2027-05-12');

    final full = InventoryItem.fromJson({
      ...parsed.toStorageJson(),
      'date_type': 'TETT',
      'quantity': 1.5,
      'unit': 'kg',
      'location': 'buzdolabi',
    });
    expect(full.dateType, DateType.tett);
    expect(full.location, StorageLocation.buzdolabi);
    expect(full.quantityLabel, '1,5 kg');
  });

  test('normalizeBaseUrl', () {
    expect(normalizeBaseUrl('192.168.1.5:8000'), 'http://192.168.1.5:8000/api');
    expect(normalizeBaseUrl(' http://192.168.1.5:8000/ '), 'http://192.168.1.5:8000/api');
    expect(normalizeBaseUrl('https://kiler.example.com/api/'), 'https://kiler.example.com/api');
    expect(normalizeBaseUrl(''), '');
  });

  test('tarih biçimleri', () {
    expect(formatShortDate(DateTime(2026, 9, 7)), '07.09.2026');
    expect(formatLongDate(DateTime(2026, 9, 7)), '7 Eylül 2026');
    expect(toIsoDate(DateTime(2026, 9, 7)), '2026-09-07');
    expect(formatQuantity(2), '2');
    expect(formatQuantity(0.25), '0,25');
  });
}
