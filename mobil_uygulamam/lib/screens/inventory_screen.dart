import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/screens/scanner_screen.dart';
import 'package:mobil_uygulamam/screens/recipe_screen.dart';
import 'package:mobil_uygulamam/screens/edit_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getInventory();
      if (mounted) {
        data.sort((a, b) {
          final dateA = DateTime.tryParse(a['expiry_date'] ?? '') ?? DateTime(2099);
          final dateB = DateTime.tryParse(b['expiry_date'] ?? '') ?? DateTime(2099);
          return dateA.compareTo(dateB);
        });
        setState(() {
          _inventory = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  int _daysUntilExpiry(String? dateStr) {
    if (dateStr == null) return 999;
    final expiryDate = DateTime.tryParse(dateStr);
    if (expiryDate == null) return 999;
    return expiryDate.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> _getExpiryStatus(int daysLeft) {
    if (daysLeft < 0) {
      return {
        'gradient': [const Color(0xFFE53935), const Color(0xFFEF5350)],
        'icon': Icons.error_rounded,
        'label': 'Süresi Doldu',
        'chipColor': const Color(0xFFE53935),
      };
    } else if (daysLeft == 0) {
      return {
        'gradient': [const Color(0xFFE53935), const Color(0xFFEF5350)],
        'icon': Icons.warning_amber_rounded,
        'label': 'Son Gün!',
        'chipColor': const Color(0xFFE53935),
      };
    } else if (daysLeft <= 3) {
      return {
        'gradient': [const Color(0xFFEF6C00), const Color(0xFFFFA726)],
        'icon': Icons.access_time_filled,
        'label': '$daysLeft gün',
        'chipColor': const Color(0xFFEF6C00),
      };
    } else if (daysLeft <= 7) {
      return {
        'gradient': [const Color(0xFFF9A825), const Color(0xFFFFCA28)],
        'icon': Icons.schedule_rounded,
        'label': '$daysLeft gün',
        'chipColor': const Color(0xFFF9A825),
      };
    } else {
      return {
        'gradient': [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        'icon': Icons.check_circle_rounded,
        'label': '$daysLeft gün',
        'chipColor': const Color(0xFF2E7D32),
      };
    }
  }

  int get _expiringCount {
    return _inventory.where((item) {
      final days = _daysUntilExpiry(item['expiry_date']);
      return days <= 3;
    }).length;
  }

  void _goToScanner() async {
    final bool? shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (shouldRefresh == true) {
      _loadInventory();
    }
  }

  void _goToEdit(dynamic item) async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: Map<String, dynamic>.from(item)),
      ),
    );
    if (result == true) {
      _loadInventory();
    }
  }

  void _confirmDelete(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Ürünü Sil'),
          ],
        ),
        content: Text('${item['name']} envanterden silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteInventoryItem(item['id']);
                _loadInventory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item['name']} silindi.'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silme başarısız oldu.')),
                  );
                }
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _goToRecipe() {
    List<String> ingredients =
        _inventory.map<String>((item) => item['name'].toString()).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeScreen(ingredients: ingredients),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Modern Gradient AppBar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Mobil Kiler',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  ),
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 30),
                    child: Icon(Icons.eco_rounded, size: 40, color: Colors.white24),
                  ),
                ),
              ),
            ),
            actions: [
              if (_inventory.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                    tooltip: 'AI Tarif Önerisi',
                    onPressed: _goToRecipe,
                  ),
                ),
            ],
          ),

          // İstatistik Kartları
          if (!_isLoading && _inventory.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Toplam Ürün',
                      '${_inventory.length}',
                      Icons.inventory_2_rounded,
                      const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Dikkat!',
                      '$_expiringCount',
                      Icons.warning_amber_rounded,
                      _expiringCount > 0 ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
            ),

          // Uyarı Banner'ı
          if (!_isLoading && _expiringCount > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade50, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notification_important_rounded, color: Colors.red.shade600, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_expiringCount ürünün son kullanma tarihi yaklaşıyor!',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // İçerik
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_inventory.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.kitchen_rounded, size: 64, color: Colors.green.shade300),
                    ),
                    const SizedBox(height: 24),
                    const Text('Dolabınız Boş', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                    const SizedBox(height: 8),
                    Text('Ürün eklemek için aşağıdaki butona dokunun.', style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _inventory[index];
                  final daysLeft = _daysUntilExpiry(item['expiry_date']);
                  final status = _getExpiryStatus(daysLeft);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () => _goToEdit(item),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: status['gradient']),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(status['icon'], color: Colors.white, size: 26),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        subtitle: Text(
                          'SKT: ${item['expiry_date']}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (status['chipColor'] as Color).withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status['label'],
                                style: TextStyle(
                                  color: status['chipColor'],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 22),
                              tooltip: 'Sil',
                              onPressed: () => _confirmDelete(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _inventory.length,
              ),
            ),

          // Alt boşluk (FAB'ın arkasında kalan ürünler için)
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _goToScanner,
          backgroundColor: Colors.transparent,
          elevation: 0,
          tooltip: 'QR/Barkod Okut',
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
