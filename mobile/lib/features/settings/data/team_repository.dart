import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/team_member_model.dart';
import '../../../shared/models/team_model.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.read(dioProvider));
});

class TeamRepository {
  final Dio _dio;

  TeamRepository(this._dio);

  Future<List<TeamMemberModel>> getMembers(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/members');
      return (response.data as List)
          .map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> inviteMember(String teamId, String email) async {
    try {
      await _dio.post(
        '/teams/$teamId/invitations',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> removeMember(String teamId, String memberId) async {
    try {
      await _dio.delete('/teams/$teamId/members/$memberId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TeamMemberModel> updateMemberRole(
    String teamId,
    String memberId,
    String role,
  ) async {
    try {
      final response = await _dio.patch(
        '/teams/$teamId/members/$memberId/role',
        data: {'role': role},
      );
      return TeamMemberModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TeamModel> updateTeamSettings(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch('/teams/$teamId', data: data);
      return TeamModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ── Invitation management ─────────────────────

  Future<List<Map<String, dynamic>>> getInvitations(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/invitations');
      return (response.data as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> createInvitation(
    String teamId,
    String email,
  ) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/invitations',
        data: {'email': email},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> revokeInvitation(
    String teamId,
    String invitationId,
  ) async {
    try {
      await _dio.delete('/teams/$teamId/invitations/$invitationId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ── Public invitation endpoints ───────────────

  Future<Map<String, dynamic>> getInvitationByToken(String token) async {
    try {
      final response = await _dio.get('/invitations/$token');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> acceptInvitation(String token) async {
    try {
      final response = await _dio.post('/invitations/$token/accept');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
