import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mobil_uygulamam/models/api_models.dart';
import 'package:mobil_uygulamam/screens/chat_screen.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/services/app_services.dart';
import 'package:mobil_uygulamam/theme.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  late final AppServices _services = AppScope.of(context);
  RecipeResult? _result;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipe();
  }

  Future<void> _fetchRecipe() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _services.api.suggestRecipe();
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Tarif Önerisi',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const _LoadingView()
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorBox(message: _error!, onRetry: _fetchRecipe),
            )
          : _buildResult(_result!),
    );
  }

  Widget _buildResult(RecipeResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.orange, Color(0xFFFF8F00)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.restaurant_rounded, color: Colors.white, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugün Ne Yapsak?',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Son tüketim tarihi yaklaşan ürünler önceliklendirildi',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: MarkdownBody(
              data: result.recipe,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.ink),
                h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.orange),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(initialRecipe: result.recipe))),
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Soru Sor / Sohbete Devam Et',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _fetchRecipe,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Başka bir tarif öner'),
            ),
          ),
          if (result.usedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Dikkate alınan malzemeler',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Son tüketim tarihi en yakın olan başta. SKT\'si geçmiş ürünler gıda güvenliği için gönderilmez.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ingredient in result.usedItems)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      ingredient,
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 24),
          const Text(
            'Yapay zekâ tarif hazırlıyor...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3),
          ),
        ],
      ),
    );
  }
}
