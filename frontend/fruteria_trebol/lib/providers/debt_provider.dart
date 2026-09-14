import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/company.dart';
import '../models/debt.dart';
import '../models/employee.dart';
import '../models/odoo_product.dart';
import '../services/api_service.dart';

class DebtProvider extends ChangeNotifier {
  static const _companyKey = 'debt_selected_company_id';
  static const _companyNameKey = 'debt_selected_company_name';

  List<Company> _companies = [];
  List<Company> get companies => _companies;

  Company? _selectedCompany;
  Company? get selectedCompany => _selectedCompany;

  List<DebtorSummary> _debtors = [];
  List<DebtorSummary> get debtors => _debtors;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getInt(_companyKey);
    final companyName = prefs.getString(_companyNameKey);
    if (companyId != null && companyName != null) {
      _selectedCompany = Company(id: companyId, name: companyName);
      notifyListeners();
    }
  }

  Future<void> loadCompanies() async {
    _setLoading(true);
    try {
      _companies = await ApiService.fetchCompanies();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectCompany(Company company) async {
    _selectedCompany = company;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_companyKey, company.id);
    await prefs.setString(_companyNameKey, company.name);
    notifyListeners();
  }

  Future<void> loadDebtors({String? search, bool onlyWithBalance = true}) async {
    _setLoading(true);
    try {
      _debtors = await ApiService.fetchDebtorSummaries(
        companyId: _selectedCompany?.id,
        search: search,
        onlyWithBalance: onlyWithBalance,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Employee>> searchEmployees(String search) async {
    return ApiService.fetchEmployees(
      companyId: _selectedCompany?.id,
      search: search,
    );
  }

  Future<List<OdooProduct>> searchProducts(String search) async {
    return ApiService.fetchOdooProducts(
      companyId: _selectedCompany?.id,
      search: search,
    );
  }

  Future<Debt> createDebt({
    required Employee employee,
    required DateTime date,
    String? notes,
    required List<DebtItem> items,
  }) async {
    final company = _selectedCompany!;
    final debt = await ApiService.createDebt(
      odooEmployeeId: employee.odooId,
      companyId: company.id,
      companyName: company.name,
      employeeName: employee.name,
      identification: employee.identification,
      jobTitle: employee.jobTitle,
      date: date,
      notes: notes,
      items: items,
    );
    return debt;
  }

  Future<void> registerPayment({
    required DebtEmployee employee,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    final company = _selectedCompany!;
    await ApiService.createPayment(
      odooEmployeeId: employee.odooEmployeeId,
      companyId: company.id,
      companyName: company.name,
      employeeName: employee.name,
      identification: employee.identification,
      jobTitle: employee.jobTitle,
      amount: amount,
      date: date,
      notes: notes,
    );
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}