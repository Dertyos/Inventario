import 'product_model.dart';

class PurchaseModel {
  final String id;
  final String purchaseNumber;
  final String supplierId;
  final String? supplierName;
  final double total;
  final String status;
  final String? notes;
  final String? receivedAt;
  final List<PurchaseItemModel> items;
  final DateTime createdAt;

  const PurchaseModel({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    this.supplierName,
    required this.total,
    required this.status,
    this.notes,
    this.receivedAt,
    this.items = const [],
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isReceived => status == 'received';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'received':
        return 'Recibida';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  factory PurchaseModel.fromJson(Map<String, dynamic> json) => PurchaseModel(
        id: json['id'] as String,
        purchaseNumber: json['purchaseNumber'] as String? ?? '',
        supplierId: json['supplierId'] as String? ?? '',
        supplierName: json['supplier']?['name'] as String?,
        total: JsonParse.toDouble(json['total']) ?? 0,
        status: json['status'] as String? ?? 'pending',
        notes: json['notes'] as String?,
        receivedAt: json['receivedAt'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map(
                    (e) => PurchaseItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class PurchaseItemModel {
  final String productId;
  final String? productName;
  final int quantity;
  final double unitCost;
  final double subtotal;

  const PurchaseItemModel({
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) =>
      PurchaseItemModel(
        productId: json['productId'] as String? ??
            json['product']?['id'] as String? ??
            '',
        productName: json['product']?['name'] as String?,
        quantity: JsonParse.toInt(json['quantity']) ?? 0,
        unitCost: JsonParse.toDouble(json['unitCost']) ?? 0,
        subtotal: JsonParse.toDouble(json['subtotal']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitCost': unitCost,
      };
}
