import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart'
    show authProvider, pendingInviteTokenProvider, AuthState;
import '../../../settings/data/team_repository.dart';

class InvitationScreen extends ConsumerStatefulWidget {
  final String token;

  const InvitationScreen({super.key, required this.token});

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  Map<String, dynamic>? _invitation;
  bool _loading = true;
  bool _accepting = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    try {
      final data = await ref
          .read(teamRepositoryProvider)
          .getInvitationByToken(widget.token);
      if (mounted) {
        setState(() {
          _invitation = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptInvitation() async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      // Save the token so it survives the login/register flow
      ref.read(pendingInviteTokenProvider.notifier).state = widget.token;
      context.go('/login');
      return;
    }

    setState(() {
      _accepting = true;
      _error = null;
    });

    try {
      await ref.read(teamRepositoryProvider).acceptInvitation(widget.token);
      // Clear the pending token
      ref.read(pendingInviteTokenProvider.notifier).state = null;
      // Refresh teams so the new team appears
      await ref.read(authProvider.notifier).refreshTeams();
      if (mounted) {
        setState(() {
          _accepting = false;
          _successMessage = 'Te has unido al equipo exitosamente';
        });
        // Go straight to dashboard — user is already logged in
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) context.go('/dashboard');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accepting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitación'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (authState.isAuthenticated) {
              context.go('/dashboard');
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_successMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 72, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              Text(
                _successMessage!,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Redirigiendo al inicio...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _invitation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No se pudo cargar la invitación',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadInvitation();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final team = _invitation!['team'] as Map<String, dynamic>;
    final inviter = _invitation!['inviter'] as Map<String, dynamic>;
    final teamName = team['name'] as String;
    final inviterName =
        '${inviter['firstName']} ${inviter['lastName']}'.trim();
    final status = _invitation!['status'] as String;
    final expiresAt = DateTime.parse(_invitation!['expiresAt'] as String);
    final isExpired = DateTime.now().isAfter(expiresAt);
    final isPending = status == 'pending';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.group_add_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Invitación al equipo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                children: [
                  TextSpan(
                    text: inviterName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' te ha invitado al equipo '),
                  TextSpan(
                    text: teamName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: colorScheme.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!isPending) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'accepted'
                      ? 'Esta invitación ya fue aceptada.'
                      : status == 'revoked'
                          ? 'Esta invitación fue revocada.'
                          : 'Esta invitación ya no es válida.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ] else if (isExpired) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Esta invitación ha expirado.',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _accepting ? null : _acceptInvitation,
                  icon: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                      _accepting ? 'Aceptando...' : 'Aceptar invitación'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
