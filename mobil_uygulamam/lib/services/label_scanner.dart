import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobil_uygulamam/services/expiry_date_parser.dart';

class LabelScanResult {
  const LabelScanResult({required this.text, this.expiry});

  /// Etiketten okunan tüm metin.
  final String text;

  /// Metinden bulunan son tüketim tarihi (bulunamadıysa null).
  final ExpiryParseResult? expiry;
}

/// Ürün etiketinin fotoğrafını çekip metni telefonun kendisinde (internetsiz)
/// okur ve son tüketim tarihini bulur.
class LabelScanner {
  /// ML Kit yalnızca Android ve iOS'ta çalışır.
  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Kullanıcı fotoğraf çekmekten vazgeçerse null döner.
  Future<LabelScanResult?> scan({ImageSource source = ImageSource.camera}) async {
    final photo = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 90);
    if (photo == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(InputImage.fromFilePath(photo.path));
      return LabelScanResult(text: recognized.text, expiry: ExpiryDateParser().parse(recognized.text));
    } finally {
      await recognizer.close();
    }
  }
}
