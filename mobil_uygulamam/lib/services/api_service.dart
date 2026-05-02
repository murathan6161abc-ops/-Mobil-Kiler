import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Bilgisayarınızın yerel IP adresini kullanıyoruz ki telefondan erişilebilsin
  final String baseUrl = 'http://192.168.1.2:8000/api';

  Future<List<dynamic>> getInventory() async {
    final response = await http.get(Uri.parse('$baseUrl/inventory/'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Envanter yüklenirken hata oluştu');
    }
  }

  Future<void> addInventoryItem(String barcode, String name, String date) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'barcode': barcode,
        'name': name,
        'expiry_date': date,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Ürün eklenirken hata oluştu');
    }
  }

  Future<String> getRecipeSuggestion(List<String> ingredients) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suggest-recipe/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'available_ingredients': ingredients,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data['recipe'];
    } else {
      throw Exception('Tarif alınırken hata oluştu');
    }
  }

  Future<void> deleteInventoryItem(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/inventory/$id'),
    );
    if (response.statusCode != 200) {
      throw Exception('Ürün silinirken hata oluştu');
    }
  }

  Future<void> updateInventoryItem(int id, String barcode, String name, String date) async {
    final response = await http.put(
      Uri.parse('$baseUrl/inventory/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'barcode': barcode,
        'name': name,
        'expiry_date': date,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Ürün güncellenirken hata oluştu');
    }
  }

  Future<String> chatWithAI(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'messages': messages}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data['reply'];
    } else {
      throw Exception('Sohbet sırasında hata oluştu');
    }
  }
}
