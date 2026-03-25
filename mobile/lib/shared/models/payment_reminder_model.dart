class PaymentReminderModel {
  final String id;
  final String teamId;
  final String installmentId;
  final String customerId;
  final String type;
  final String channel;
  final String status;
  final String scheduledDate;
  final DateTime? sentAt;
  final String? message;
  final String? errorMessage;
  final DateTime createdAt;

  // Nested relations
  final String? customerName;
  final double? installmentAmount;
  final double? installmentPaidAmount;
  final String? installmentDueDate;

  const PaymentReminderModel({
    required this.id,
    required this.teamId,
    required this.installmentId,
    required this.customerId,
    required this.type,
    required this.channel,
    required this.status,
    required this.scheduledDate,
    this.sentAt,
    this.message,
    this.errorMessage,
    required this.createdAt,
    this.customerName,
    this.installmentAmount,
    this.installmentPaidAmount,
    this.installmentDueDate,
  });

  factory PaymentReminderModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final installment = json['installment'] as Map<String, dynamic>?;

    return PaymentReminderModel(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      installmentId: json['installmentId'] as String,
      customerId: json['customerId'] as String,
      type: json['type'] as String,
      channel: json['channel'] as String? ?? 'internal',
      status: json['status'] as String? ?? 'pending',
      scheduledDate: json['scheduledDate'] as String,
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : null,
      message: json['message'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      customerName: customer?['name'] as String?,
      installmentAmount: _toDouble(installment?['amount']),
      installmentPaidAmount: _toDouble(installment?['paidAmount']),
      installmentDueDate: installment?['dueDate'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Remaining amount for the installment.
  double get remainingAmount =>
      (installmentAmount ?? 0) - (installmentPaidAmount ?? 0);

  /// Status label in Spanish.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'sent':
        return 'Enviado';
      case 'failed':
        return 'Fallido';
      default:
        return status;
    }
  }

  /// Channel label in Spanish.
  String get channelLabel {
    switch (channel) {
      case 'sms':
        return 'SMS';
      case 'whatsapp':
        return 'WhatsApp';
      case 'email':
        return 'Email';
      case 'push':
        return 'Push';
      case 'internal':
        return 'Interno';
      default:
        return channel;
    }
  }

  /// Type label in Spanish.
  String get typeLabel {
    switch (type) {
      case 'before_due':
        return 'Antes del vencimiento';
      case 'on_due':
        return 'Día del vencimiento';
      case 'after_due':
        return 'Después del vencimiento';
      default:
        return type;
    }
  }
}
