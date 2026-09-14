import 'employee.dart';

class OdooProduct {
  final int id;
  final String name;
  final String? code;
  final double listPrice;
  final int? categoryId;
  final int? companyId;

  OdooProduct({
    required this.id,
    required this.name,
    this.code,
    this.listPrice = 0,
    this.categoryId,
    this.companyId,
  });

  factory OdooProduct.fromJson(Map<String, dynamic> json) {
    return OdooProduct(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['default_code'] as String?,
      listPrice: (json['list_price'] as num?)?.toDouble() ?? 0,
      categoryId: parseOdooId(json['categ_id']),
      companyId: parseOdooId(json['company_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'default_code': code,
      'list_price': listPrice,
      'categ_id': categoryId,
      'company_id': companyId,
    };
  }
}