import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobil_uygulamam/models/inventory_item.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/services/speech_service.dart';
import 'package:mobil_uygulamam/theme.dart';
import 'package:mobil_uygulamam/utils/dates.dart';

/// Ürün ekleme (barkod ile ya da barkodsuz) ve düzenleme formu.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.item, this.barcode = ''});

  /// Düzenlenen ürün; null ise yeni ürün eklenir.
  final InventoryItem? item;

  /// Yeni ürün için okunan barkod (barkodsuz ürünlerde boş).
  final String barcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static final DateTime _firstDate = DateTime(2000);
  static final DateTime _lastDate = DateTime(2100, 12, 31);

  late final AppServices _services = AppScope.of(context);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  late DateTime _expiryDate;
  DateType _dateType = DateType.skt;
  StorageLocation _location = StorageLocation.dolap;
  String _unit = 'adet';
  String? _category;

  bool _isSaving = false;
  String? _errorMessage;
  bool _isLookingUp = false;
  String? _lookupNote;
  bool _isReadingLabel = false;
  String? _labelNote;

  bool get _isEditing => widget.item != null;

  String get _barcode => widget.item?.barcode ?? widget.barcode;

  Color get _accent => _isEditing ? AppColors.blue : AppColors.primary;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _quantityController.text = formatQuantity(item.quantity).replaceAll(',', '.');
      _expiryDate = item.expiryDate;
      _dateType = item.dateType;
      _location = item.location;
      _unit = itemUnits.contains(item.unit) ? item.unit : 'adet';
      _category = item.category;
    } else {
      _expiryDate = dateOnly(DateTime.now()).add(const Duration(days: 7));
      if (widget.barcode.isNotEmpty) _lookupProduct();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Barkoddan ürün adını ve kategorisini otomatik doldurur.
  Future<void> _lookupProduct() async {
    setState(() => _isLookingUp = true);
    try {
      final info = await _services.api.lookupProduct(widget.barcode);
      if (!mounted) return;
      setState(() {
        if (info == null) {
          _lookupNote = 'Bu barkod kayıtlı değil. Bilgileri girdiğinizde bir dahaki sefere otomatik dolacak.';
          return;
        }
        if (_nameController.text.trim().isEmpty) _nameController.text = info.name;
        _category ??= info.category;
        _lookupNote = info.source == 'openfoodfacts'
            ? 'Ürün bilgisi Open Food Facts veritabanından dolduruldu.'
            : 'Bu ürün daha önce eklenmiş; bilgiler otomatik dolduruldu.';
      });
    } on ApiException {
      // Ürün bilgisi bulunamasa da kullanıcı elle girebilir
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<void> _pickDate() async {
    var initial = _expiryDate;
    if (initial.isBefore(_firstDate)) initial = _firstDate;
    if (initial.isAfter(_lastDate)) initial = _lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _firstDate,
      lastDate: _lastDate,
      helpText: '${_dateType.longLabel} seçin',
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  /// Etiketin fotoğrafından son tüketim tarihini okur (telefonda, internetsiz).
  Future<void> _readLabel() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Etiketin fotoğrafını çek'),
              subtitle: const Text('Tarih yazan kısmı yakından ve net çekin'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() {
      _isReadingLabel = true;
      _labelNote = null;
    });
    try {
      final result = await _services.labelScanner.scan(source: source);
      if (!mounted || result == null) return;
      final expiry = result.expiry;
      if (expiry == null) {
        setState(
          () => _labelNote = 'Etikette tarih bulunamadı. Daha yakından çekmeyi deneyin ya da tarihi elle seçin.',
        );
        if (_services.settings.voiceFeedback) _services.speech.speak('Etikette tarih bulunamadı.');
        return;
      }
      setState(() {
        _expiryDate = expiry.date;
        if (expiry.dateType != null) _dateType = expiry.dateType!;
        _labelNote = 'Etiketten okundu: "${expiry.matchedText}". Lütfen doğruluğunu kontrol edin.';
      });
      if (_services.settings.voiceFeedback) {
        _services.speech.speak(buildDateSpeech(expiry.date, expiry.dateType));
      }
    } catch (error) {
      if (mounted) setState(() => _labelNote = 'Etiket okunamadı: $error');
    } finally {
      if (mounted) setState(() => _isReadingLabel = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Lütfen ürün adını girin.');
      return;
    }
    final quantity = double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'Lütfen geçerli bir miktar girin (ör. 1 ya da 0,5).');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final draft = InventoryItemDraft(
      barcode: _barcode,
      name: name,
      category: _category,
      expiryDate: _expiryDate,
      dateType: _dateType,
      quantity: quantity,
      unit: _unit,
      location: _location,
    );

    try {
      if (_isEditing) {
        await _services.api.updateItem(widget.item!.id, draft);
      } else {
        await _services.api.addItem(draft);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? '$name güncellendi!' : '$name envantere eklendi!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [...itemCategories, if (_category != null && !itemCategories.contains(_category)) _category!];
    final daysLeft = daysBetween(DateTime.now(), _expiryDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _isEditing ? AppColors.blue : AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_barcode.isNotEmpty) ...[
              _BarcodeCard(barcode: _barcode, color: _accent, isLookingUp: _isLookingUp, note: _lookupNote),
              const SizedBox(height: 24),
            ],

            const FieldLabel('Ürün adı'),
            _Panel(
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditing && _barcode.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: InputDecoration(
                  hintText: 'Örn: Süt, Yumurta, Domates',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.fastfood_rounded, color: _accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 20),

            const FieldLabel('Kategori'),
            _Panel(
              child: DropdownButtonFormField<String?>(
                key: ValueKey(_category),
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.category_rounded, color: _accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Seçilmedi')),
                  for (final category in categories) DropdownMenuItem<String?>(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
            ),
            const SizedBox(height: 20),

            const FieldLabel('Miktar'),
            Row(
              children: [
                Expanded(
                  child: _Panel(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.scale_rounded, color: _accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Panel(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [for (final unit in itemUnits) DropdownMenuItem(value: unit, child: Text(unit))],
                      onChanged: (value) => setState(() => _unit = value ?? 'adet'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const FieldLabel('Nerede saklanıyor?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final location in StorageLocation.values)
                  ChoiceChip(
                    avatar: Icon(locationIcon(location), size: 18),
                    label: Text(location.label),
                    selected: _location == location,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _location = location),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            FieldLabel(
              'Etiketteki tarih türü',
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'SKT ile TETT farkı nedir?',
                onPressed: () => showDateTypeInfo(context),
                icon: Icon(Icons.info_outline_rounded, color: _accent),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DateType>(
                segments: const [
                  ButtonSegment(value: DateType.skt, label: Text('SKT (son tüketim)')),
                  ButtonSegment(value: DateType.tett, label: Text('TETT (tavsiye)')),
                ],
                selected: {_dateType},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _dateType = selection.first),
              ),
            ),
            const SizedBox(height: 20),

            FieldLabel(_dateType.longLabel),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: _Panel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatShortDate(_expiryDate),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          Text(
                            daysLeft < 0
                                ? '${-daysLeft} gün önce geçti'
                                : daysLeft == 0
                                ? 'Bugün'
                                : '$daysLeft gün sonra',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _accent.withAlpha(15), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Değiştir',
                        style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_services.labelScanner.isSupported) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isReadingLabel ? null : _readLabel,
                  icon: _isReadingLabel
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.document_scanner_rounded),
                  label: Text(_isReadingLabel ? 'Etiket okunuyor...' : 'Tarihi etiketten oku (kamera)'),
                ),
              ),
            ],
            if (_labelNote != null) ...[
              const SizedBox(height: 8),
              Text(_labelNote!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],

            if (_errorMessage != null) ...[const SizedBox(height: 20), ErrorBox(message: _errorMessage!)],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: _accent.withAlpha(100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isEditing ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _isEditing ? 'Güncelle' : 'Envantere Ekle',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _BarcodeCard extends StatelessWidget {
  const _BarcodeCard({required this.barcode, required this.color, required this.isLookingUp, this.note});

  final String barcode;
  final Color color;
  final bool isLookingUp;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.qr_code_rounded, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barkod', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      barcode,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              if (isLookingUp) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          if (isLookingUp || note != null) ...[
            const SizedBox(height: 10),
            Text(
              isLookingUp ? 'Ürün bilgisi aranıyor...' : note!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
