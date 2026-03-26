import 'product_model.dart';

class ProductLotModel {
  final String id;
  final String productId;
  final String? productName;
  final String lotNumber;
  final int quantity;
  final int soldQuantity;
  final DateTime? expirationDate;
  final DateTime? manufacturingDate;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const ProductLotModel({
    required this.id,
    required this.productId,
    this.productName,
    required this.lotNumber,
    required this.quantity,
    this.soldQuantity = 0,
    this.expirationDate,
    this.manufacturingDate,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  int get availableQuantity => quantity - soldQuantity;

  String get statusLabel {
    if (status == 'expired') return 'Expirado';
    if (status == 'depleted') return 'Agotado';
    if (isExpiringSoon(30)) return 'Por vencer';
    return 'Activo';
  }

  bool get isExpired => status == 'expired';

  bool get isDepleted => status == 'depleted';

  bool isExpiringSoon(int days) {
    if (expirationDate == null) return false;
    if (status != 'active') return false;
    final now = DateTime.now();
    final diff = expirationDate!.difference(now).inDays;
    return diff >= 0 && diff <= days;
  }

  factory ProductLotModel.fromJson(Map<String, dynamic> json) =>
      ProductLotModel(
        id: json['id'] as String,
        productId: json['productId'] as String? ??
            json['product']?['id'] as String? ??
            '',
        productName: json['product']?['name'] as String?,
        lotNumber: json['lotNumber'] as String,
        quantity: JsonParse.toInt(json['quantity']) ?? 0,
        soldQuantity: JsonParse.toInt(json['soldQuantity']) ?? 0,
        expirationDate: json['expirationDate'] != null
            ? DateTime.tryParse(json['expirationDate'] as String)
            : null,
        manufacturingDate: json['manufacturingDate'] != null
            ? DateTime.tryParse(json['manufacturingDate'] as String)
            : null,
        status: json['status'] as String? ?? 'active',
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
