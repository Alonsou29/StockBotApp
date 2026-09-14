import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/daily_list.dart';
import '../models/company.dart';
import '../models/employee.dart';
import '../models/odoo_product.dart';
import '../models/debt.dart';

class ApiService {
  // Ajusta esta URL segun donde corra el backend.
  // En emulador Android usa: http://10.0.2.2:8000
  // En iOS simulador/dispositivo fisico usa la IP de tu computadora.
  static const String baseUrl = 'https://stockbot.fruteriaeltrebol.com.ve';

  static Future<List<Product>> fetchProducts({String? category}) async {
    final uri = Uri.parse('$baseUrl/products/').replace(
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
      Uri.parse('$baseUrl/products/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'category': category}),
    );
    if (response.statusCode == 201) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error creando producto: ${response.statusCode} ${response.body}');
  }

  static Future<List<DailyListSummary>> fetchDailyLists() async {
    final response = await http.get(Uri.parse('$baseUrl/daily-lists/'));
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
      Uri.parse('$baseUrl/daily-lists/'),
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

  // --------------------------
  // Odoo
  // --------------------------
  static Future<void> checkOdooHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/odoo/health'));
    if (response.statusCode != 200) {
      throw Exception('Odoo no disponible: ${response.statusCode} ${response.body}');
    }
  }

  static Future<List<Company>> fetchCompanies() async {
    final response = await http.get(Uri.parse('$baseUrl/odoo/companies'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Error cargando cedes: ${response.statusCode}');
  }

  static Future<List<Employee>> fetchEmployees({int? companyId, String? search}) async {
    final uri = Uri.parse('$baseUrl/odoo/employees').replace(
      queryParameters: {
        if (companyId != null) 'company_id': '$companyId',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Error cargando empleados: ${response.statusCode}');
  }

  static Future<List<OdooProduct>> fetchOdooProducts({int? companyId, String? search}) async {
    final uri = Uri.parse('$baseUrl/odoo/products').replace(
      queryParameters: {
        if (companyId != null) 'company_id': '$companyId',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => OdooProduct.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Error cargando productos: ${response.statusCode}');
  }

  // --------------------------
  // Deudas
  // --------------------------
  static Future<List<DebtorSummary>> fetchDebtorSummaries({
    int? companyId,
    String? search,
    bool onlyWithBalance = false,
  }) async {
    final uri = Uri.parse('$baseUrl/debts/employees').replace(
      queryParameters: {
        if (companyId != null) 'company_id': '$companyId',
        if (search != null && search.isNotEmpty) 'search': search,
        if (onlyWithBalance) 'only_with_balance': 'true',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => DebtorSummary.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Error cargando deudores: ${response.statusCode}');
  }

  static Future<EmployeeAccount> fetchEmployeeAccount(int employeeId) async {
    final response = await http.get(Uri.parse('$baseUrl/debts/employees/$employeeId'));
    if (response.statusCode == 200) {
      return EmployeeAccount.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error cargando cuenta: ${response.statusCode}');
  }

  static Future<Debt> createDebt({
    required int odooEmployeeId,
    required int companyId,
    required String companyName,
    required String employeeName,
    String? identification,
    String? jobTitle,
    required DateTime date,
    String? notes,
    required List<DebtItem> items,
  }) async {
    final body = jsonEncode({
      'odoo_employee_id': odooEmployeeId,
      'company_id': companyId,
      'company_name': companyName,
      'employee_name': employeeName,
      'identification': identification,
      'job_title': jobTitle,
      'debt_date': _formatDate(date),
      'notes': notes,
      'items': items.map((i) => i.toCreateJson()).toList(),
    });
    final response = await http.post(
      Uri.parse('$baseUrl/debts/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 201) {
      return Debt.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error creando deuda: ${response.statusCode} ${response.body}');
  }

  static Future<DebtPayment> createPayment({
    required int odooEmployeeId,
    required int companyId,
    required String companyName,
    required String employeeName,
    String? identification,
    String? jobTitle,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    final body = jsonEncode({
      'odoo_employee_id': odooEmployeeId,
      'company_id': companyId,
      'company_name': companyName,
      'employee_name': employeeName,
      'identification': identification,
      'job_title': jobTitle,
      'amount': amount,
      'payment_date': _formatDate(date),
      'notes': notes,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/debts/payments'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 201) {
      return DebtPayment.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error registrando abono: ${response.statusCode} ${response.body}');
  }
}
