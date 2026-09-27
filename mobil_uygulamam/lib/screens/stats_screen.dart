import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/models/api_models.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/theme.dart';

/// İsraf etki paneli: tüketilen ve çöpe giden ürünlerin özeti.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final AppServices _services = AppScope.of(context);
  InventoryStats? _stats;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _stats == null;
      _error = null;
    });
    try {
      final stats = await _services.api.getStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'İsraf Etki Paneli',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[ErrorBox(message: _error!, onRetry: _load), const SizedBox(height: 16)],
            if (stats != null) ...[
              _SavedRateCard(stats: stats),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatTile(
                    label: 'Tüketilen',
                    value: stats.consumedCount,
                    detail: 'Bu ay: ${stats.consumedThisMonth}',
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.good,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Çöpe giden',
                    value: stats.wastedCount,
                    detail: 'Bu ay: ${stats.wastedThisMonth}',
                    icon: Icons.delete_sweep_rounded,
                    iconColor: AppColors.critical,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatTile(
                    label: 'Dolapta',
                    value: stats.activeCount,
                    icon: Icons.kitchen_rounded,
                    iconColor: AppColors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: '3 gün içinde',
                    value: stats.expiringSoonCount,
                    icon: Icons.access_time_filled,
                    iconColor: AppColors.serious,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'SKT geçmiş',
                    value: stats.expiredCount,
                    icon: Icons.dangerous_rounded,
                    iconColor: AppColors.critical,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (stats.mostWastedCategories.isNotEmpty) _WastedCategoriesCard(categories: stats.mostWastedCategories),
              const SizedBox(height: 12),
              const _HowItWorksCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _SavedRateCard extends StatelessWidget {
  const _SavedRateCard({required this.stats});

  final InventoryStats stats;

  @override
  Widget build(BuildContext context) {
    final rate = stats.savedRate;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kurtarma oranı', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            rate == null ? '—' : '%${(rate * 100).round()}',
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate ?? 0,
              minHeight: 10,
              color: AppColors.good,
              backgroundColor: AppColors.good.withAlpha(40),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            rate == null
                ? 'Henüz dolaptan çıkan ürün yok. Ürünleri "Tükettim" ya da "Çöpe gitti" diye '
                      'işaretledikçe oranınız burada görünecek.'
                : 'Dolaptan çıkan ${stats.closedCount} üründen ${stats.consumedCount} tanesi tüketildi, '
                      '${stats.wastedCount} tanesi çöpe gitti.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.iconColor, this.detail});

  final String label;
  final int value;
  final String? detail;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            if (detail != null) Text(detail!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _WastedCategoriesCard extends StatelessWidget {
  const _WastedCategoriesCard({required this.categories});

  final List<CategoryCount> categories;

  @override
  Widget build(BuildContext context) {
    final maxCount = categories.map((entry) => entry.count).reduce((a, b) => a > b ? a : b);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En çok israf edilen kategoriler',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Alışverişte bu kategorilerden daha az almayı deneyin.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          for (final entry in categories) ...[
            Row(
              children: [
                Expanded(
                  child: Text(entry.category, style: const TextStyle(color: AppColors.ink)),
                ),
                Text(
                  '${entry.count} ürün',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: entry.count / maxCount,
                minHeight: 6,
                color: Colors.blueGrey.shade400,
                backgroundColor: Colors.blueGrey.shade50,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu panel, Kilerim sekmesinde bir ürüne dokunup "Tükettim" ya da "Çöpe gitti" '
              'seçtiğinizde güncellenir. Düzenli kullanıldığında, uygulamanın israfı ne kadar '
              'azalttığını gösteren ölçülebilir bir veri kaynağı olur.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
