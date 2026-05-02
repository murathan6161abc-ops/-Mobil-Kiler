import 'package:flutter/material.dart';
import 'package:mobil_uygulamam/services/api_service.dart';
import 'package:mobil_uygulamam/screens/chat_screen.dart';

class RecipeScreen extends StatefulWidget {
  final List<String> ingredients;

  const RecipeScreen({super.key, required this.ingredients});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final ApiService _apiService = ApiService();
  String _recipe = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipe();
  }

  Future<void> _fetchRecipe() async {
    try {
      final suggestion = await _apiService.getRecipeSuggestion(widget.ingredients);
      setState(() {
        _recipe = suggestion;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _recipe = 'Tarif alınırken bir hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI Tarif Önerisi', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, size: 48, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gemini tarif hazırlıyor...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFFE65100), strokeWidth: 3)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                      ),
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
                              Text('Bugün Ne Yapsak?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                              SizedBox(height: 4),
                              Text('Yapay zeka dolabınızı inceledi', style: TextStyle(fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarif İçeriği
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      _recipe,
                      style: const TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF37474F)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sohbete Devam Et Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(initialRecipe: _recipe),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('Soru Sor / Sohbete Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Kullanılan Malzemeler
                  const Text('Elinizdeki Malzemeler', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF37474F))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.ingredients
                        .map((ing) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(ing, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
