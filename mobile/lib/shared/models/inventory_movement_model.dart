import 'product_model.dart';

class InventoryMovementModel {
  final String id;
  final String type;
  final int quantity;
  final String? reason;
  final String productId;
  final String? productName;
  final DateTime createdAt;

  const InventoryMovementModel({
    required this.id,
    required this.type,
    required this.quantity,
    this.reason,
    required this.productId,
    this.productName,
    required this.createdAt,
  });

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) =>
      InventoryMovementModel(
        id: json['id'] as String,
        type: json['type'] as String,
        quantity: JsonParse.toInt(json['quantity']) ?? 0,
        reason: json['reason'] as String?,
        productId: json['productId'] as String? ??
            json['product']?['id'] as String? ??
            '',
        productName: json['product']?['name'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get typeLabel {
    switch (type) {
      case 'in':
        return 'Entrada';
      case 'out':
        return 'Salida';
      case 'adjustment':
        return 'Ajuste';
      case 'sale':
        return 'Venta';
      case 'purchase':
        return 'Compra';
      case 'return':
        return 'Devolución';
      default:
        return type;
    }
  }

  bool get isPositive => type == 'in' || type == 'purchase' || type == 'return';
}
