import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String? message;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.message,
    this.isRead = false,
    this.metadata,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  /// Returns an appropriate icon based on the notification type.
  IconData get icon {
    switch (type) {
      case 'payment_due':
        return Icons.payment;
      case 'stock_low':
        return Icons.inventory_2_outlined;
      case 'lot_expiring':
        return Icons.timer_outlined;
      case 'purchase_received':
        return Icons.local_shipping_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Returns a semantic color based on the notification type.
  Color color(BuildContext context) {
    switch (type) {
      case 'payment_due':
        return const Color(0xFFFF9F43);
      case 'stock_low':
        return const Color(0xFFEB4D4B);
      case 'lot_expiring':
        return const Color(0xFFEB4D4B);
      case 'purchase_received':
        return const Color(0xFF2ECC71);
      case 'system':
        return const Color(0xFF4F6BF6);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
