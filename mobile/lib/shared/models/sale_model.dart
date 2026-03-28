import 'product_model.dart';

class SaleModel {
  final String id;
  final String saleNumber;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final String? notes;
  final String? customerId;
  final String? customerName;
  final int? creditInstallments;
  final double? creditPaidAmount;
  final double? creditInterestRate;
  final String? creditFrequency;
  final DateTime? creditNextPayment;
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
    this.creditInstallments,
    this.creditPaidAmount,
    this.creditInterestRate,
    this.creditFrequency,
    this.creditNextPayment,
    this.items = const [],
    required this.createdAt,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isCredit => paymentMethod == 'credit';
  double get creditTotalWithInterest {
    if (!isCredit || creditInterestRate == null || creditInterestRate == 0) {
      return totalAmount;
    }
    return totalAmount * (1 + creditInterestRate! / 100);
  }

  double get creditBalance =>
      isCredit ? creditTotalWithInterest - (creditPaidAmount ?? 0) : 0;

  String get creditFrequencyLabel {
    switch (creditFrequency) {
      case 'weekly':
        return 'Semanal';
      case 'daily':
        return 'Diaria';
      default:
        return 'Mensual';
    }
  }

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json['id'] as String,
        saleNumber: json['saleNumber'] as String? ?? '',
        totalAmount: JsonParse.toDouble(json['total']) ?? 0,
        status: json['status'] as String? ?? 'completed',
        paymentMethod: json['paymentMethod'] as String?,
        notes: json['notes'] as String?,
        customerId: json['customerId'] as String?,
        customerName: json['customer']?['name'] as String?,
        creditInstallments: JsonParse.toInt(json['creditInstallments']),
        creditPaidAmount: JsonParse.toDouble(json['creditPaidAmount']),
        creditInterestRate: JsonParse.toDouble(json['creditInterestRate']),
        creditFrequency: json['creditFrequency'] as String?,
        creditNextPayment: json['creditNextPayment'] != null
            ? DateTime.tryParse(json['creditNextPayment'] as String)
            : null,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
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
        quantity: JsonParse.toInt(json['quantity']) ?? 0,
        unitPrice: JsonParse.toDouble(json['unitPrice']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}
