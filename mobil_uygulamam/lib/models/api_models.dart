class ProductInfo {
  const ProductInfo({required this.barcode, required this.name, this.category, this.brand, this.source = 'user'});

  final String barcode;
  final String name;
  final String? category;
  final String? brand;

  /// user | openfoodfacts
  final String source;

  factory ProductInfo.fromJson(Map<String, dynamic> json) => ProductInfo(
    barcode: json['barcode'] as String,
    name: json['name'] as String,
    category: json['category'] as String?,
    brand: json['brand'] as String?,
    source: (json['source'] as String?) ?? 'user',
  );
}

class CategoryCount {
  const CategoryCount(this.category, this.count);

  final String category;
  final int count;
}

class InventoryStats {
  const InventoryStats({
    required this.activeCount,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.consumedCount,
    required this.wastedCount,
    required this.consumedThisMonth,
    required this.wastedThisMonth,
    this.savedRate,
    this.mostWastedCategories = const [],
  });

  final int activeCount;
  final int expiringSoonCount;
  final int expiredCount;
  final int consumedCount;
  final int wastedCount;
  final int consumedThisMonth;
  final int wastedThisMonth;

  /// 0..1 arası; henüz kapatılan ürün yoksa null.
  final double? savedRate;
  final List<CategoryCount> mostWastedCategories;

  int get closedCount => consumedCount + wastedCount;

  factory InventoryStats.fromJson(Map<String, dynamic> json) => InventoryStats(
    activeCount: json['active_count'] as int,
    expiringSoonCount: json['expiring_soon_count'] as int,
    expiredCount: json['expired_count'] as int,
    consumedCount: json['consumed_count'] as int,
    wastedCount: json['wasted_count'] as int,
    consumedThisMonth: json['consumed_this_month'] as int,
    wastedThisMonth: json['wasted_this_month'] as int,
    savedRate: (json['saved_rate'] as num?)?.toDouble(),
    mostWastedCategories: [
      for (final entry in (json['most_wasted_categories'] as List? ?? const []))
        CategoryCount(entry['category'] as String, entry['count'] as int),
    ],
  );
}

class RecipeResult {
  const RecipeResult({required this.recipe, required this.usedItems});

  final String recipe;
  final List<String> usedItems;
}

class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.isLocal = false});

  /// user | model
  final String role;
  final String text;

  /// Sadece ekranda gösterilen (sunucuya gönderilmeyen) mesaj, örn. karşılama.
  final bool isLocal;

  bool get isUser => role == 'user';

  Map<String, String> toJson() => {'role': role, 'text': text};
}
