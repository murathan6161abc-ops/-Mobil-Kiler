import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/expiry_date_parser.dart';

void main() {
  final parser = ExpiryDateParser(today: DateTime(2026, 9, 27));

  void expectDate(String text, DateTime date, DateType? type) {
    final result = parser.parse(text);
    expect(result, isNotNull, reason: text);
    expect(result!.date, date, reason: text);
    expect(result.dateType, type, reason: text);
  }

  group('SKT', () {
    test('standart biçimler', () {
      expectDate('SKT: 12.05.2027', DateTime(2027, 5, 12), DateType.skt);
      expectDate('S.K.T. 12/05/2027', DateTime(2027, 5, 12), DateType.skt);
      expectDate('skt 12-05-27', DateTime(2027, 5, 12), DateType.skt);
      expectDate('Son Tüketim Tarihi: 3.1.2027', DateTime(2027, 1, 3), DateType.skt);
      expectDate('SON KULLANMA TARİHİ 01.10.2026', DateTime(2026, 10, 1), DateType.skt);
      expectDate('STT: 30.09.2026', DateTime(2026, 9, 30), DateType.skt);
      expectDate('EXP 2027-05-12', DateTime(2027, 5, 12), DateType.skt);
    });

    test('ifade bir üst satırda', () {
      expectDate('SKT\n12.05.2027', DateTime(2027, 5, 12), DateType.skt);
    });

    test('OCR boşlukları', () {
      expectDate('SKT : 12 . 05 . 2027', DateTime(2027, 5, 12), DateType.skt);
      expectDate('SKT 12 05 2027', DateTime(2027, 5, 12), DateType.skt);
    });

    test('ay adıyla', () {
      expectDate('SKT: 12 MAYIS 2027', DateTime(2027, 5, 12), DateType.skt);
      expectDate('SKT 12 Ağustos 2027', DateTime(2027, 8, 12), DateType.skt);
      expectDate('EXP 12 DEC 2026', DateTime(2026, 12, 12), DateType.skt);
    });
  });

  group('TETT', () {
    test('tam tarih', () {
      expectDate('TETT: 12.05.2027', DateTime(2027, 5, 12), DateType.tett);
      expectDate('T.E.T.T. 12/05/2027', DateTime(2027, 5, 12), DateType.tett);
      expectDate('Tavsiye Edilen Tüketim Tarihi: 01.02.2028', DateTime(2028, 2, 1), DateType.tett);
      expectDate('BEST BEFORE 12.05.2027', DateTime(2027, 5, 12), DateType.tett);
    });

    test('ay-yıl yazılmışsa ayın son günü alınır', () {
      expectDate('TETT: 05/2027', DateTime(2027, 5, 31), DateType.tett);
      expectDate('TETT 02.2028', DateTime(2028, 2, 29), DateType.tett);
      expectDate('TETT: MAYIS 2027', DateTime(2027, 5, 31), DateType.tett);
    });
  });

  group('üretim tarihi', () {
    test('ÜT yok sayılır, SKT seçilir', () {
      expectDate('ÜT: 01.09.2026 SKT: 15.10.2026', DateTime(2026, 10, 15), DateType.skt);
      expectDate('SKT: 15.10.2026\nÜ.T.: 01.09.2026', DateTime(2026, 10, 15), DateType.skt);
      expectDate('Üretim Tarihi 01.09.2026\nTETT 01.09.2028', DateTime(2028, 9, 1), DateType.tett);
      expectDate('PROD 01.09.2026 EXP 01.03.2027', DateTime(2027, 3, 1), DateType.skt);
    });

    test('yalnızca üretim tarihi varsa sonuç yok', () {
      expect(parser.parse('Üretim Tarihi: 01.09.2026'), isNull);
    });

    test('"süt" kelimesi üretim tarihi sanılmaz', () {
      expectDate('Tam yağlı süt 12.10.2026', DateTime(2026, 10, 12), null);
    });
  });

  test('kamera okumasındaki harf-rakam karışıklıkları düzeltilir', () {
    expectDate('SKT: 12.O5.2O27', DateTime(2027, 5, 12), DateType.skt);
    expectDate('SKT: I2/05/2027', DateTime(2027, 5, 12), DateType.skt);
    expectDate('S.K.T 1l.05.2027', DateTime(2027, 5, 11), DateType.skt);
    expectDate('TETT: O5/2O28', DateTime(2028, 5, 31), DateType.tett);
    // "B.B." (best before) ifadesi rakama çevrilmez
    expectDate('B.B. 12.05.2027', DateTime(2027, 5, 12), DateType.tett);
    // Tarih olmayan kelimelere dokunulmaz
    expectDate('SÜT SKT 12.05.2027', DateTime(2027, 5, 12), DateType.skt);
  });

  test('etiketsiz birden çok tarihte en geç olan seçilir', () {
    expectDate('01.09.2026 01.03.2027', DateTime(2027, 3, 1), null);
  });

  test('gerçekçi etiket metni', () {
    const label =
        'PINAR\nTAM YAĞLI UHT SÜT 1 L\nParti No: L2309\nÜT: 01.09.2026\nSKT: 01.03.2027\n'
        'Net: 1000 ml  Fiyat 42.50 TL';
    expectDate(label, DateTime(2027, 3, 1), DateType.skt);
  });

  test('bulunan metin kullanıcıya gösterilebilir', () {
    final result = parser.parse('Son Tüketim: 12.05.2027 Lot 5')!;
    expect(result.matchedText, '12.05.2027');
  });

  test('geçersiz ya da anlamsız tarihler', () {
    expect(parser.parse(''), isNull);
    expect(parser.parse('Fiyat 12.50 TL'), isNull);
    expect(parser.parse('SKT: 31.02.2027'), isNull);
    expect(parser.parse('SKT: 12.13.2027'), isNull);
    expect(parser.parse('SKT: 12.05.1990'), isNull);
    expect(parser.parse('Tel: 0 462 123 45 67'), isNull);
  });
}
