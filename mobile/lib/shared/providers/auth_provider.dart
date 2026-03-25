import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final TeamModel? activeTeam;
  final List<TeamModel> teams;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.activeTeam,
    this.teams = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  String get teamId => activeTeam?.id ?? '';

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    TeamModel? activeTeam,
    List<TeamModel>? teams,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        activeTeam: activeTeam ?? this.activeTeam,
        teams: teams ?? this.teams,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final SecureStorage _storage;

  AuthNotifier(this._repo, this._storage) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final token = await _storage.getToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repo.getProfile();
      final teams = await _repo.getTeams();
      final savedTeamId = await _storage.getActiveTeamId();
      TeamModel? activeTeam;
      if (teams.isNotEmpty) {
        activeTeam = teams.firstWhere(
          (t) => t.id == savedTeamId,
          orElse: () => teams.first,
        );
        await _storage.saveActiveTeamId(activeTeam.id);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        teams: teams,
        activeTeam: activeTeam,
      );
    } catch (_) {
      await _storage.clearAll();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _repo.login(email: email, password: password);
      final teams = await _repo.getTeams();
      TeamModel? activeTeam;
      if (teams.isNotEmpty) {
        activeTeam = teams.first;
        await _storage.saveActiveTeamId(activeTeam.id);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: teams,
        activeTeam: activeTeam,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: const [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createTeam(String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final team = await _repo.createTeam(name);
      await _storage.saveActiveTeamId(team.id);
      state = state.copyWith(
        teams: [...state.teams, team],
        activeTeam: team,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void switchTeam(TeamModel team) {
    _storage.saveActiveTeamId(team.id);
    state = state.copyWith(activeTeam: team);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
  );
});
