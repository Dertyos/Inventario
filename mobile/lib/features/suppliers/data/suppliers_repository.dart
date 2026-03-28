import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/cache_for.dart';
import '../../../shared/models/supplier_model.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.read(dioProvider));
});

final suppliersProvider = FutureProvider.autoDispose
    .family<List<SupplierModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(suppliersRepositoryProvider).getSuppliers(teamId);
});

final supplierDetailProvider = FutureProvider.autoDispose
    .family<SupplierModel, ({String teamId, String supplierId})>(
        (ref, params) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref
      .read(suppliersRepositoryProvider)
      .getSupplier(params.teamId, params.supplierId);
});

class SuppliersRepository {
  final Dio _dio;

  SuppliersRepository(this._dio);

  Future<List<SupplierModel>> getSuppliers(
    String teamId, {
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/teams/$teamId/suppliers',
        queryParameters: params,
      );
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SupplierModel> getSupplier(String teamId, String supplierId) async {
    try {
      final response =
          await _dio.get('/teams/$teamId/suppliers/$supplierId');
      return SupplierModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SupplierModel> updateSupplier(
    String teamId,
    String supplierId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/teams/$teamId/suppliers/$supplierId',
        data: data,
      );
      return SupplierModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SupplierModel> createSupplier(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/suppliers', data: data);
      return SupplierModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
