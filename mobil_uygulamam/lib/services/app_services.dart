import 'package:flutter/widgets.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_settings.dart';
import 'package:mobil_uygulamam/services/inventory_cache.dart';
import 'package:mobil_uygulamam/services/label_scanner.dart';
import 'package:mobil_uygulamam/services/notification_service.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama genelinde paylaşılan servisler. Testlerde sahteleri verilebilir.
class AppServices {
  AppServices({
    required this.settings,
    required this.api,
    required this.cache,
    required this.notifications,
    required this.speech,
    required this.labelScanner,
  });

  final AppSettings settings;
  final ApiService api;
  final InventoryCache cache;
  final NotificationService notifications;
  final SpeechService speech;
  final LabelScanner labelScanner;

  static Future<AppServices> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final notifications = NotificationService();
    await notifications.init();
    return AppServices(
      settings: settings,
      api: ApiService(settings: settings),
      cache: InventoryCache(prefs),
      notifications: notifications,
      speech: SpeechService(),
      labelScanner: LabelScanner(),
    );
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
