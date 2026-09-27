import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/screens/product_form_screen.dart';
import 'package:mobil_uygulamam/screens/recipe_screen.dart';
import 'package:mobil_uygulamam/screens/scanner_screen.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';
import 'package:mobil_uygulamam/theme.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

enum _ItemAction { consumed, wasted, edit, delete }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.refreshToken = 0});

  /// Değiştiğinde liste sunucudan yeniden yüklenir.
  final int refreshToken;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final AppServices _services = AppScope.of(context);
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String? _error;

  /// Sunucuya ulaşılamadığında gösterilen önbelleğin kaydedildiği zaman.
  DateTime? _offlineSince;
  StorageLocation? _locationFilter;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void didUpdateWidget(covariant InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _error = null;
    });
    try {
      final items = await _services.api.getInventory();
      items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _offlineSince = null;
      });
      await _services.cache.save(items);
      await _services.notifications.reschedule(
        items,
        enabledByUser: _services.settings.notificationsEnabled,
        hour: _services.settings.reminderHour,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final cached = error.isConnectionError ? _services.cache.load() : null;
      setState(() {
        _isLoading = false;
        if (cached != null) {
          _items = cached.items;
          _offlineSince = cached.savedAt;
        } else {
          _error = error.message;
        }
      });
    }
  }

  List<InventoryItem> get _visibleItems =>
      _locationFilter == null ? _items : _items.where((item) => item.location == _locationFilter).toList();

  int get _attentionCount => _items.where((item) => item.level().needsAttention).length;

  int get _expiredCount => _items.where((item) => item.level() == ExpiryLevel.expired).length;

  void _showMessage(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _openScanner() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (saved == true) _loadInventory();
  }

  Future<void> _openEditor(InventoryItem item) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ProductFormScreen(item: item)));
    if (saved == true) _loadInventory();
  }

  void _openRecipe() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeScreen()));
  }

  void _speakSummary() {
    _services.speech.speak(buildInventorySpeech(_items));
  }

  Future<void> _onItemTap(InventoryItem item) async {
    if (_offlineSince != null) {
      _showMessage('Çevrimdışı moddasınız. Değişiklik yapmak için sunucuya bağlanın.');
      return;
    }
    final action = await showModalBottomSheet<_ItemAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ItemSheet(item: item),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ItemAction.consumed:
        await _closeItem(item, 'consumed');
      case _ItemAction.wasted:
        await _closeItem(item, 'wasted');
      case _ItemAction.edit:
        await _openEditor(item);
      case _ItemAction.delete:
        await _confirmDelete(item);
    }
  }

  Future<void> _closeItem(InventoryItem item, String outcome) async {
    try {
      await _services.api.closeItem(item.id, outcome);
      if (!mounted) return;
      _showMessage(
        outcome == 'consumed'
            ? '${item.name} tüketildi olarak işaretlendi. Afiyet olsun!'
            : '${item.name} israf olarak kaydedildi. Etki sekmesinden takip edebilirsiniz.',
        color: outcome == 'consumed' ? AppColors.good : null,
      );
      _loadInventory();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Ürünü Sil'),
          ],
        ),
        content: Text(
          '${item.name} kalıcı olarak silinsin mi?\n\n'
          'İpucu: Ürünü tükettiyseniz ya da attıysanız "Tükettim" / "Çöpe gitti" '
          'seçeneklerini kullanın; böylece israf istatistiğiniz oluşur.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _services.api.deleteItem(item.id);
      if (!mounted) return;
      _showMessage('${item.name} silindi.');
      _loadInventory();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadInventory,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Mobil Kiler',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white, letterSpacing: 1),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primaryLight],
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
                if (_items.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.record_voice_over_rounded, color: Colors.white),
                    tooltip: 'Sesli özet',
                    onPressed: _speakSummary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                    tooltip: 'Yapay zekâ tarif önerisi',
                    onPressed: _openRecipe,
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
            if (_offlineSince != null)
              SliverToBoxAdapter(
                child: _OfflineBanner(savedAt: _offlineSince!, onRetry: _loadInventory),
              ),
            if (_error != null && _items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorBox(message: _error!, onRetry: _loadInventory),
                ),
              ),
            if (!_isLoading && _items.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _StatCard(
                        title: 'Toplam ürün',
                        value: '${_items.length}',
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        title: 'Dikkat',
                        value: '$_attentionCount',
                        icon: Icons.warning_amber_rounded,
                        color: _attentionCount > 0 ? AppColors.critical : AppColors.good,
                      ),
                    ],
                  ),
                ),
              ),
              if (_attentionCount > 0)
                SliverToBoxAdapter(
                  child: _AttentionBanner(attention: _attentionCount, expired: _expiredCount),
                ),
              SliverToBoxAdapter(
                child: _LocationFilter(
                  selected: _locationFilter,
                  onSelected: (location) => setState(() => _locationFilter = location),
                ),
              ),
            ],
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty && _error == null)
              const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
            else
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) => _InventoryTile(item: visible[index], onTap: _onItemTap),
              ),
            // FAB'ın arkasında kalan ürünler için boşluk
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight]),
          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          onPressed: _openScanner,
          backgroundColor: Colors.transparent,
          elevation: 0,
          tooltip: 'Ürün ekle (barkod okut)',
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item, required this.onTap});

  final InventoryItem item;
  final ValueChanged<InventoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final style = ExpiryStyle.of(item.level());
    final details = [
      '${item.dateType.label}: ${formatShortDate(item.expiryDate)}',
      item.location.label,
      item.quantityLabel,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          onTap: () => onTap(item),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: style.colors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, color: Colors.white, size: 26),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: style.color.withAlpha(24), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  item.statusLabel(),
                  style: TextStyle(color: style.color, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(details, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final level = item.level();
    final style = ExpiryStyle.of(level);
    final days = item.daysLeft();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: style.icon,
                  color: style.color,
                  text: '${item.dateType.label}: ${formatLongDate(item.expiryDate)} (${item.statusLabel()})',
                ),
                _InfoChip(icon: locationIcon(item.location), text: item.location.label),
                _InfoChip(icon: Icons.scale_rounded, text: item.quantityLabel),
                if (item.category != null) _InfoChip(icon: Icons.category_rounded, text: item.category!),
              ],
            ),
            if (level == ExpiryLevel.expired) ...[
              const SizedBox(height: 14),
              _Advice(
                color: AppColors.critical,
                icon: Icons.dangerous_rounded,
                text: 'Son tüketim tarihi ${-days} gün önce geçti. Gıda güvenliği için tüketmeyin.',
              ),
            ],
            if (level == ExpiryLevel.tettPassed) ...[
              const SizedBox(height: 14),
              _Advice(
                color: const Color(0xFF6D4C41),
                icon: Icons.visibility_rounded,
                text:
                    'Tavsiye edilen tarih geçti ama bu bir "son tüketim" tarihi değil. Ambalaj sağlamsa, '
                    'kokusu ve görünüşü normalse çoğu zaman tüketilebilir.',
                onInfo: () => showDateTypeInfo(context),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.good,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(context, _ItemAction.consumed),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Tükettim'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.critical,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.pop(context, _ItemAction.wasted),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Çöpe gitti'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, _ItemAction.edit),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Düzenle'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                  onPressed: () => Navigator.pop(context, _ItemAction.delete),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Yanlış kayıt, sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Advice extends StatelessWidget {
  const _Advice({required this.color, required this.icon, required this.text, this.onInfo});

  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, height: 1.4)),
          ),
          if (onInfo != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'SKT ve TETT farkı',
              onPressed: onInfo,
              icon: Icon(Icons.info_outline_rounded, color: color),
            ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt, required this.onRetry});

  final DateTime savedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final time = '${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sunucuya ulaşılamadı. ${formatShortDate(savedAt)} $time tarihli kayıt gösteriliyor.',
              style: TextStyle(color: Colors.blueGrey.shade800),
            ),
          ),
          IconButton(onPressed: onRetry, tooltip: 'Tekrar dene', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.attention, required this.expired});

  final int attention;
  final int expired;

  @override
  Widget build(BuildContext context) {
    final soon = attention - expired;
    final parts = [
      if (expired > 0) '$expired ürünün son tüketim tarihi geçti',
      if (soon > 0) '$soon ürün için süre doluyor ya da kontrol gerekiyor',
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade50, Colors.orange.shade50]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.notification_important_rounded, color: Colors.red.shade600, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${parts.join(', ')}.',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({required this.selected, required this.onSelected});

  final StorageLocation? selected;
  final ValueChanged<StorageLocation?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          ChoiceChip(label: const Text('Tümü'), selected: selected == null, onSelected: (_) => onSelected(null)),
          for (final location in StorageLocation.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(locationIcon(location), size: 18),
              label: Text(location.label),
              selected: selected == location,
              onSelected: (_) => onSelected(location),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.kitchen_rounded, size: 64, color: Colors.green.shade300),
            ),
            const SizedBox(height: 24),
            const Text(
              'Dolabınız Boş',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Ürün eklemek için aşağıdaki butona dokunun.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
