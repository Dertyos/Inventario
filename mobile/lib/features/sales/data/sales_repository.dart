import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/sale_model.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.read(dioProvider));
});

class SalesRepository {
  final Dio _dio;

  SalesRepository(this._dio);

  Future<List<SaleModel>> getSales(
    String teamId, {
    String? customerId,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (customerId != null) params['customerId'] = customerId;
      if (status != null) params['status'] = status;

      final response = await _dio.get(
        '/teams/$teamId/sales',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SaleModel> createSale(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/sales', data: data);
      return SaleModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SaleModel> cancelSale(String teamId, String saleId) async {
    try {
      final response =
          await _dio.patch('/teams/$teamId/sales/$saleId/cancel');
      return SaleModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
