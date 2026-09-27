import 'package:mobil_uygulamam/utils/dates.dart';

/// SKT: son tüketim tarihi (geçince tüketilmez).
/// TETT: tavsiye edilen tüketim tarihi (geçince kalite düşebilir, ürün
/// kontrol edilerek çoğu zaman tüketilebilir).
enum DateType {
  skt('SKT', 'SKT', 'Son Tüketim Tarihi'),
  tett('TETT', 'TETT', 'Tavsiye Edilen Tüketim Tarihi');

  const DateType(this.apiValue, this.label, this.longLabel);

  final String apiValue;
  final String label;
  final String longLabel;

  static DateType fromApi(String? value) => value == 'TETT' ? DateType.tett : DateType.skt;
}

enum StorageLocation {
  dolap('dolap', 'Dolap'),
  buzdolabi('buzdolabi', 'Buzdolabı'),
  dondurucu('dondurucu', 'Dondurucu');

  const StorageLocation(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static StorageLocation fromApi(String? value) =>
      StorageLocation.values.firstWhere((location) => location.apiValue == value, orElse: () => StorageLocation.dolap);
}

const List<String> itemUnits = ['adet', 'kg', 'g', 'L', 'ml', 'paket'];

const List<String> itemCategories = [
  'Süt Ürünleri',
  'Et & Tavuk',
  'Balık',
  'Sebze',
  'Meyve',
  'Fırın',
  'Kahvaltılık',
  'Bakliyat & Tahıl',
  'Konserve',
  'İçecek',
  'Atıştırmalık',
  'Dondurulmuş',
  'Sos & Baharat',
  'Diğer',
];

/// Kalan süreye göre ürünün durumu.
enum ExpiryLevel {
  /// SKT'si geçmiş: tüketilmemeli.
  expired,

  /// TETT'i geçmiş: kontrol edilerek tüketilebilir.
  tettPassed,
  lastDay,
  soon,
  week,
  fresh;

  bool get needsAttention => index <= ExpiryLevel.soon.index;
}

/// Sunucuya gönderilen (id'siz) ürün bilgisi.
class InventoryItemDraft {
  const InventoryItemDraft({
    required this.name,
    required this.expiryDate,
    this.barcode = '',
    this.category,
    this.dateType = DateType.skt,
    this.quantity = 1,
    this.unit = 'adet',
    this.location = StorageLocation.dolap,
  });

  final String barcode;
  final String name;
  final String? category;
  final DateTime expiryDate;
  final DateType dateType;
  final double quantity;
  final String unit;
  final StorageLocation location;

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'category': category,
    'expiry_date': toIsoDate(expiryDate),
    'date_type': dateType.apiValue,
    'quantity': quantity,
    'unit': unit,
    'location': location.apiValue,
  };
}

class InventoryItem extends InventoryItemDraft {
  const InventoryItem({
    required this.id,
    required super.name,
    required super.expiryDate,
    super.barcode,
    super.category,
    super.dateType,
    super.quantity,
    super.unit,
    super.location,
    this.status = 'active',
  });

  final int id;

  /// active | consumed | wasted
  final String status;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as int,
      barcode: (json['barcode'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      category: json['category'] as String?,
      expiryDate: DateTime.tryParse((json['expiry_date'] as String?) ?? '') ?? DateTime(2100),
      dateType: DateType.fromApi(json['date_type'] as String?),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: (json['unit'] as String?) ?? 'adet',
      location: StorageLocation.fromApi(json['location'] as String?),
      status: (json['status'] as String?) ?? 'active',
    );
  }

  /// Çevrimdışı önbellek için tam kayıt.
  Map<String, dynamic> toStorageJson() => {...toJson(), 'id': id, 'status': status};

  int daysLeft({DateTime? today}) => daysBetween(today ?? DateTime.now(), expiryDate);

  ExpiryLevel level({DateTime? today}) {
    final days = daysLeft(today: today);
    if (days < 0) return dateType == DateType.tett ? ExpiryLevel.tettPassed : ExpiryLevel.expired;
    if (days == 0) return ExpiryLevel.lastDay;
    if (days <= 3) return ExpiryLevel.soon;
    if (days <= 7) return ExpiryLevel.week;
    return ExpiryLevel.fresh;
  }

  /// Listede gösterilen kısa durum etiketi.
  String statusLabel({DateTime? today}) {
    final days = daysLeft(today: today);
    switch (level(today: today)) {
      case ExpiryLevel.expired:
        return 'Süresi doldu';
      case ExpiryLevel.tettPassed:
        return 'TETT geçti';
      case ExpiryLevel.lastDay:
        return 'Son gün!';
      case ExpiryLevel.soon:
      case ExpiryLevel.week:
      case ExpiryLevel.fresh:
        return '$days gün';
    }
  }

  String get quantityLabel => '${formatQuantity(quantity)} $unit';
}
