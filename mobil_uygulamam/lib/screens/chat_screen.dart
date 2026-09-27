import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mobil_uygulamam/models/api_models.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialRecipe, this.embedded = false});

  /// Tarif ekranından gelindiyse, sohbet bu tarif üzerinden devam eder.
  final String? initialRecipe;

  /// Alt menüde sekme olarak gösteriliyorsa geri butonu olmaz.
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _suggestions = [
    'Bugün dolabımdakilerle ne pişirebilirim?',
    'Açılmış süt buzdolabında kaç gün dayanır?',
    'Ekmeği bayatlatmadan nasıl saklarım?',
    'TETT geçmiş makarna yenir mi?',
  ];

  late final AppServices _services = AppScope.of(context);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final recipe = widget.initialRecipe;
    if (recipe != null && recipe.isNotEmpty) {
      _messages.add(ChatMessage(role: 'model', text: recipe));
    } else {
      _messages.add(
        const ChatMessage(
          role: 'model',
          isLocal: true,
          text:
              'Merhaba! 👋 Ben mutfak asistanınızım. Dolabınızdaki ürünleri biliyorum; tarifler, '
              'pişirme ipuçları ya da gıda saklama yöntemleri hakkında bana soru sorabilirsiniz.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || _isLoading) return;
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _isLoading = true;
    });
    _scrollToBottom();

    ChatMessage reply;
    try {
      reply = ChatMessage(role: 'model', text: await _services.api.chat(_messages));
    } on ApiException catch (error) {
      reply = ChatMessage(role: 'model', text: 'Üzgünüm, yanıt alınamadı. ${error.message}', isLocal: true);
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _messages.length == 1 && widget.initialRecipe == null;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 22, color: Colors.white70),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mutfak Asistanı',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingIndicator();
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          if (showSuggestions)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    ActionChip(label: Text(_suggestions[index]), onPressed: () => _sendMessage(_suggestions[index])),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Mesajınızı yazın...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.purple, Color(0xFF9C27B0)]),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      tooltip: 'Gönder',
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
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

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.purple, Color(0xFF9C27B0)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textColor = isUser ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) const _AssistantAvatar(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.purple : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: isUser
                  ? Text(message.text, style: TextStyle(color: textColor, fontSize: 15, height: 1.5))
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(p: TextStyle(color: textColor, fontSize: 15, height: 1.5)),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Noktalar sırayla yanıp söner: her nokta kendi evresinin ortasında en parlak.
  double _dotOpacity(int index) {
    final phase = (_controller.value - index / 3) % 1.0;
    final brightness = 1.0 - (phase - 0.5).abs() * 2;
    return 0.3 + 0.7 * brightness;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const _AssistantAvatar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Opacity(
                      opacity: _dotOpacity(i),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: Colors.grey.shade500, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
