class SaleModel {
  final String id;
  final String saleNumber;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final String? notes;
  final String? customerId;
  final String? customerName;
  final List<SaleItemModel> items;
  final DateTime createdAt;

  const SaleModel({
    required this.id,
    required this.saleNumber,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.notes,
    this.customerId,
    this.customerName,
    this.items = const [],
    required this.createdAt,
  });

  bool get isCancelled => status == 'cancelled';

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json['id'] as String,
        saleNumber: json['saleNumber'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num).toDouble(),
        status: json['status'] as String? ?? 'completed',
        paymentMethod: json['paymentMethod'] as String?,
        notes: json['notes'] as String?,
        customerId: json['customerId'] as String?,
        customerName: json['customer']?['name'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class SaleItemModel {
  final String productId;
  final String? productName;
  final int quantity;
  final double unitPrice;

  const SaleItemModel({
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory SaleItemModel.fromJson(Map<String, dynamic> json) => SaleItemModel(
        productId: json['productId'] as String? ?? json['product']?['id'] as String? ?? '',
        productName: json['product']?['name'] as String?,
        quantity: json['quantity'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}
