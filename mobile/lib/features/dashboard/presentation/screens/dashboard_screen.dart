import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/widgets/stat_card.dart';

final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardData, String>((ref, teamId) {
  return ref.read(dashboardRepositoryProvider).getDashboardData(teamId);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final teamId = auth.teamId;
    final dashboard = ref.watch(dashboardProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${auth.user?.firstName ?? ''}!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (auth.activeTeam != null)
              Text(
                auth.activeTeam!.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider(teamId));
        },
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text('Error: $e'),
                TextButton(
                  onPressed: () => ref.invalidate(dashboardProvider(teamId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4, vertical: AppSpacing.sm),
            children: [
              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.1,
                children: [
                  StatCard(
                    title: 'Ventas hoy',
                    value: cop.format(data.todayRevenue),
                    icon: Icons.trending_up_rounded,
                    color: colorScheme.primary,
                    subtitle: '${data.todaySalesCount} transacciones',
                    onTap: () => context.go('/sales'),
                  ),
                  StatCard(
                    title: 'Productos',
                    value: '${data.totalProducts}',
                    icon: Icons.inventory_2_rounded,
                    color: colorScheme.secondary,
                    subtitle: '${data.totalCategories} categorías',
                    onTap: () => context.go('/products'),
                  ),
                  StatCard(
                    title: 'Stock bajo',
                    value: '${data.lowStockProducts.length}',
                    icon: Icons.warning_rounded,
                    color: data.lowStockProducts.isEmpty
                        ? AppColors.success
                        : AppColors.warning,
                    subtitle: data.lowStockProducts.isEmpty
                        ? 'Todo bien'
                        : 'Requiere atención',
                    onTap: () => context.go('/inventory'),
                  ),
                  StatCard(
                    title: 'Total ventas',
                    value: '${data.totalSales}',
                    icon: Icons.receipt_long_rounded,
                    color: colorScheme.tertiary,
                    onTap: () => context.go('/sales'),
                  ),
                ],
              ),

              // Low stock alert
              if (data.lowStockProducts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stock bajo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/inventory'),
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...data.lowStockProducts.take(3).map(
                      (p) => Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 20,
                            ),
                          ),
                          title: Text(p.name),
                          subtitle: Text('Stock: ${p.stock} / Mín: ${p.minStock}'),
                          trailing: FilledButton.tonal(
                            onPressed: () => context.go('/inventory'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('+ Stock'),
                          ),
                          onTap: () => context.go('/inventory'),
                        ),
                      ),
                    ),
              ],

              // Recent sales
              if (data.recentSales.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ventas recientes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/sales'),
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...data.recentSales.map(
                  (s) => Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            s.saleNumber.isNotEmpty
                                ? s.saleNumber.split('-').last
                                : '#',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                      title: Text(cop.format(s.totalAmount)),
                      subtitle: Text(
                        s.customerName ?? 'Venta directa',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Text(
                        DateFormat('HH:mm').format(s.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'voice',
            onPressed: () => context.push('/voice-transaction'),
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: AppSpacing.sm),
          FloatingActionButton.extended(
            heroTag: 'sale',
            onPressed: () => context.go('/sales/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }
}

