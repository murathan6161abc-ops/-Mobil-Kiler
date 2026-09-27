import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının kısaca yazdığı "192.168.1.5:8000" gibi adresleri
/// "http://192.168.1.5:8000/api" biçimine getirir.
String normalizeBaseUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  if (!url.contains('://')) url = 'http://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (!url.endsWith('/api')) url = '$url/api';
  return url;
}

/// Telefonda saklanan uygulama ayarları.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  /// Derleme sırasında değiştirilebilir:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.2:8000/api',
  );
  static const String defaultApiKey = String.fromEnvironment('APP_API_KEY');

  static const _baseUrlKey = 'base_url';
  static const _apiKeyKey = 'api_key';
  static const _notificationsKey = 'notifications_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _voiceFeedbackKey = 'voice_feedback';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async => AppSettings(await SharedPreferences.getInstance());

  String get baseUrl => normalizeBaseUrl(_prefs.getString(_baseUrlKey) ?? defaultBaseUrl);

  Future<void> setBaseUrl(String value) async {
    final normalized = normalizeBaseUrl(value);
    if (normalized.isEmpty) {
      await _prefs.remove(_baseUrlKey);
    } else {
      await _prefs.setString(_baseUrlKey, normalized);
    }
    notifyListeners();
  }

  String get apiKey => _prefs.getString(_apiKeyKey) ?? defaultApiKey;

  Future<void> setApiKey(String value) async {
    await _prefs.setString(_apiKeyKey, value.trim());
    notifyListeners();
  }

  bool get notificationsEnabled => _prefs.getBool(_notificationsKey) ?? true;

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }

  /// Hatırlatmaların gönderileceği saat (0-23).
  int get reminderHour => _prefs.getInt(_reminderHourKey) ?? 9;

  Future<void> setReminderHour(int value) async {
    await _prefs.setInt(_reminderHourKey, value.clamp(0, 23));
    notifyListeners();
  }

  /// Erişilebilirlik: okunan tarihlerin ve özetlerin sesli söylenmesi.
  bool get voiceFeedback => _prefs.getBool(_voiceFeedbackKey) ?? false;

  Future<void> setVoiceFeedback(bool value) async {
    await _prefs.setBool(_voiceFeedbackKey, value);
    notifyListeners();
  }
}
