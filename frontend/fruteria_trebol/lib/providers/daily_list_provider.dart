import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/daily_list.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class DailyListProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> get products => _products;

  @visibleForTesting
  set products(List<Product> value) {
    _products = value;
    notifyListeners();
  }

  List<Product> get verduras =>
      _products.where((p) => p.category == 'verdura').toList();
  List<Product> get frutas =>
      _products.where((p) => p.category == 'fruta').toList();

  DailyList? _currentList;
  DailyList? get currentList => _currentList;

  @visibleForTesting
  set currentList(DailyList? value) {
    _currentList = value;
    if (value != null) {
      _initialSnapshot = _snapshot(value);
    }
    notifyListeners();
  }

  String? _initialSnapshot;
  bool get hasUnsavedChanges =>
      _currentList != null &&
      _initialSnapshot != null &&
      _snapshot(_currentList!) != _initialSnapshot;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _snapshot(DailyList list) => jsonEncode(list.toJson());

  Future<void> loadProducts() async {
    _setLoading(true);
    try {
      _products = await ApiService.fetchProducts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDailyListForDate(DateTime date) async {
    _setLoading(true);
    try {
      _currentList = await ApiService.fetchDailyListByDate(date);
      if (_currentList == null) {
        // Pre-crear items vacios para todos los productos
        final items = _products
            .map((p) => DailyListItem(productId: p.id, product: p))
            .toList();
        _currentList = DailyList(listDate: date, items: items);
      } else {
        // Asegurar que todos los productos activos aparezcan
        _currentList = _mergeWithAllProducts(_currentList!, date);
      }
      _initialSnapshot = _snapshot(_currentList!);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  DailyList _mergeWithAllProducts(DailyList existing, DateTime date) {
    final existingMap = {for (var item in existing.items) item.productId: item};
    final merged = _products.map((p) {
      if (existingMap.containsKey(p.id)) {
        final item = existingMap[p.id]!;
        item.product = p;
        return item;
      }
      return DailyListItem(productId: p.id, product: p);
    }).toList();
    return DailyList(
      id: existing.id,
      listDate: date,
      notes: existing.notes,
      items: merged,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
  }

  void updateItem(int productId,
      {String? hay, String? action, String? quantityToBring}) {
    if (_currentList == null) return;
    final item =
        _currentList!.items.firstWhere((i) => i.productId == productId);
    if (hay != null) item.hay = hay;
    if (action != null) item.action = action;
    if (quantityToBring != null) {
      item.quantityToBring = quantityToBring.isEmpty ? null : quantityToBring;
    }
    notifyListeners();
  }

  Future<void> saveDailyList() async {
    if (_currentList == null) return;
    _setLoading(true);
    try {
      if (_currentList!.id == null) {
        _currentList = await ApiService.createDailyList(_currentList!);
      } else {
        _currentList =
            await ApiService.updateDailyList(_currentList!.id!, _currentList!);
      }
      _currentList =
          _mergeWithAllProducts(_currentList!, _currentList!.listDate);
      _initialSnapshot = _snapshot(_currentList!);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void setNotes(String notes) {
    if (_currentList == null) return;
    _currentList = DailyList(
      id: _currentList!.id,
      listDate: _currentList!.listDate,
      notes: notes.isEmpty ? null : notes,
      items: _currentList!.items,
      createdAt: _currentList!.createdAt,
      updatedAt: _currentList!.updatedAt,
    );
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
