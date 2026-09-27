import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobil_uygulamam/screens/product_form_screen.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';
import 'package:mobil_uygulamam/theme.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final AppServices _services = AppScope.of(context);
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastRejected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    if (value.length > 64) {
      // Web adresi gibi uzun QR kodları ürün barkodu değildir
      if (_lastRejected != value) {
        _lastRejected = value;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bu kod bir ürün barkodu değil. Ürünün barkodunu okutun.')));
      }
      return;
    }
    _openForm(value);
  }

  Future<void> _openForm(String barcode) async {
    _isProcessing = true;
    // Form açıkken kamera boşuna çalışıp pil tüketmesin
    await _stopCamera();
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(barcode: barcode)),
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.pop(context, true);
      return;
    }
    _isProcessing = false;
    await _startCamera();
  }

  Future<void> _showManualEntryDialog() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _ManualBarcodeDialog());
    if (code != null && code.isNotEmpty && mounted) _openForm(code);
  }

  /// Görme engelli kullanıcılar için: etiketin fotoğrafını çekip tarihi sesli okur.
  Future<void> _readDateAloud() async {
    _isProcessing = true;
    await _stopCamera();
    try {
      final result = await _services.labelScanner.scan();
      if (!mounted || result == null) return;
      final expiry = result.expiry;
      final message = expiry == null
          ? 'Etikette tarih bulunamadı. Tarih yazan kısmı daha yakından çekmeyi deneyin.'
          : buildDateSpeech(expiry.date, expiry.dateType);
      _services.speech.speak(message);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(expiry == null ? 'Tarih bulunamadı' : formatLongDate(expiry.date)),
          content: Text(expiry == null ? message : '$message\n\nEtiketten okunan: "${expiry.matchedText}"'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Etiket okunamadı: $error')));
      }
    } finally {
      _services.speech.stop();
      if (mounted) {
        _isProcessing = false;
        await _startCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Kodu Okutun',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
            tooltip: 'Barkodu elle gir',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _ScannerError(error: error),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withAlpha(150), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'QR kodu veya barkodu çerçeveye hizalayın',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openForm(''),
                          icon: const Icon(Icons.eco_rounded),
                          label: const Text('Barkodsuz ekle'),
                        ),
                      ),
                      if (_services.labelScanner.isSupported) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _readDateAloud,
                            icon: const Icon(Icons.record_voice_over_rounded),
                            label: const Text('Tarihi sesli oku'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = error.errorCode == MobileScannerErrorCode.permissionDenied
        ? 'Kamera izni verilmedi. Telefon ayarlarından Mobil Kiler için kamera iznini açın '
              'ya da sağ üstteki klavye simgesiyle barkodu elle girin.'
        : 'Kamera açılamadı. Barkodu sağ üstteki klavye simgesiyle elle girebilirsiniz.';
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.keyboard_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Text('Manuel Giriş'),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 64,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Barkod veya QR kod numarası',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submit,
          child: const Text('Devam'),
        ),
      ],
    );
  }
}
