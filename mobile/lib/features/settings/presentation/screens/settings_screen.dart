import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';

void _showEditTeamNameDialog(BuildContext context, WidgetRef ref) {
  final auth = ref.read(authProvider);
  final controller = TextEditingController(text: auth.activeTeam?.name ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nombre de la tienda'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nombre',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty && auth.activeTeam != null) {
              ref.read(authProvider.notifier).updateTeamName(auth.activeTeam!.id, name);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

void _showTeamSwitcher(BuildContext context, WidgetRef ref) {
  final auth = ref.read(authProvider);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  'Tus equipos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...auth.teams.map((team) {
            final isActive = team.id == auth.activeTeam?.id;
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.store_rounded,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              title: Text(team.name),
              subtitle: Text(team.currency),
              trailing: isActive
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(authProvider.notifier).switchTeam(team);
                Navigator.pop(ctx);
              },
            );
          }),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                size: 20,
              ),
            ),
            title: const Text('Crear nuevo equipo'),
            onTap: () {
              Navigator.pop(ctx);
              _showCreateTeamDialog(context, ref);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

void _showCreateTeamDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nuevo equipo'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nombre del negocio',
          prefixIcon: Icon(Icons.store_rounded),
          hintText: 'Ej: Mi Tienda',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty || name.length < 2) return;
            Navigator.pop(ctx);
            await ref.read(authProvider.notifier).createTeam(name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Equipo "$name" creado')),
              );
            }
          },
          child: const Text('Crear'),
        ),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mas')),
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
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showTeamSwitcher(context, ref),
                onLongPress: () => _showEditTeamNameDialog(context, ref),
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
                              '${auth.activeTeam!.currency} · ${auth.teams.length} equipo${auth.teams.length > 1 ? 's' : ''}',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.unfold_more_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Menu items
          _SettingsTile(
            icon: Icons.group_outlined,
            title: 'Equipo y miembros',
            subtitle: 'Gestiona los miembros de tu equipo',
            onTap: () => context.push('/team-members'),
          ),
          _SettingsTile(
            icon: Icons.settings_outlined,
            title: 'Configuración del equipo',
            subtitle: 'Nombre, moneda y más',
            onTap: () => context.push('/team-settings'),
          ),
          _SettingsTile(
            icon: Icons.people_outlined,
            title: 'Clientes',
            onTap: () => context.go('/customers'),
          ),
          _SettingsTile(
            icon: Icons.local_shipping_outlined,
            title: 'Proveedores',
            subtitle: 'Gestiona tus proveedores',
            onTap: () => context.push('/suppliers'),
          ),
          _SettingsTile(
            icon: Icons.credit_score_outlined,
            title: 'Créditos',
            subtitle: 'Cuentas por cobrar y cuotas',
            onTap: () => context.push('/credits'),
          ),
          _SettingsTile(
            icon: Icons.shopping_cart_outlined,
            title: 'Compras',
            subtitle: 'Órdenes de compra a proveedores',
            onTap: () => context.push('/purchases'),
          ),
          _SettingsTile(
            icon: Icons.inventory_outlined,
            title: 'Lotes',
            subtitle: 'Lotes y fechas de vencimiento',
            onTap: () => context.push('/lots'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () => context.push('/notifications'),
          ),
          _SettingsTile(
            icon: Icons.schedule_outlined,
            title: 'Recordatorios de pago',
            subtitle: 'Genera y gestiona cobros',
            onTap: () => context.push('/reminders'),
          ),
          _SettingsTile(
            icon: Icons.mic,
            title: 'Registrar con voz',
            subtitle: 'Ventas y compras en lenguaje natural',
            onTap: () => context.push('/voice-transaction'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Logout
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar sesion?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Cerrar sesion'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // App info
          Center(
            child: Text(
              'Inventario v${AppConfig.appVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
