const List<String> turkishMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// İki tarih arasındaki gün farkı; saatler yok sayılır.
///
/// `DateTime.difference().inDays` saat farkını da hesaba kattığı için, yarın
/// bitecek bir ürün öğleden sonra "0 gün" görünüyordu. Hesap UTC gün başları
/// üzerinden yapılır (yaz saati geçişlerinden de etkilenmez).
int daysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// 2026-09-27
String toIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 27.09.2026
String formatShortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

/// 27 Eylül 2026
String formatLongDate(DateTime date) => '${date.day} ${turkishMonths[date.month - 1]} ${date.year}';

/// Bir ayın son günü (ay-yıl şeklinde yazılmış TETT'ler için).
DateTime lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0);

/// 1 -> "1", 1.5 -> "1,5"
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');
}
