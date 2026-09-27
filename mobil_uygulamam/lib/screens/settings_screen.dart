import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppServices _services = AppScope.of(context);
  late final TextEditingController _urlController = TextEditingController(text: _services.settings.baseUrl);
  late final TextEditingController _apiKeyController = TextEditingController(text: _services.settings.apiKey);
  bool _isTesting = false;
  bool? _connectionOk;
  String? _connectionMessage;
  bool _obscureKey = true;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    FocusScope.of(context).unfocus();
    final settings = _services.settings;
    await settings.setBaseUrl(_urlController.text);
    await settings.setApiKey(_apiKeyController.text);
    _urlController.text = settings.baseUrl;

    setState(() {
      _isTesting = true;
      _connectionMessage = null;
    });
    try {
      final aiReady = await _services.api.checkHealth();
      if (!mounted) return;
      setState(() {
        _connectionOk = true;
        _connectionMessage = aiReady
            ? 'Bağlantı başarılı. Yapay zekâ özellikleri hazır.'
            : 'Bağlantı başarılı, ancak sunucuda GEMINI_API_KEY tanımlı değil; tarif ve asistan çalışmaz.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionMessage = error.message;
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    if (enabled) {
      final granted = await _services.notifications.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim izni verilmedi. Telefon ayarlarından izin verebilirsiniz.')),
        );
      }
    }
    await _services.settings.setNotificationsEnabled(enabled);
    await _rescheduleFromCache();
  }

  Future<void> _setReminderHour(int hour) async {
    await _services.settings.setReminderHour(hour);
    await _rescheduleFromCache();
  }

  /// Ayar değişince hatırlatmaları son bilinen envantere göre hemen yeniden kurar.
  Future<void> _rescheduleFromCache() async {
    final cached = _services.cache.load();
    await _services.notifications.reschedule(
      cached?.items ?? const [],
      enabledByUser: _services.settings.notificationsEnabled,
      hour: _services.settings.reminderHour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _services.settings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Sunucu bağlantısı',
              icon: Icons.dns_rounded,
              children: [
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Sunucu adresi',
                    hintText: '192.168.1.5:8000',
                    helperText: 'Bilgisayarınızın yerel IP adresi ya da bulut sunucu adresi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'API anahtarı (isteğe bağlı)',
                    helperText: 'Sunucudaki APP_API_KEY ile aynı olmalı',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? 'Göster' : 'Gizle',
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(_obscureKey ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isTesting ? null : _saveAndTest,
                    icon: _isTesting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Kaydet ve bağlantıyı test et'),
                  ),
                ),
                if (_connectionMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _connectionOk == true ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: _connectionOk == true ? AppColors.good : AppColors.critical,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_connectionMessage!)),
                    ],
                  ),
                ],
              ],
            ),
            _Section(
              title: 'SKT hatırlatmaları',
              icon: Icons.notifications_active_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bildirim gönder'),
                  subtitle: const Text('SKT\'ye 3 gün, 1 gün kala ve son gün hatırlatır'),
                  value: settings.notificationsEnabled,
                  onChanged: _services.notifications.isSupported ? _setNotifications : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hatırlatma saati'),
                  trailing: DropdownButton<int>(
                    value: settings.reminderHour,
                    items: [
                      for (var hour = 6; hour <= 22; hour++)
                        DropdownMenuItem(value: hour, child: Text('${hour.toString().padLeft(2, '0')}:00')),
                    ],
                    onChanged: settings.notificationsEnabled
                        ? (hour) {
                            if (hour != null) _setReminderHour(hour);
                          }
                        : null,
                  ),
                ),
                if (!_services.notifications.isSupported)
                  Text(
                    'Bildirimler yalnızca Android ve iOS\'ta çalışır.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _services.notifications.showTest,
                      icon: const Icon(Icons.notifications_rounded),
                      label: const Text('Test bildirimi gönder'),
                    ),
                  ),
              ],
            ),
            _Section(
              title: 'Erişilebilirlik',
              icon: Icons.accessibility_new_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sesli geri bildirim'),
                  subtitle: const Text('Etiketten okunan tarihi sesli söyler (görme engelli kullanıcılar için)'),
                  value: settings.voiceFeedback,
                  onChanged: settings.setVoiceFeedback,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _services.speech.speak('Merhaba, ben Mobil Kiler. Sesli okuma çalışıyor.'),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Sesi dene'),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Hakkında',
              icon: Icons.info_outline_rounded,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('SKT ile TETT arasındaki fark'),
                  onTap: () => showDateTypeInfo(context),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.eco_rounded),
                  title: Text('Mobil Kiler 2.0'),
                  subtitle: Text('Gıda israfını azaltan akıllı kiler asistanı · Teknofest projesi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
