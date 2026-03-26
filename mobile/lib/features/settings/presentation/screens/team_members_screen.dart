import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/team_member_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/team_repository.dart';

final teamMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMemberModel>, String>((ref, teamId) {
  return ref.read(teamRepositoryProvider).getMembers(teamId);
});

const _roles = ['owner', 'admin', 'manager', 'staff'];

const _roleLabels = {
  'owner': 'Dueño',
  'admin': 'Administrador',
  'manager': 'Gerente',
  'staff': 'Personal',
};

class TeamMembersScreen extends ConsumerStatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  ConsumerState<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends ConsumerState<TeamMembersScreen> {
  void _showInviteDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar miembro'),
        content: TextField(
          controller: emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'usuario@ejemplo.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              final teamId = ref.read(authProvider).teamId;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(teamRepositoryProvider)
                    .inviteMember(teamId, email);
                ref.invalidate(teamMembersProvider(teamId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Invitación enviada a "$email". '
                        'Recibirá un correo con el enlace para unirse.',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Invitar'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(TeamMemberModel member) async {
    final teamId = ref.read(authProvider).teamId;
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Cambiar rol de ${member.fullName}'),
        children: _roles
            .where((r) => r != 'owner') // Cannot assign owner role
            .map(
              (role) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, role),
                child: ListTile(
                  leading: Icon(
                    role == member.role
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: role == member.role
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  title: Text(_roleLabels[role] ?? role),
                  dense: true,
                ),
              ),
            )
            .toList(),
      ),
    );

    if (newRole == null || newRole == member.role) return;

    try {
      await ref
          .read(teamRepositoryProvider)
          .updateMemberRole(teamId, member.id, newRole);
      ref.invalidate(teamMembersProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rol de ${member.fullName} cambiado a ${_roleLabels[newRole]}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(TeamMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar miembro?'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${member.fullName} del equipo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final teamId = ref.read(authProvider).teamId;
    try {
      await ref.read(teamRepositoryProvider).removeMember(teamId, member.id);
      ref.invalidate(teamMembersProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.fullName} eliminado del equipo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final members = ref.watch(teamMembersProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipo y miembros'),
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(teamMembersProvider(teamId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined,
                      size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Sin miembros',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Invita a tu primer miembro',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(teamMembersProvider(teamId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final member = items[index];
                final auth = ref.read(authProvider);
                final canManageMembers =
                    auth.hasPermission('admin.members') &&
                        member.role != 'owner' &&
                        member.userId != auth.user?.id;
                return _MemberCard(
                  member: member,
                  onChangeRole: canManageMembers
                      ? () => _changeRole(member)
                      : null,
                  onRemove: canManageMembers
                      ? () => _removeMember(member)
                      : null,
                  onConfigurePermissions:
                      auth.isOwner &&
                              (member.role == 'manager' ||
                                  member.role == 'staff')
                          ? () => context
                              .push('/role-permissions/${member.role}')
                          : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invitar'),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMemberModel member;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRemove;
  final VoidCallback? onConfigurePermissions;

  const _MemberCard({
    required this.member,
    this.onChangeRole,
    this.onRemove,
    this.onConfigurePermissions,
  });

  Color _roleBadgeColor(BuildContext context, String role) {
    switch (role) {
      case 'owner':
        return AppColors.warning;
      case 'admin':
        return AppColors.info;
      case 'manager':
        return AppColors.success;
      case 'staff':
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = _roleBadgeColor(context, member.role);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.fullName.isNotEmpty
                              ? member.fullName
                              : member.email,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          member.roleLabel,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: badgeColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Desde ${_formatDate(member.joinedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            if (onChangeRole != null || onRemove != null || onConfigurePermissions != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'role') onChangeRole?.call();
                  if (value == 'remove') onRemove?.call();
                  if (value == 'permissions') onConfigurePermissions?.call();
                },
                itemBuilder: (context) => [
                  if (onChangeRole != null)
                    const PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                        leading: Icon(Icons.admin_panel_settings_outlined),
                        title: Text('Cambiar rol'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (onConfigurePermissions != null)
                    const PopupMenuItem(
                      value: 'permissions',
                      child: ListTile(
                        leading: Icon(Icons.security_outlined),
                        title: Text('Configurar permisos'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (onRemove != null)
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.person_remove_outlined,
                            color: Theme.of(context).colorScheme.error),
                        title: Text(
                          'Eliminar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
