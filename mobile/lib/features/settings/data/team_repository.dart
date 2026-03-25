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

  Future<TeamMemberModel> inviteMember(String teamId, String email) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/members',
        data: {'email': email},
      );
      return TeamMemberModel.fromJson(response.data);
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
}
