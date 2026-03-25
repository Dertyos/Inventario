import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(dioProvider));
});

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
        quantity: json['quantity'] as int,
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

class InventoryRepository {
  final Dio _dio;

  InventoryRepository(this._dio);

  Future<List<InventoryMovementModel>> getMovements(
    String teamId, {
    String? productId,
    String? type,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (productId != null) params['productId'] = productId;
      if (type != null) params['type'] = type;

      final response = await _dio.get(
        '/teams/$teamId/inventory/movements',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) =>
              InventoryMovementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<InventoryMovementModel> createMovement(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/inventory/movements',
        data: data,
      );
      return InventoryMovementModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
