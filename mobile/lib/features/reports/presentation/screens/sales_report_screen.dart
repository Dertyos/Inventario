import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/reports_repository.dart';

final _selectedPeriodProvider = StateProvider.autoDispose<String>((ref) => '30d');

final salesAnalyticsProvider = FutureProvider.autoDispose
    .family<SalesAnalytics, ({String teamId, String period})>((ref, params) {
  return ref
      .read(reportsRepositoryProvider)
      .getSalesAnalytics(params.teamId, period: params.period);
});

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final teamId = auth.teamId;
    final period = ref.watch(_selectedPeriodProvider);
    final analyticsAsync =
        ref.watch(salesAnalyticsProvider((teamId: teamId, period: period)));
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) =>
                _handleMenuAction(context, ref, value, teamId, period),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Exportar CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Compartir por WhatsApp'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _PeriodChip(
                  label: '7 dias',
                  value: '7d',
                  selected: period == '7d',
                  onTap: () =>
                      ref.read(_selectedPeriodProvider.notifier).state = '7d',
                ),
                const SizedBox(width: AppSpacing.sm),
                _PeriodChip(
                  label: '30 dias',
                  value: '30d',
                  selected: period == '30d',
                  onTap: () =>
                      ref.read(_selectedPeriodProvider.notifier).state = '30d',
                ),
                const SizedBox(width: AppSpacing.sm),
                _PeriodChip(
                  label: 'Este mes',
                  value: 'month',
                  selected: period == 'month',
                  onTap: () => ref
                      .read(_selectedPeriodProvider.notifier)
                      .state = 'month',
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: analyticsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Error: $e'),
                    TextButton(
                      onPressed: () => ref.invalidate(salesAnalyticsProvider(
                          (teamId: teamId, period: period))),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(salesAnalyticsProvider(
                      (teamId: teamId, period: period)));
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 4,
                      vertical: AppSpacing.sm),
                  children: [
                    // Hero card
                    _HeroRevenueCard(data: data, cop: cop),
                    const SizedBox(height: AppSpacing.lg),

                    // Revenue line chart
                    if (data.dailyRevenue.isNotEmpty) ...[
                      Text(
                        'Ventas por dia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RevenueLineChart(
                        dailyRevenue: data.dailyRevenue,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Top products
                    if (data.topProducts.isNotEmpty) ...[
                      Text(
                        'Top productos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _TopProductsChart(
                        products: data.topProducts.take(5).toList(),
                        cop: cop,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Payment methods
                    if (data.paymentMethods.isNotEmpty) ...[
                      Text(
                        'Metodos de pago',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _PaymentMethodsBar(methods: data.paymentMethods),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String teamId,
    String period,
  ) async {
    if (action == 'csv') {
      try {
        final csv = await ref
            .read(reportsRepositoryProvider)
            .exportSalesCsv(teamId);
        await SharePlus.instance.share(ShareParams(text: csv, title: 'Reporte de ventas'));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al exportar: $e')),
          );
        }
      }
    } else if (action == 'whatsapp') {
      final analytics = ref
          .read(salesAnalyticsProvider((teamId: teamId, period: period)))
          .valueOrNull;
      if (analytics == null) return;

      final cop = NumberFormat.currency(
          locale: 'es_CO', symbol: '\$', decimalDigits: 0);
      final now = DateTime.now();
      final days = period == '7d' ? 7 : 30;
      final startDate = DateFormat('dd/MM/yyyy')
          .format(now.subtract(Duration(days: days)));
      final endDate = DateFormat('dd/MM/yyyy').format(now);

      final topProduct = analytics.topProducts.isNotEmpty
          ? analytics.topProducts.first
          : null;

      final message = StringBuffer()
        ..writeln('\u{1F4CA} *Inventario - Reporte*')
        ..writeln(
            '\u{1F4C5} Periodo: $startDate - $endDate')
        ..writeln()
        ..writeln(
            '\u{1F4B0} Total ventas: ${cop.format(analytics.totalRevenue)}')
        ..writeln(
            '\u{1F4E6} Transacciones: ${analytics.totalTransactions}');
      if (topProduct != null) {
        message.writeln(
            '\u{1F3C6} Top producto: ${topProduct.name} (${cop.format(topProduct.revenue)})');
      }
      message.writeln()
        ..writeln('Generado por Inventario App');

      final encoded = Uri.encodeComponent(message.toString());
      final url = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _HeroRevenueCard extends StatelessWidget {
  final SalesAnalytics data;
  final NumberFormat cop;

  const _HeroRevenueCard({required this.data, required this.cop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = data.percentChange >= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      color: colorScheme.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total ventas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              cop.format(data.totalRevenue),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 18,
                  color: isPositive ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}${data.percentChange.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            isPositive ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${data.totalTransactions} transacciones',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueLineChart extends StatelessWidget {
  final List<DailyRevenue> dailyRevenue;
  final Color color;

  const _RevenueLineChart({
    required this.dailyRevenue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = dailyRevenue.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final padding = (maxY - minY) * 0.15;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _bottomInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dailyRevenue.length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.tryParse(dailyRevenue[index].date);
                  if (date == null) return const SizedBox.shrink();

                  final labels = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
                  final label = dailyRevenue.length <= 7
                      ? labels[date.weekday % 7]
                      : DateFormat('dd').format(date);

                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          minY: minY > 0 ? (minY - padding).clamp(0, double.infinity) : minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final cop = NumberFormat.currency(
                      locale: 'es_CO', symbol: '\$', decimalDigits: 0);
                  return LineTooltipItem(
                    cop.format(spot.y),
                    TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: false,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _bottomInterval {
    final count = dailyRevenue.length;
    if (count <= 7) return 1;
    if (count <= 15) return 2;
    return (count / 6).ceilToDouble();
  }
}

class _TopProductsChart extends StatelessWidget {
  final List<TopProduct> products;
  final NumberFormat cop;

  const _TopProductsChart({required this.products, required this.cop});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final maxRevenue =
        products.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      AppColors.info,
      AppColors.success,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: products.asMap().entries.map((entry) {
            final i = entry.key;
            final product = entry.value;
            final fraction =
                maxRevenue > 0 ? product.revenue / maxRevenue : 0.0;
            final barColor = colors[i % colors.length];

            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < products.length - 1 ? AppSpacing.md : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        cop.format(product.revenue),
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest,
                      color: barColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PaymentMethodsBar extends StatelessWidget {
  final List<PaymentMethodBreakdown> methods;

  const _PaymentMethodsBar({required this.methods});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      AppColors.info,
      AppColors.warning,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Segmented bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: methods.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    return Expanded(
                      flex: (m.percentage * 100).round().clamp(1, 100),
                      child: Container(
                        color: colors[i % colors.length],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Legend
            ...methods.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i < methods.length - 1 ? AppSpacing.sm : 0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _methodLabel(m.method),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${(m.percentage * 100).toStringAsFixed(0)}%',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      cop.format(m.amount),
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'nequi':
        return 'Nequi';
      case 'daviplata':
        return 'Daviplata';
      default:
        return method;
    }
  }
}
