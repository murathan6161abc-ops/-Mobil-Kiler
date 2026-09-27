import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

/// Etiket metninden bulunan son tüketim tarihi.
class ExpiryParseResult {
  const ExpiryParseResult({required this.date, required this.dateType, required this.matchedText});

  final DateTime date;

  /// Etikette "SKT" / "TETT" gibi bir ifade bulunamadıysa null.
  final DateType? dateType;

  /// Etikette tarihin okunduğu kısım (kullanıcıya göstermek için).
  final String matchedText;

  @override
  String toString() => 'ExpiryParseResult(${toIsoDate(date)}, ${dateType?.label}, "$matchedText")';
}

enum _Label { skt, tett, production }

class _Candidate {
  _Candidate(this.start, this.end, this.date);

  final int start;
  final int end;
  final DateTime date;
  _Label? label;
}

/// Türkçe gıda etiketlerindeki son tüketim tarihini OCR metninden ayıklar.
///
/// Desteklenen örnekler:
///   "SKT: 12.05.2027", "S.K.T. 12/05/27", "Son Tüketim Tarihi 12-05-2027",
///   "TETT: 05.2027" (ayın son günü alınır), "T.E.T.T 12 MAYIS 2027",
///   "EXP 2027-05-12", "BEST BEFORE 05/2027".
/// Üretim tarihleri ("ÜT", "Üretim Tarihi", "PROD", "MFG") yok sayılır.
class ExpiryDateParser {
  ExpiryDateParser({DateTime? today}) : _today = dateOnly(today ?? DateTime.now());

  final DateTime _today;

