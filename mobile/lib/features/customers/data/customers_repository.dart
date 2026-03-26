import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/pending_sales_service.dart';
import '../../../shared/models/customer_model.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(
    ref.read(dioProvider),
    ref.read(pendingSalesServiceProvider),
  );
});

class CustomersRepository {
  final Dio _dio;
  final PendingSalesService _offline;

  CustomersRepository(this._dio, this._offline);

  Future<List<CustomerModel>> getCustomers(
    String teamId, {
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/teams/$teamId/customers',
        queryParameters: params,
      );
      final customers = (response.data as List)
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache for offline use (only full list, no search)
      if (search == null || search.isEmpty) {
        _offline.cacheCustomers(
          teamId,
          (response.data as List).cast<Map<String, dynamic>>(),
        );
      }

      return customers;
    } on DioException catch (e) {
      // Offline fallback: return cached customers
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        final cached = await _offline.getCachedCustomers(teamId);
        if (cached != null) {
          return cached.map((e) => CustomerModel.fromJson(e)).toList();
        }
      }
      throw ApiException.fromDioError(e);
    }
  }

  Future<CustomerModel> createCustomer(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response =
          await _dio.post('/teams/$teamId/customers', data: data);
      return CustomerModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _offline.savePendingOperation(
          teamId: teamId,
          type: 'create_customer',
          endpoint: '/teams/$teamId/customers',
          data: data,
        );
        throw ApiException(
            'Cliente guardado localmente. Se creara cuando haya conexion.');
      }
      throw ApiException.fromDioError(e);
    }
  }

  Future<CustomerModel> updateCustomer(
    String teamId,
    String customerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/teams/$teamId/customers/$customerId',
        data: data,
      );
      return CustomerModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
