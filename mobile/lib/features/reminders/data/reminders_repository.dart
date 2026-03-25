import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/payment_reminder_model.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(ref.read(dioProvider));
});

/// Fetches reminders for the given team, optionally filtered by status.
/// Family key: `(teamId, status)` where status can be null.
final remindersProvider = FutureProvider.autoDispose
    .family<List<PaymentReminderModel>, (String, String?)>((ref, arg) async {
  final repo = ref.read(remindersRepositoryProvider);
  return repo.getReminders(arg.$1, status: arg.$2);
});

class RemindersRepository {
  final Dio _dio;

  RemindersRepository(this._dio);

  Future<List<PaymentReminderModel>> getReminders(
    String teamId, {
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;

      final response = await _dio.get(
        '/teams/$teamId/reminders',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) =>
              PaymentReminderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Asks the backend to generate reminders for upcoming / overdue
  /// installments. Returns the number of reminders created.
  Future<int> generateReminders(String teamId) async {
    try {
      final response = await _dio.post('/teams/$teamId/reminders/generate');
      return response.data as int;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
