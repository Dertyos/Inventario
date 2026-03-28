import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/inventory_movement_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(dioProvider));
});

class InventoryRepository {
  final Dio _dio;

  InventoryRepository(this._dio);

  Future<List<InventoryMovementModel>> getMovements(
    String teamId, {
    String? productId,
    String? supplierId,
    String? type,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (productId != null) params['productId'] = productId;
      if (supplierId != null) params['supplierId'] = supplierId;
      if (type != null) params['type'] = type;

      final response = await _dio.get(
        '/teams/$teamId/inventory/movements',
        queryParameters: params,
      );
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
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
