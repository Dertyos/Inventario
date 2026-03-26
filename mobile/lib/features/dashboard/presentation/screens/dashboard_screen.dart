import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/offline/pending_sales_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/home_widget_updater.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/mini_line_chart.dart';
import '../../../reports/data/reports_repository.dart';

final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardData, String>((ref, teamId) async {
  final data = await ref.read(dashboardRepositoryProvider).getDashboardData(teamId);
  // Push metrics to home screen widget
  HomeWidgetUpdater.updateDashboard(
    todayRevenue: data.todayRevenue,
    todaySalesCount: data.todaySalesCount,
    totalProducts: data.totalProducts,
    lowStockCount: data.lowStockProducts.length,
  );
  return data;
});

final analyticsSummaryProvider =
    FutureProvider.autoDispose.family<AnalyticsSummary, String>((ref, teamId) {
  return ref.read(reportsRepositoryProvider).getSummary(teamId);
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
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
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
          data: (data) {
            // Check low stock alerts once per session
            NotificationService().checkLowStockAlerts(data.lowStockProducts);
            final summaryAsync = ref.watch(analyticsSummaryProvider(teamId));
            final pendingCount = ref.watch(pendingSalesCountProvider).value ?? 0;
            return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4, vertical: AppSpacing.sm),
            children: [
              // Hero metric card (graceful degradation)
              if (summaryAsync.value != null)
                _buildHeroMetric(context, summaryAsync.value!, cop, colorScheme),

              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.0,
                children: [
                  StatCard(
                    title: 'Ventas hoy',
                    value: cop.format(data.todayRevenue),
                    icon: Icons.trending_up_rounded,
                    color: colorScheme.primary,
                    subtitle: pendingCount > 0
                        ? '${data.todaySalesCount} trans. · $pendingCount pendientes'
                        : '${data.todaySalesCount} transacciones',
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
          );
          },
        ),
      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'scanner',
            onPressed: () => context.push('/scanner'),
            backgroundColor: colorScheme.tertiaryContainer,
            foregroundColor: colorScheme.onTertiaryContainer,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: AppSpacing.sm),
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
            onPressed: () => context.push('/sales/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(
    BuildContext context,
    AnalyticsSummary summary,
    NumberFormat cop,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final isPositive = summary.changePercent >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        color: colorScheme.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cop.format(summary.todayRevenue),
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${summary.todayTransactions} transacciones'
                '${summary.changePercent != 0 ? ' \u00b7 ${isPositive ? '+' : ''}${summary.changePercent.toStringAsFixed(1)}% vs ayer' : ''}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (summary.last7DaysRevenue.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                MiniLineChart(
                  data: summary.last7DaysRevenue,
                  color: colorScheme.primary,
                  height: 60,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

