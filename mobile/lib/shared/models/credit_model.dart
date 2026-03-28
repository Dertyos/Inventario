import 'product_model.dart' show JsonParse;
import 'customer_model.dart';

enum InterestType { none, fixed, monthly }

enum CreditStatus { active, paid, defaulted }

enum InstallmentStatus { pending, paid, overdue, partial }

class CreditAccountModel {
  final String id;
  final String teamId;
  final String saleId;
  final String customerId;
  final CustomerModel? customer;
  final double totalAmount;
  final double paidAmount;
  final double interestRate;
  final InterestType interestType;
  final int installments;
  final String startDate;
  final CreditStatus status;
  final List<CreditInstallmentModel> creditInstallments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditAccountModel({
    required this.id,
    required this.teamId,
    required this.saleId,
    required this.customerId,
    this.customer,
    required this.totalAmount,
    required this.paidAmount,
    required this.interestRate,
    required this.interestType,
    required this.installments,
    required this.startDate,
    required this.status,
    this.creditInstallments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get balance => totalAmount - paidAmount;

  bool get isOverdue =>
      status == CreditStatus.active &&
      creditInstallments.any((i) =>
          i.status == InstallmentStatus.overdue ||
          i.status == InstallmentStatus.pending &&
              DateTime.tryParse(i.dueDate)?.isBefore(DateTime.now()) == true);

  String get statusLabel {
    switch (status) {
      case CreditStatus.active:
        return 'Activo';
      case CreditStatus.paid:
        return 'Pagado';
      case CreditStatus.defaulted:
        return 'Vencido';
    }
  }

  String get interestTypeLabel {
    switch (interestType) {
      case InterestType.none:
        return 'Sin interés';
      case InterestType.fixed:
        return 'Fijo';
      case InterestType.monthly:
        return 'Mensual';
    }
  }

  double get progressPercent =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0;

  factory CreditAccountModel.fromJson(Map<String, dynamic> json) {
    final installmentsList = json['creditInstallments'] as List?;
    return CreditAccountModel(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      saleId: json['saleId'] as String,
      customerId: json['customerId'] as String,
      customer: json['customer'] != null
          ? CustomerModel.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      totalAmount: JsonParse.toDouble(json['totalAmount']) ?? 0,
      paidAmount: JsonParse.toDouble(json['paidAmount']) ?? 0,
      interestRate: JsonParse.toDouble(json['interestRate']) ?? 0,
      interestType: _parseInterestType(json['interestType'] as String?),
      installments: JsonParse.toInt(json['installments']) ?? 1,
      startDate: json['startDate'] as String? ?? '',
      status: _parseCreditStatus(json['status'] as String?),
      creditInstallments: installmentsList != null
          ? installmentsList
              .map((e) =>
                  CreditInstallmentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static InterestType _parseInterestType(String? value) {
    switch (value) {
      case 'fixed':
        return InterestType.fixed;
      case 'monthly':
        return InterestType.monthly;
      default:
        return InterestType.none;
    }
  }

  static CreditStatus _parseCreditStatus(String? value) {
    switch (value) {
      case 'paid':
        return CreditStatus.paid;
      case 'defaulted':
        return CreditStatus.defaulted;
      default:
        return CreditStatus.active;
    }
  }
}

class CreditInstallmentModel {
  final String id;
  final String creditAccountId;
  final int installmentNumber;
  final double amount;
  final String dueDate;
  final double paidAmount;
  final DateTime? paidAt;
  final InstallmentStatus status;
  final DateTime createdAt;

  const CreditInstallmentModel({
    required this.id,
    required this.creditAccountId,
    required this.installmentNumber,
    required this.amount,
    required this.dueDate,
    required this.paidAmount,
    this.paidAt,
    required this.status,
    required this.createdAt,
  });

  double get balance => amount - paidAmount;

  bool get isOverdue =>
      (status == InstallmentStatus.pending ||
          status == InstallmentStatus.partial) &&
      DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true;

  String get statusLabel {
    switch (status) {
      case InstallmentStatus.pending:
        return isOverdue ? 'Vencida' : 'Pendiente';
      case InstallmentStatus.paid:
        return 'Pagada';
      case InstallmentStatus.overdue:
        return 'Vencida';
      case InstallmentStatus.partial:
        return isOverdue ? 'Parcial (vencida)' : 'Parcial';
    }
  }

  factory CreditInstallmentModel.fromJson(Map<String, dynamic> json) {
    return CreditInstallmentModel(
      id: json['id'] as String,
      creditAccountId: json['creditAccountId'] as String,
      installmentNumber: JsonParse.toInt(json['installmentNumber']) ?? 0,
      amount: JsonParse.toDouble(json['amount']) ?? 0,
      dueDate: json['dueDate'] as String? ?? '',
      paidAmount: JsonParse.toDouble(json['paidAmount']) ?? 0,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      status: _parseInstallmentStatus(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static InstallmentStatus _parseInstallmentStatus(String? value) {
    switch (value) {
      case 'paid':
        return InstallmentStatus.paid;
      case 'overdue':
        return InstallmentStatus.overdue;
      case 'partial':
        return InstallmentStatus.partial;
      default:
        return InstallmentStatus.pending;
    }
  }
}
