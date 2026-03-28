import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/offline/pending_sales_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/widgets/home_widget_updater.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/mini_line_chart.dart';
import '../../../../core/providers/cache_for.dart';
import '../../../../shared/widgets/expandable_fab.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../suppliers/data/suppliers_repository.dart';

final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardData, String>((ref, teamId) async {
  ref.cacheFor(const Duration(minutes: 5));
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
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(reportsRepositoryProvider).getSummary(teamId);
});

enum DashboardPeriod { today, week, month }

final _dashboardPeriodProvider = StateProvider<DashboardPeriod>((ref) {
  return DashboardPeriod.today;
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
              '\u00a1Hola${auth.user?.firstName != null && auth.user!.firstName.isNotEmpty ? ', ${auth.user!.firstName}' : ''}!',
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
            final selectedPeriod = ref.watch(_dashboardPeriodProvider);
            final periodLabels = {
              DashboardPeriod.today: 'Hoy',
              DashboardPeriod.week: 'Semana',
              DashboardPeriod.month: '30 días',
            };
            return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4, vertical: AppSpacing.md),
            children: [
              // Period selector chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: DashboardPeriod.values.map((period) {
                    final isSelected = period == selectedPeriod;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(periodLabels[period]!),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(_dashboardPeriodProvider.notifier).state = period;
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ).animate()
                  .fadeIn(duration: AppAnimations.normal)
                  .slideX(begin: -0.05, end: 0, duration: AppAnimations.normal),
              const SizedBox(height: AppSpacing.md),

              // Hero metric card (graceful degradation)
              if (summaryAsync.value != null)
                _buildHeroMetric(context, summaryAsync.value!, cop, colorScheme, selectedPeriod)
                    .animate()
                    .fadeIn(duration: AppAnimations.normal, delay: 100.ms)
                    .slideY(begin: 0.05, end: 0, duration: AppAnimations.normal),

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
                    color: const Color(0xFFFF6B6B),
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
                    color: const Color(0xFFFF6B6B),
                    onTap: () => context.go('/sales'),
                  ),
                ],
              ).animate()
                  .fadeIn(duration: AppAnimations.normal, delay: 150.ms)
                  .slideY(begin: 0.05, end: 0, duration: AppAnimations.normal),

              // Low stock alert
              if (data.lowStockProducts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_rounded,
                                  color: Color(0xFF25D366),
                                ),
                                tooltip: 'Pedir a proveedor',
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (_) => _OrderSupplierSheet(
                                    product: p,
                                    teamId: teamId,
                                    teamName: auth.activeTeam?.name ?? '',
                                  ),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () => context.go('/inventory'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                                child: const Text('+ Stock'),
                              ),
                            ],
                          ),
                          onTap: () => context.go('/inventory'),
                        ),
                      ),
                    ),
              ],

              // Recent sales
              if (data.recentSales.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
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

              // Extra bottom padding so content clears the expanded FAB
              // (3 actions ≈ 48px each + main FAB 56px + margins ≈ 220px)
              const SizedBox(height: 240),
            ],
          );
          },
        ),
      ),
          ),
        ],
      ),
      floatingActionButton: ExpandableFab(
        actions: [
          FabAction(
            icon: Icons.qr_code_scanner,
            label: 'Escanear',
            color: colorScheme.tertiaryContainer,
            foregroundColor: colorScheme.onTertiaryContainer,
            onPressed: () => context.push('/scanner'),
          ),
          FabAction(
            icon: Icons.mic,
            label: 'Voz',
            color: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            onPressed: () => context.push('/voice-transaction'),
          ),
          FabAction(
            icon: Icons.point_of_sale_rounded,
            label: 'Nueva venta',
            onPressed: () => context.push('/sales/new'),
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
    DashboardPeriod period,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final double revenue;
    final int transactions;
    final double change;
    final String comparisonLabel;

    switch (period) {
      case DashboardPeriod.today:
        revenue = summary.todayRevenue;
        transactions = summary.todayTransactions;
        change = summary.changePercent;
        comparisonLabel = 'vs ayer';
      case DashboardPeriod.week:
        revenue = summary.weekRevenue;
        transactions = summary.weekTransactions;
        change = summary.weekChangePercent;
        comparisonLabel = 'vs semana anterior';
      case DashboardPeriod.month:
        revenue = summary.monthRevenue;
        transactions = summary.monthTransactions;
        change = summary.monthChangePercent;
        comparisonLabel = 'vs 30 días anteriores';
    }

    final isPositive = change >= 0;

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
                cop.format(revenue),
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$transactions transacciones'
                '${change != 0 ? ' \u00b7 ${isPositive ? '+' : ''}${change.toStringAsFixed(1)}% $comparisonLabel' : ''}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              () {
                final chartData = period == DashboardPeriod.month
                    ? summary.last30DaysRevenue
                    : summary.last7DaysRevenue;
                if (chartData.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: MiniLineChart(
                      data: chartData,
                      color: colorScheme.primary,
                      height: 60,
                    ),
                  );
                }
                return const SizedBox.shrink();
              }(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSupplierSheet extends ConsumerStatefulWidget {
  final ProductModel product;
  final String teamId;
  final String teamName;

  const _OrderSupplierSheet({
    required this.product,
    required this.teamId,
    required this.teamName,
  });

  @override
  ConsumerState<_OrderSupplierSheet> createState() =>
      _OrderSupplierSheetState();
}

class _OrderSupplierSheetState extends ConsumerState<_OrderSupplierSheet> {
  late int _quantity;
  final _qtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantity =
        (widget.product.minStock - widget.product.stock).clamp(1, 9999);
    _qtyController.text = _quantity.toString();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider(widget.teamId));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pedir ${widget.product.name}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'Stock actual: ${widget.product.stock} / Mínimo: ${widget.product.minStock}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad a pedir',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && parsed > 0) _quantity = parsed;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Selecciona proveedor',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          suppliersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error al cargar proveedores: $e'),
            data: (suppliers) {
              if (suppliers.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No hay proveedores registrados.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final sorted = [...suppliers]
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final s = sorted[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          s.name[0].toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    title: Text(s.name),
                    subtitle: s.phone != null ? Text(s.phone!) : null,
                    trailing: s.phone != null
                        ? const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366))
                        : const Icon(Icons.phone_disabled_outlined),
                    onTap: s.phone == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            final msg =
                                'Hola ${s.contactName ?? s.name}, necesito $_quantity unidades de ${widget.product.name}. — ${widget.teamName}';
                            openWhatsApp(context, s.phone!, msg);
                          },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