  static const Map<String, int> _monthNames = {
    'OCAK': 1,
    'SUBAT': 2,
    'MART': 3,
    'NISAN': 4,
    'MAYIS': 5,
    'HAZIRAN': 6,
    'TEMMUZ': 7,
    'AGUSTOS': 8,
    'EYLUL': 9,
    'EKIM': 10,
    'KASIM': 11,
    'ARALIK': 12,
    'OCA': 1,
    'SUB': 2,
    'MAR': 3,
    'NIS': 4,
    'MAY': 5,
    'HAZ': 6,
    'TEM': 7,
    'AGU': 8,
    'EYL': 9,
    'EKI': 10,
    'KAS': 11,
    'ARA': 12,
    'JAN': 1,
    'FEB': 2,
    'APR': 4,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  // Tarihlerin önünde aranan ifadeler (metin önce büyük harfe ve Türkçe
  // karakterler ASCII'ye çevrildikten sonra aranır).
  static final Map<_Label, RegExp> _labelPatterns = {
    _Label.tett: RegExp(r'T\s?\.?\s?E\s?\.?\s?T\s?\.?\s?T|TAVSIYE\s+EDILEN|BEST\s*BEFORE|\bBB\b|\bB\.B\b|EN\s+IYI'),
    _Label.skt: RegExp(
      r'S\s?\.?\s?K\s?\.?\s?T\b|\bS\s?\.?\s?T\s?\.?\s?T\b|SON\s+TUKETIM|SON\s+KULLANMA|SON\s+KUL\b|\bEXP|USE\s*BY|\bSKT',
    ),
    _Label.production: RegExp(
      r'URETIM|IMALAT|IMAL\b|\bU\s?\.?\s?T\b|\bURT\b|\bPROD|\bMFG|\bMFD|\bP\s?\.?\s?D\b|PACKED|AMBALAJLAMA',
    ),
  };

  static final RegExp _dayMonthYear = RegExp(r'(?<!\d)(\d{1,2})\s?[./\-]\s?(\d{1,2})\s?[./\-]\s?(\d{4}|\d{2})(?!\d)');
  static final RegExp _yearMonthDay = RegExp(r'(?<!\d)(\d{4})\s?[./\-]\s?(\d{1,2})\s?[./\-]\s?(\d{1,2})(?!\d)');
  // Ay adları uzundan kısaya sıralanır ki "MAYIS", "MAY"dan önce eşleşsin
  static final String _monthAlternation = (_monthNames.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
      .join('|');
  static final RegExp _dayMonthNameYear = RegExp(
    r'(?<![A-Z0-9])(\d{1,2})?\s?[./\-]?\s?(' + _monthAlternation + r')(?![A-Z])\.?\s?[./\-]?\s?(\d{4}|\d{2})(?!\d)',
  );
  static final RegExp _monthYear = RegExp(r'(?<![\d./\-])(\d{1,2})\s?[./\-]\s?(\d{4})(?![\d]|\s?[./\-]\s?\d)');
  static final RegExp _spacedDayMonthYear = RegExp(r'(?<!\d)(\d{1,2}) (\d{1,2}) (\d{4})(?!\d)');

  /// Metindeki en olası son tüketim tarihini döner; bulamazsa null.
  ExpiryParseResult? parse(String text) {
    if (text.trim().isEmpty) return null;
    final folded = _fixOcrDigits(_fold(text));
    final candidates = _findCandidates(folded);
    if (candidates.isEmpty) return null;

    _assignLabels(folded, candidates);
    final usable = candidates.where((candidate) => candidate.label != _Label.production).toList();
    if (usable.isEmpty) return null;

    final labeled = usable.where((candidate) => candidate.label != null).toList();
    // Etiketli tarih varsa onu, yoksa en geç tarihi seç (son tüketim tarihi
    // üretim tarihinden sonra gelir).
    final pool = labeled.isNotEmpty ? labeled : usable;
    pool.sort((a, b) => b.date.compareTo(a.date));
    final best = pool.first;

    final DateType? type = switch (best.label) {
      _Label.skt => DateType.skt,
      _Label.tett => DateType.tett,
      _ => null,
    };
    return ExpiryParseResult(date: best.date, dateType: type, matchedText: text.substring(best.start, best.end).trim());
  }

  // Tarihe benzeyen parçalar: aralarında nokta / eğik çizgi / tire olan 2-3
  // grup; her grupta en az bir gerçek rakam bulunur (ör. "12.O5.2O27").
  // Böylece "B.B." gibi kısaltmalar tarihle birleştirilmez.
  static const String _ocrGroup = r'(?=[0-9OILSBZ|]{0,3}\d)[0-9OILSBZ|]{1,4}';
  static final RegExp _dateLikeToken = RegExp('(?<![A-Z0-9])$_ocrGroup(?:\\s?[./\\-]\\s?$_ocrGroup){1,2}(?![A-Z0-9])');
  static const Map<String, String> _ocrDigitFixes = {
    'O': '0',
    'I': '1',
    'L': '1',
    '|': '1',
    'S': '5',
    'B': '8',
    'Z': '2',
  };

  /// Kamera ile okunan etiketlerde sık görülen harf-rakam karışıklıklarını
  /// (0 yerine O, 1 yerine I/l, 5 yerine S...) yalnızca tarihe benzeyen
  /// parçalarda düzeltir. Karakter sayısı değişmez.
  static String _fixOcrDigits(String folded) {
    return folded.replaceAllMapped(_dateLikeToken, (match) {
      final token = match[0]!;
      return token.split('').map((char) => _ocrDigitFixes[char] ?? char).join();
    });
  }

  /// Türkçe karakterleri ASCII'ye çevirip büyük harf yapar. Karakter sayısı
  /// korunur; böylece bulunan konumlar asıl metinde de geçerlidir.
  static String _fold(String text) {
    const map = {
      'ç': 'C',
      'Ç': 'C',
      'ğ': 'G',
      'Ğ': 'G',
      'ı': 'I',
      'İ': 'I',
      'i': 'I',
      'ö': 'O',
      'Ö': 'O',
      'ş': 'S',
      'Ş': 'S',
      'ü': 'U',
      'Ü': 'U',
    };
    final buffer = StringBuffer();
    for (final unit in text.split('')) {
      final mapped = map[unit];
      if (mapped != null) {
        buffer.write(mapped);
      } else {
        final upper = unit.toUpperCase();
        buffer.write(upper.length == 1 ? upper : unit);
      }
    }
    return buffer.toString();
  }

  List<_Candidate> _findCandidates(String folded) {
    final candidates = <_Candidate>[];
    final taken = List<bool>.filled(folded.length, false);

    void add(Match match, DateTime? date) {
      if (date == null) return;
      for (var i = match.start; i < match.end; i++) {
        if (taken[i]) return;
      }
      for (var i = match.start; i < match.end; i++) {
        taken[i] = true;
      }
      candidates.add(_Candidate(match.start, match.end, date));
    }

    for (final match in _yearMonthDay.allMatches(folded)) {
      add(match, _makeDate(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!)));
    }
    for (final match in _dayMonthYear.allMatches(folded)) {
      add(match, _makeDate(_year(match[3]!), int.parse(match[2]!), int.parse(match[1]!)));
    }
    for (final match in _spacedDayMonthYear.allMatches(folded)) {
      add(match, _makeDate(int.parse(match[3]!), int.parse(match[2]!), int.parse(match[1]!)));
    }
    for (final match in _dayMonthNameYear.allMatches(folded)) {
      final month = _monthNames[match[2]!]!;
      final year = _year(match[3]!);
      final day = match[1] != null ? int.parse(match[1]!) : null;
      add(match, day != null ? _makeDate(year, month, day) : _makeMonthEnd(year, month));
    }
    for (final match in _monthYear.allMatches(folded)) {
      add(match, _makeMonthEnd(int.parse(match[2]!), int.parse(match[1]!)));
    }

    candidates.sort((a, b) => a.start.compareTo(b.start));
    return candidates;
  }

  /// Her tarihe, önündeki en yakın "SKT / TETT / ÜT" ifadesini atar.
  /// İfade, bir önceki tarihten sonra ve en fazla 40 karakter geride olmalı.
  void _assignLabels(String folded, List<_Candidate> candidates) {
    var previousEnd = 0;
    for (final candidate in candidates) {
      final windowStart = candidate.start - 40 > previousEnd ? candidate.start - 40 : previousEnd;
      final window = folded.substring(windowStart, candidate.start);
      var bestPosition = -1;
      _Label? bestLabel;
      _labelPatterns.forEach((label, pattern) {
        for (final match in pattern.allMatches(window)) {
          if (match.start > bestPosition) {
            bestPosition = match.start;
            bestLabel = label;
          }
        }
      });
      candidate.label = bestLabel;
      previousEnd = candidate.end;
    }
  }

  static int _year(String value) => value.length == 2 ? 2000 + int.parse(value) : int.parse(value);

  DateTime? _makeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    // 31.02 gibi geçersiz tarihler DateTime tarafından sonraki aya kaydırılır
    if (date.month != month || date.day != day) return null;
    return _isPlausible(date) ? date : null;
  }

  DateTime? _makeMonthEnd(int year, int month) {
    if (month < 1 || month > 12) return null;
    final date = lastDayOfMonth(year, month);
    return _isPlausible(date) ? date : null;
  }

  bool _isPlausible(DateTime date) =>
      date.isAfter(DateTime(_today.year - 3)) && date.isBefore(DateTime(_today.year + 16));
}
