import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/widgets/stat_card.dart';

final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardData, String>((ref, teamId) {
  return ref.read(dashboardRepositoryProvider).getDashboardData(teamId);
});

final aiInsightProvider =
    FutureProvider.autoDispose.family<AiInsight?, String>((ref, teamId) async {
  try {
    return await ref.read(aiServiceProvider).getDashboardInsights(teamId);
  } catch (_) {
    return null;
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final teamId = auth.teamId;
    final dashboard = ref.watch(dashboardProvider(teamId));
    final aiInsight = ref.watch(aiInsightProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${auth.user?.firstName ?? ''}!',
              style: Theme.of(context).textTheme.titleMedium,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider(teamId));
          ref.invalidate(aiInsightProvider(teamId));
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
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // AI Insight card
              aiInsight.whenOrNull(
                    data: (insight) => insight != null
                        ? _AiInsightCard(insight: insight)
                        : null,
                  ) ??
                  const SizedBox.shrink(),
              if (aiInsight.valueOrNull != null)
                const SizedBox(height: AppSpacing.md),

              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.5,
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
                        ? Colors.green
                        : Colors.orange,
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
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(p.name),
                          subtitle: Text('Stock: ${p.stock} / Mín: ${p.minStock}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/products/${p.id}/edit'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/sales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta'),
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  final AiInsight insight;

  const _AiInsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Insights de IA',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              insight.summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (insight.recommendations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...insight.recommendations.take(2).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              r,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
