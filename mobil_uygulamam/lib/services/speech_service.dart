import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

/// Envanterin sesli özeti (görme engelli kullanıcılar için).
String buildInventorySpeech(List<InventoryItem> items, {DateTime? today}) {
  if (items.isEmpty) return 'Dolabınız boş.';
  final expired = <String>[];
  final tettPassed = <String>[];
  final lastDay = <String>[];
  final soon = <String>[];
  for (final item in items) {
    switch (item.level(today: today)) {
      case ExpiryLevel.expired:
        expired.add(item.name);
      case ExpiryLevel.tettPassed:
        tettPassed.add(item.name);
      case ExpiryLevel.lastDay:
        lastDay.add(item.name);
      case ExpiryLevel.soon:
        soon.add(item.name);
      case ExpiryLevel.week:
      case ExpiryLevel.fresh:
        break;
    }
  }
  final parts = <String>['Dolabınızda ${items.length} ürün var.'];
  if (expired.isNotEmpty) parts.add('Son tüketim tarihi geçmiş, tüketmeyin: ${expired.join(', ')}.');
  if (tettPassed.isNotEmpty) parts.add('Tavsiye edilen tarihi geçmiş, kontrol edin: ${tettPassed.join(', ')}.');
  if (lastDay.isNotEmpty) parts.add('Bugün son gün: ${lastDay.join(', ')}.');
  if (soon.isNotEmpty) parts.add('Üç gün içinde bitecek: ${soon.join(', ')}.');
  if (parts.length == 1) parts.add('Süresi yaklaşan ürün yok.');
  return parts.join(' ');
}

/// Etiketten okunan tarihin sesli ifadesi.
String buildDateSpeech(DateTime date, DateType? type, {DateTime? today}) {
  final label = type?.longLabel ?? 'Tarih';
  final days = daysBetween(today ?? DateTime.now(), date);
  final String remaining;
  if (days < 0) {
    remaining = type == DateType.tett
        ? 'Tarihi ${-days} gün önce geçmiş, kontrol ederek tüketebilirsiniz.'
        : 'Tarihi ${-days} gün önce geçmiş, tüketmeyin.';
  } else if (days == 0) {
    remaining = 'Bugün son gün.';
  } else {
    remaining = '$days gün kaldı.';
  }
  return '$label ${formatLongDate(date)}. $remaining';
}

class SpeechService {
  FlutterTts? _tts;

  Future<void> speak(String text) async {
    try {
      var tts = _tts;
      if (tts == null) {
        tts = FlutterTts();
        await tts.setLanguage('tr-TR');
        await tts.setSpeechRate(0.45);
        _tts = tts;
      }
      await tts.stop();
      await tts.speak(text);
    } catch (error) {
      debugPrint('Sesli okuma yapılamadı: $error');
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
