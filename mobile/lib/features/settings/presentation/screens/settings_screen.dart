import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // User card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      auth.user?.firstName[0].toUpperCase() ?? '?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.fullName ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          auth.user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Team card
          if (auth.activeTeam != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.store_rounded,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.activeTeam!.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${auth.activeTeam!.currency} · ${auth.activeTeam!.timezone}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (auth.teams.length > 1)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.swap_horiz),
                        onSelected: (teamId) {
                          final team =
                              auth.teams.firstWhere((t) => t.id == teamId);
                          ref.read(authProvider.notifier).switchTeam(team);
                        },
                        itemBuilder: (context) => auth.teams
                            .map((t) => PopupMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Menu items
          _SettingsTile(
            icon: Icons.people_outlined,
            title: 'Clientes',
            onTap: () => context.go('/customers'),
          ),
          _SettingsTile(
            icon: Icons.mic,
            title: 'Registrar con voz',
            subtitle: 'Ventas y compras en lenguaje natural',
            onTap: () => context.push('/voice-transaction'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.group_outlined,
            title: 'Equipo y miembros',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'Configuración del equipo',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.lg),

          // Logout
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
