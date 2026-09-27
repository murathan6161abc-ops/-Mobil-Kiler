import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';

class AppColors {
  static const primaryDark = Color(0xFF1B5E20);
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF43A047);
  static const background = Color(0xFFF5F7FA);
  static const ink = Color(0xFF37474F);
  static const blue = Color(0xFF1565C0);
  static const purple = Color(0xFF6A1B9A);
  static const orange = Color(0xFFE65100);

  // Durum renkleri: her zaman simge + yazı ile birlikte kullanılır
  static const good = Color(0xFF2E7D32);
  static const warning = Color(0xFFF9A825);
  static const serious = Color(0xFFEF6C00);
  static const critical = Color(0xFFD32F2F);
}

class ExpiryStyle {
  const ExpiryStyle(this.colors, this.icon);

  final List<Color> colors;
  final IconData icon;

  Color get color => colors.first;

  static ExpiryStyle of(ExpiryLevel level) {
    switch (level) {
      case ExpiryLevel.expired:
        return const ExpiryStyle([Color(0xFFD32F2F), Color(0xFFEF5350)], Icons.dangerous_rounded);
      case ExpiryLevel.tettPassed:
        return const ExpiryStyle([Color(0xFF8D6E63), Color(0xFFA1887F)], Icons.visibility_rounded);
      case ExpiryLevel.lastDay:
        return const ExpiryStyle([Color(0xFFE53935), Color(0xFFEF5350)], Icons.warning_amber_rounded);
      case ExpiryLevel.soon:
        return const ExpiryStyle([Color(0xFFEF6C00), Color(0xFFFFA726)], Icons.access_time_filled);
      case ExpiryLevel.week:
        return const ExpiryStyle([Color(0xFFF9A825), Color(0xFFFFCA28)], Icons.schedule_rounded);
      case ExpiryLevel.fresh:
        return const ExpiryStyle([Color(0xFF2E7D32), Color(0xFF66BB6A)], Icons.check_circle_rounded);
    }
  }
}

IconData locationIcon(StorageLocation location) {
  switch (location) {
    case StorageLocation.dolap:
      return Icons.kitchen_rounded;
    case StorageLocation.buzdolabi:
      return Icons.ac_unit_rounded;
    case StorageLocation.dondurucu:
      return Icons.severe_cold_rounded;
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 4, shape: CircleBorder()),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// Kırmızı çerçeveli hata kutusu.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Form alanlarının üstündeki küçük başlık.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// SKT ile TETT arasındaki farkı anlatan bilgi penceresi.
Future<void> showDateTypeInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('SKT mi, TETT mi?'),
      content: const Text(
        'SKT (Son Tüketim Tarihi): Süt, et, tavuk gibi çabuk bozulan ürünlerde bulunur. '
        'Bu tarih geçtikten sonra ürün tüketilmemelidir.\n\n'
        'TETT (Tavsiye Edilen Tüketim Tarihi): Makarna, bakliyat, konserve gibi ürünlerde bulunur. '
        'Tarih geçtikten sonra ürünün tadı ya da kıvamı değişebilir, ancak ambalajı bozulmamışsa '
        've kokusu, görünüşü normalse çoğu zaman güvenle tüketilebilir.\n\n'
        'Bu ikisini karıştırmak, sağlam ürünlerin çöpe atılmasının en yaygın nedenlerinden biridir.',
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım'))],
    ),
  );
}
