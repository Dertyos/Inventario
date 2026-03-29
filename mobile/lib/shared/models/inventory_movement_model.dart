import 'product_model.dart';

class InventoryMovementModel {
  final String id;
  final String type;
  final int quantity;
  final double? unitCost;
  final double? totalCost;
  final String? reason;
  final String productId;
  final String? productName;
  final String? supplierId;
  final String? supplierName;
  final String? lotId;
  final String? lotNumber;
  final int stockBefore;
  final int stockAfter;
  final DateTime createdAt;

  const InventoryMovementModel({
    required this.id,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.totalCost,
    this.reason,
    required this.productId,
    this.productName,
    this.supplierId,
    this.supplierName,
    this.lotId,
    this.lotNumber,
    this.stockBefore = 0,
    this.stockAfter = 0,
    required this.createdAt,
  });

  bool get canDelete => type == 'in' || type == 'out';

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) =>
      InventoryMovementModel(
        id: json['id'] as String,
        type: json['type'] as String,
        quantity: JsonParse.toInt(json['quantity']) ?? 0,
        unitCost: JsonParse.toDouble(json['unitCost']),
        totalCost: JsonParse.toDouble(json['totalCost']),
        reason: json['reason'] as String?,
        productId: json['productId'] as String? ??
            json['product']?['id'] as String? ??
            '',
        productName: json['product']?['name'] as String?,
        supplierId: json['supplierId'] as String?,
        supplierName: json['supplier']?['name'] as String?,
        lotId: json['lotId'] as String?,
        lotNumber: json['lot']?['lotNumber'] as String?,
        stockBefore: JsonParse.toInt(json['stockBefore']) ?? 0,
        stockAfter: JsonParse.toInt(json['stockAfter']) ?? 0,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  String get typeLabel {
    switch (type) {
      case 'in':
        return 'Entrada';
      case 'out':
        return 'Salida';
      case 'adjustment':
        return 'Corrección de conteo';
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
