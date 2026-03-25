import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/notification_model.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(dioProvider));
});

/// Fetches notifications for the given team. Pass [unreadOnly] in the arg
/// record to filter.  The family key is `(teamId, unreadOnly)`.
final notificationsProvider = FutureProvider.autoDispose
    .family<List<NotificationModel>, (String, bool)>((ref, arg) async {
  final repo = ref.read(notificationsRepositoryProvider);
  return repo.getNotifications(arg.$1, unreadOnly: arg.$2);
});

/// Unread notification count for the active team (badge).
final unreadCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, teamId) async {
  final repo = ref.read(notificationsRepositoryProvider);
  final unread = await repo.getNotifications(teamId, unreadOnly: true);
  return unread.length;
});

class NotificationsRepository {
  final Dio _dio;

  NotificationsRepository(this._dio);

  Future<List<NotificationModel>> getNotifications(
    String teamId, {
    bool unreadOnly = false,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (unreadOnly) params['unreadOnly'] = 'true';

      final response = await _dio.get(
        '/teams/$teamId/notifications',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NotificationModel> markAsRead(String teamId, String id) async {
    try {
      final response =
          await _dio.patch('/teams/$teamId/notifications/$id/read');
      return NotificationModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> markAllAsRead(String teamId) async {
    try {
      await _dio.post('/teams/$teamId/notifications/read-all');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
