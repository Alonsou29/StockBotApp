import 'product.dart';

class DailyListItem {
  final int? id;
  final int productId;
  String hay;
  String action;
  String? quantityToBring;
  Product? product;

  DailyListItem({
    this.id,
    required this.productId,
    this.hay = '',
    this.action = 'NO',
    this.quantityToBring,
    this.product,
  });

  factory DailyListItem.fromJson(Map<String, dynamic> json) {
    return DailyListItem(
      id: json['id'] as int?,
      productId: json['product_id'] as int,
      hay: json['hay'] as String? ?? '',
      action: json['action'] as String? ?? 'NO',
      quantityToBring: json['quantity_to_bring'] as String?,
      product: json['product'] != null ? Product.fromJson(json['product'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'hay': hay,
      'action': action,
      'quantity_to_bring': quantityToBring,
    };
  }
}

class DailyList {
  final int? id;
  final DateTime listDate;
  final String? notes;
  final List<DailyListItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailyList({
    this.id,
    required this.listDate,
    this.notes,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory DailyList.fromJson(Map<String, dynamic> json) {
    return DailyList(
      id: json['id'] as int?,
      listDate: DateTime.parse(json['list_date'] as String),
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => DailyListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'list_date': listDate.toIso8601String().substring(0, 10),
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class DailyListSummary {
  final int id;
  final DateTime listDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailyListSummary({
    required this.id,
    required this.listDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DailyListSummary.fromJson(Map<String, dynamic> json) {
    return DailyListSummary(
      id: json['id'] as int,
      listDate: DateTime.parse(json['list_date'] as String),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}
