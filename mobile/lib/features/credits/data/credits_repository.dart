import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/cache_for.dart';
import '../../../shared/models/credit_model.dart';

final creditsRepositoryProvider = Provider<CreditsRepository>((ref) {
  return CreditsRepository(ref.read(dioProvider));
});

final creditsProvider = FutureProvider.autoDispose
    .family<List<CreditAccountModel>, String>((ref, teamId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.read(creditsRepositoryProvider);
  return repo.getCredits(teamId);
});

final overdueCreditsProvider = FutureProvider.autoDispose
    .family<List<CreditInstallmentModel>, String>((ref, teamId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.read(creditsRepositoryProvider);
  return repo.getOverdue(teamId);
});

final creditDetailProvider = FutureProvider.autoDispose
    .family<CreditAccountModel, ({String teamId, String creditId})>(
        (ref, params) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.read(creditsRepositoryProvider);
  return repo.getCredit(params.teamId, params.creditId);
});

class CreditsRepository {
  final Dio _dio;

  CreditsRepository(this._dio);

  Future<List<CreditAccountModel>> getCredits(
    String teamId, {
    String? customerId,
    CreditStatus? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (customerId != null && customerId.isNotEmpty) {
        params['customerId'] = customerId;
      }
      if (status != null) {
        params['status'] = status.name;
      }

      final response = await _dio.get(
        '/teams/$teamId/credits',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) =>
              CreditAccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CreditInstallmentModel>> getOverdue(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/credits/overdue');
      return (response.data as List)
          .map((e) =>
              CreditInstallmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CreditAccountModel> getCredit(String teamId, String id) async {
    try {
      final response = await _dio.get('/teams/$teamId/credits/$id');
      return CreditAccountModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CreditAccountModel> createCredit(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/credits', data: data);
      return CreditAccountModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CreditAccountModel> payInstallment(
    String teamId,
    String creditId,
    String installmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/credits/$creditId/installments/$installmentId/pay',
        data: data,
      );
      return CreditAccountModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
