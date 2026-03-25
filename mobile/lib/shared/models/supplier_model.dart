class SupplierModel {
  final String id;
  final String name;
  final String? nit;
  final String? contactName;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  const SupplierModel({
    required this.id,
    required this.name,
    this.nit,
    this.contactName,
    this.phone,
    this.isActive = true,
    required this.createdAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'] as String,
        name: json['name'] as String,
        nit: json['nit'] as String?,
        contactName: json['contactName'] as String?,
        phone: json['phone'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
