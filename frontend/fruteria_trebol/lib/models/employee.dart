class Employee {
  final int odooId;
  final String name;
  final String? identification;
  final String? jobTitle;
  final int? companyId;
  final bool active;

  Employee({
    required this.odooId,
    required this.name,
    this.identification,
    this.jobTitle,
    this.companyId,
    this.active = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      odooId: json['id'] as int,
      name: odooString(json['name']) ?? '',
      identification: odooString(json['identification_id']),
      jobTitle: odooString(json['job_title']),
      companyId: parseOdooId(json['company_id']),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': odooId,
      'name': name,
      'identification_id': identification,
      'job_title': jobTitle,
      'company_id': companyId,
      'active': active,
    };
  }
}

int? parseOdooId(dynamic value) {
  if (value is int) return value;
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is int) return first;
  }
  return null;
}

String? odooString(dynamic value) {
  if (value == null || value is bool) return null;
  return value.toString();
}