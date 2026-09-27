import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/utils/dates.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Belirli bir günde gönderilecek tek bildirim (o gün hatırlatılacak tüm ürünler).
class ReminderDay {
  const ReminderDay({required this.fireAt, required this.lines});

  final DateTime fireAt;
  final List<String> lines;

  String get title => lines.length == 1 ? 'Mobil Kiler hatırlatması' : '${lines.length} ürün için hatırlatma';

  String get body => lines.join('\n');
}

/// Hangi gün hangi ürünlerin hatırlatılacağını hesaplar.
///
/// SKT'li ürünler için 3 gün önce, 1 gün önce ve son gün; TETT'li ürünler
/// için yalnızca son gün hatırlatılır. Aynı güne düşen hatırlatmalar tek
/// bildirimde toplanır (iOS en fazla 64 bekleyen bildirime izin verir).
List<ReminderDay> buildReminderPlan(
  Iterable<InventoryItem> items, {
  required DateTime now,
  required int hour,
  int maxDays = 30,
}) {
  final today = dateOnly(now);
  final byDay = <DateTime, List<String>>{};

  for (final item in items) {
    if (item.status != 'active') continue;
    final expiry = dateOnly(item.expiryDate);
    final offsets = item.dateType == DateType.skt ? const [3, 1, 0] : const [0];
    for (final offset in offsets) {
      final day = DateTime(expiry.year, expiry.month, expiry.day - offset);
      if (day.isBefore(today)) continue;
      final fireAt = DateTime(day.year, day.month, day.day, hour);
      if (!fireAt.isAfter(now)) continue;
      final String line;
      if (item.dateType == DateType.tett) {
        line = '${item.name}: TETT bugün doluyor, kontrol edip tüketebilirsiniz';
      } else if (offset == 0) {
        line = '${item.name}: bugün son gün';
      } else if (offset == 1) {
        line = '${item.name}: yarın son gün';
      } else {
        line = '${item.name}: $offset gün kaldı';
      }
      byDay.putIfAbsent(day, () => []).add(line);
    }
  }

  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days.take(maxDays))
      ReminderDay(fireAt: DateTime(day.year, day.month, day.day, hour), lines: byDay[day]!),
  ];
}

/// SKT hatırlatmalarını telefonun kendisinde zamanlar (sunucu gerekmez).
class NotificationService {
  NotificationService({this.enabled = true});

  /// Testlerde ve desteklenmeyen platformlarda hiçbir şey yapmayan örnek.
  NotificationService.disabled() : enabled = false;

  final bool enabled;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'expiry_reminders';
  static const _channelName = 'SKT hatırlatmaları';
  static const _channelDescription = 'Son tüketim tarihi yaklaşan ürünler için hatırlatmalar';
  static const _icon = 'ic_stat_kiler';

  static NotificationDetails _details(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: _icon,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  bool get isSupported =>
      enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('Bildirimler başlatılamadı: $error');
    }
  }

  /// Bildirim izni ister (Android 13+ ve iOS). İzin verildiyse true.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (error) {
      debugPrint('Bildirim izni istenemedi: $error');
      return false;
    }
  }

  /// Tüm hatırlatmaları silip güncel envantere göre yeniden kurar.
  Future<void> reschedule(List<InventoryItem> items, {required bool enabledByUser, required int hour}) async {
    if (!isSupported) return;
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      if (!enabledByUser) return;
      final plan = buildReminderPlan(items, now: DateTime.now(), hour: hour);
      for (var i = 0; i < plan.length; i++) {
        final day = plan[i];
        await _plugin.zonedSchedule(
          id: i + 1,
          title: day.title,
          body: day.body,
          // Yerel saat, aynı ana karşılık gelen UTC zamanına çevrilir
          scheduledDate: tz.TZDateTime.from(day.fireAt, tz.UTC),
          notificationDetails: _details(day.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      debugPrint('Hatırlatmalar zamanlanamadı: $error');
    }
  }

  /// Ayarlar ekranındaki "Test bildirimi gönder" düğmesi için.
  Future<void> showTest() async {
    if (!isSupported) return;
    await init();
    try {
      const body = 'Bildirimler çalışıyor! SKT hatırlatmaları bu şekilde gelecek.';
      await _plugin.show(id: 0, title: 'Mobil Kiler', body: body, notificationDetails: _details(body));
    } catch (error) {
      debugPrint('Test bildirimi gönderilemedi: $error');
    }
  }
}
