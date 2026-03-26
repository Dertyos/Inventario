import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/cache_for.dart';
import '../../../shared/models/purchase_model.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.read(dioProvider));
});

final purchasesProvider = FutureProvider.autoDispose
    .family<List<PurchaseModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(purchasesRepositoryProvider).getPurchases(teamId);
});

class PurchasesRepository {
  final Dio _dio;

  PurchasesRepository(this._dio);

  Future<List<PurchaseModel>> getPurchases(
    String teamId, {
    String? supplierId,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (supplierId != null) params['supplierId'] = supplierId;
      if (status != null) params['status'] = status;

      final response = await _dio.get(
        '/teams/$teamId/purchases',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => PurchaseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PurchaseModel> createPurchase(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/purchases', data: data);
      return PurchaseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PurchaseModel> receivePurchase(String teamId, String id) async {
    try {
      final response =
          await _dio.patch('/teams/$teamId/purchases/$id/receive');
      return PurchaseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<PurchaseModel> cancelPurchase(String teamId, String id) async {
    try {
      final response =
          await _dio.patch('/teams/$teamId/purchases/$id/cancel');
      return PurchaseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
