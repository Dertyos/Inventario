class CustomerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  const CustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.documentType,
    this.documentNumber,
    this.address,
    this.notes,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        documentType: json['documentType'] as String?,
        documentNumber: json['documentNumber'] as String?,
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
