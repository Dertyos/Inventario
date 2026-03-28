import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/cache_for.dart';
import '../../../shared/models/product_lot_model.dart';

final lotsRepositoryProvider = Provider<LotsRepository>((ref) {
  return LotsRepository(ref.read(dioProvider));
});

final lotsProvider = FutureProvider.autoDispose
    .family<List<ProductLotModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(lotsRepositoryProvider).getLots(teamId);
});

final expiringLotsProvider = FutureProvider.autoDispose
    .family<List<ProductLotModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(lotsRepositoryProvider).getExpiringLots(teamId);
});

class LotsRepository {
  final Dio _dio;

  LotsRepository(this._dio);

  Future<List<ProductLotModel>> getLots(
    String teamId, {
    String? productId,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (productId != null) params['productId'] = productId;
      if (status != null) params['status'] = status;

      final response = await _dio.get(
        '/teams/$teamId/lots',
        queryParameters: params,
      );
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => ProductLotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<ProductLotModel>> getExpiringLots(
    String teamId, {
    int days = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/teams/$teamId/lots/expiring',
        queryParameters: {'days': days},
      );
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => ProductLotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductLotModel> createLot(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/lots',
        data: data,
      );
      return ProductLotModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<int> markExpired(String teamId) async {
    try {
      final response = await _dio.post('/teams/$teamId/lots/mark-expired');
      return response.data as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
