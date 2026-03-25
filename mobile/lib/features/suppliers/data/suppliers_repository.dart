import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/supplier_model.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.read(dioProvider));
});

final suppliersProvider = FutureProvider.autoDispose
    .family<List<SupplierModel>, String>((ref, teamId) {
  return ref.read(suppliersRepositoryProvider).getSuppliers(teamId);
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
      return (response.data as List)
          .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
