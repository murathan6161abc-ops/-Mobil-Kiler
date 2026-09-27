import 'dart:convert';

import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedInventory {
  const CachedInventory(this.items, this.savedAt);

  final List<InventoryItem> items;
  final DateTime savedAt;
}

/// Sunucuya ulaşılamadığında son görülen envanteri gösterebilmek için
/// listeyi telefonda saklar (çevrimdışı mod).
class InventoryCache {
  InventoryCache(this._prefs);

  static const _key = 'inventory_cache_v1';

  final SharedPreferences _prefs;

  Future<void> save(List<InventoryItem> items) async {
    final payload = {
      'saved_at': DateTime.now().toIso8601String(),
      'items': [for (final item in items) item.toStorageJson()],
    };
    await _prefs.setString(_key, json.encode(payload));
  }

  CachedInventory? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      return CachedInventory([
        for (final item in data['items'] as List) InventoryItem.fromJson(item as Map<String, dynamic>),
      ], DateTime.parse(data['saved_at'] as String));
    } catch (_) {
      return null;
    }
  }
}
