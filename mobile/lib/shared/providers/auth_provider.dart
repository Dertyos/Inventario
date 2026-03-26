import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  final List<String> permissions;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.activeTeam,
    this.teams = const [],
    this.permissions = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  String get teamId => activeTeam?.id ?? '';

  // Role-based access
  String? get userRole => activeTeam?.userRole;
  bool get isOwner => userRole == 'owner';
  bool get isAdmin => userRole == 'admin' || isOwner;
  bool get isManager => userRole == 'manager' || isAdmin;
  // staff can do basic operations

  /// Check if the user has a specific permission.
  /// Owner and Admin always have all permissions.
  bool hasPermission(String key) =>
      isOwner || isAdmin || permissions.contains(key);

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    TeamModel? activeTeam,
    List<TeamModel>? teams,
    List<String>? permissions,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        activeTeam: activeTeam ?? this.activeTeam,
        teams: teams ?? this.teams,
        permissions: permissions ?? this.permissions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SecureStorage get _storage => ref.read(secureStorageProvider);

  /// Fetch permissions for the current user's role on the given team.
  /// Owner/Admin always have all permissions, so we skip the network call.
  Future<List<String>> _fetchPermissions(TeamModel team) async {
    final role = team.userRole;
    if (role == null || role == 'owner' || role == 'admin') {
      return const [];
    }
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/teams/${team.id}/permissions/$role');
      final data = response.data;
      final List<dynamic> perms = data is Map
          ? (data['permissions'] as List<dynamic>? ?? [])
          : (data as List<dynamic>? ?? []);
      return perms.cast<String>().toList();
    } catch (_) {
      return const [];
    }
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
      List<String> permissions = const [];
      if (activeTeam != null) {
        permissions = await _fetchPermissions(activeTeam);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        teams: teams,
        activeTeam: activeTeam,
        permissions: permissions,
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
      List<String> permissions = const [];
      if (activeTeam != null) {
        permissions = await _fetchPermissions(activeTeam);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: teams,
        activeTeam: activeTeam,
        permissions: permissions,
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
      // Fetch teams — user may already belong to one via a pre-accepted invite.
      final teams = await _repo.getTeams();
      TeamModel? activeTeam;
      if (teams.isNotEmpty) {
        activeTeam = teams.first;
        await _storage.saveActiveTeamId(activeTeam.id);
      }
      List<String> permissions = const [];
      if (activeTeam != null) {
        permissions = await _fetchPermissions(activeTeam);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: teams,
        activeTeam: activeTeam,
        permissions: permissions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No se pudo obtener el token de Google',
        );
        return;
      }

      final auth = await _repo.googleSignIn(idToken);
      final teams = await _repo.getTeams();
      TeamModel? activeTeam;
      if (teams.isNotEmpty) {
        activeTeam = teams.first;
        await _storage.saveActiveTeamId(activeTeam.id);
      }
      List<String> permissions = const [];
      if (activeTeam != null) {
        permissions = await _fetchPermissions(activeTeam);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: teams,
        activeTeam: activeTeam,
        permissions: permissions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No se pudo obtener el token de Apple',
        );
        return;
      }

      final auth = await _repo.appleSignIn(
        identityToken,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
      final teams = await _repo.getTeams();
      TeamModel? activeTeam;
      if (teams.isNotEmpty) {
        activeTeam = teams.first;
        await _storage.saveActiveTeamId(activeTeam.id);
      }
      List<String> permissions = const [];
      if (activeTeam != null) {
        permissions = await _fetchPermissions(activeTeam);
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: auth.user,
        teams: teams,
        activeTeam: activeTeam,
        permissions: permissions,
        isLoading: false,
      );
    } catch (e) {
      // User cancelled Apple Sign-In
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false);
        return;
      }
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

  /// Re-fetches teams from backend and updates state (e.g. after accepting an invite).
  Future<void> refreshTeams() async {
    final teams = await _repo.getTeams();
    TeamModel? activeTeam;
    if (teams.isNotEmpty) {
      final savedTeamId = await _storage.getActiveTeamId();
      activeTeam = teams.firstWhere(
        (t) => t.id == savedTeamId,
        orElse: () => teams.first,
      );
      await _storage.saveActiveTeamId(activeTeam.id);
    }
    List<String> permissions = const [];
    if (activeTeam != null) {
      permissions = await _fetchPermissions(activeTeam);
    }
    state = state.copyWith(teams: teams, activeTeam: activeTeam, permissions: permissions);
  }

  Future<void> switchTeam(TeamModel team) async {
    _storage.saveActiveTeamId(team.id);
    final permissions = await _fetchPermissions(team);
    state = state.copyWith(activeTeam: team, permissions: permissions);
  }

  Future<void> updateTeamName(String teamId, String name) async {
    try {
      final updated = await _repo.updateTeam(teamId, {'name': name});
      final teams = state.teams.map((t) => t.id == teamId ? updated : t).toList();
      state = state.copyWith(
        teams: teams,
        activeTeam: state.activeTeam?.id == teamId ? updated : state.activeTeam,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Holds a pending invite token so it survives the login/register redirect.
final pendingInviteTokenProvider = StateProvider<String?>((ref) => null);
