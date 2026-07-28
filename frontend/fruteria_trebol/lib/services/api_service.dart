import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/daily_list.dart';

class ApiService {
  // Ajusta esta URL segun donde corra el backend.
  // En emulador Android usa: http://10.0.2.2:8000
  // En iOS simulador/dispositivo fisico usa la IP de tu computadora.
  static const String baseUrl = 'https://stockbot.fruteriaeltrebol.com.ve';

  static Future<List<Product>> fetchProducts({String? category}) async {
    final uri = Uri.parse(baseUrl + '/products/').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Product.fromJson(e)).toList();
    }
    throw Exception('Error cargando productos: ${response.statusCode}');
  }

  static Future<Product> createProduct(String name, String category) async {
    final response = await http.post(
      Uri.parse(baseUrl + '/products/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'category': category}),
    );
    if (response.statusCode == 201) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error creando producto: ${response.statusCode} ${response.body}');
  }

  static Future<List<DailyListSummary>> fetchDailyLists() async {
    final response = await http.get(Uri.parse(baseUrl + '/daily-lists/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => DailyListSummary.fromJson(e)).toList();
    }
    throw Exception('Error cargando historial: ${response.statusCode}');
  }

  static Future<DailyList?> fetchDailyListByDate(DateTime date) async {
    final dateStr = _formatDate(date);
    final response = await http.get(Uri.parse('$baseUrl/daily-lists/by-date/$dateStr'));
    if (response.statusCode == 200) {
      return DailyList.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Error cargando lista del dia: ${response.statusCode}');
  }

  static Future<DailyList> fetchDailyListById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/daily-lists/$id'));
    if (response.statusCode == 200) {
      return DailyList.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error cargando lista: ${response.statusCode}');
  }

  static Future<DailyList> createDailyList(DailyList list) async {
    final response = await http.post(
      Uri.parse(baseUrl + '/daily-lists/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(list.toJson()),
    );
    if (response.statusCode == 201) {
      return DailyList.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 409) {
      throw Exception('Ya existe una lista para esta fecha. Guarda como actualizacion.');
    }
    throw Exception('Error creando lista: ${response.statusCode} ${response.body}');
  }

  static Future<DailyList> updateDailyList(int id, DailyList list) async {
    final response = await http.put(
      Uri.parse('$baseUrl/daily-lists/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(list.toJson()),
    );
    if (response.statusCode == 200) {
      return DailyList.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error actualizando lista: ${response.statusCode} ${response.body}');
  }

  static Future<void> deleteDailyList(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/daily-lists/$id'));
    if (response.statusCode != 204) {
      throw Exception('Error eliminando lista: ${response.statusCode}');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
