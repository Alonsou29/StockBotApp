class DebtEmployee {
  final int id;
  final int odooEmployeeId;
  final int companyId;
  final String? companyName;
  final String name;
  final String? identification;
  final String? jobTitle;
  final bool active;

  DebtEmployee({
    required this.id,
    required this.odooEmployeeId,
    required this.companyId,
    this.companyName,
    required this.name,
    this.identification,
    this.jobTitle,
    this.active = true,
  });

  factory DebtEmployee.fromJson(Map<String, dynamic> json) {
    return DebtEmployee(
      id: json['id'] as int,
      odooEmployeeId: json['odoo_employee_id'] as int,
      companyId: json['company_id'] as int,
      companyName: json['company_name'] as String?,
      name: json['name'] as String? ?? '',
      identification: json['identification'] as String?,
      jobTitle: json['job_title'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

class DebtItem {
  final int? id;
  final int? debtId;
  final int odooProductId;
  final String productName;
  final String? productCode;
  final double unitPrice;
  final double quantity;
  final double subtotal;

  DebtItem({
    this.id,
    this.debtId,
    required this.odooProductId,
    required this.productName,
    this.productCode,
    required this.unitPrice,
    this.quantity = 1,
    this.subtotal = 0,
  });

  factory DebtItem.fromJson(Map<String, dynamic> json) {
    return DebtItem(
      id: json['id'] as int?,
      debtId: json['debt_id'] as int?,
      odooProductId: json['odoo_product_id'] as int,
      productName: json['product_name'] as String? ?? '',
      productCode: json['product_code'] as String?,
      unitPrice: _toDouble(json['unit_price']),
      quantity: _toDouble(json['quantity']),
      subtotal: _toDouble(json['subtotal']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'odoo_product_id': odooProductId,
      'product_name': productName,
      'product_code': productCode,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }
}

class Debt {
  final int? id;
  final int? employeeId;
  final int companyId;
  final DateTime? debtDate;
  final String? notes;
  final double total;
  final DebtEmployee? employee;
  final List<DebtItem> items;

  Debt({
    this.id,
    this.employeeId,
    required this.companyId,
    this.debtDate,
    this.notes,
    this.total = 0,
    this.employee,
    this.items = const [],
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as int?,
      employeeId: json['employee_id'] as int?,
      companyId: (json['company_id'] as int?) ?? 0,
      debtDate: json['debt_date'] != null
          ? DateTime.tryParse(json['debt_date'] as String)
          : null,
      notes: json['notes'] as String?,
      total: _toDouble(json['total']),
      employee: json['employee'] != null
          ? DebtEmployee.fromJson(json['employee'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => DebtItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DebtPayment {
  final int? id;
  final int? employeeId;
  final int companyId;
  final double amount;
  final DateTime? paymentDate;
  final String? notes;

  DebtPayment({
    this.id,
    this.employeeId,
    required this.companyId,
    required this.amount,
    this.paymentDate,
    this.notes,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as int?,
      employeeId: json['employee_id'] as int?,
      companyId: (json['company_id'] as int?) ?? 0,
      amount: _toDouble(json['amount']),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class DebtorSummary {
  final DebtEmployee employee;
  final double totalCharged;
  final double totalPaid;
  final double balance;

  DebtorSummary({
    required this.employee,
    required this.totalCharged,
    required this.totalPaid,
    required this.balance,
  });

  factory DebtorSummary.fromJson(Map<String, dynamic> json) {
    return DebtorSummary(
      employee:
          DebtEmployee.fromJson(json['employee'] as Map<String, dynamic>),
      totalCharged: _toDouble(json['total_charged']),
      totalPaid: _toDouble(json['total_paid']),
      balance: _toDouble(json['balance']),
    );
  }
}

class EmployeeAccount {
  final DebtEmployee employee;
  final double balance;
  final double totalCharged;
  final double totalPaid;
  final List<Debt> debts;
  final List<DebtPayment> payments;

  EmployeeAccount({
    required this.employee,
    required this.balance,
    required this.totalCharged,
    required this.totalPaid,
    required this.debts,
    required this.payments,
  });

  factory EmployeeAccount.fromJson(Map<String, dynamic> json) {
    return EmployeeAccount(
      employee:
          DebtEmployee.fromJson(json['employee'] as Map<String, dynamic>),
      balance: _toDouble(json['balance']),
      totalCharged: _toDouble(json['total_charged']),
      totalPaid: _toDouble(json['total_paid']),
      debts: (json['debts'] as List<dynamic>? ?? [])
          .map((e) => Debt.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((e) => DebtPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}