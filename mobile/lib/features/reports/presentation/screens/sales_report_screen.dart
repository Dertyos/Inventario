import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../core/providers/cache_for.dart';
import '../../data/reports_repository.dart';

// --- Providers ---

enum ReportPeriod { week, month, thisMonth }

final _selectedPeriodProvider = StateProvider<ReportPeriod>((ref) {
  return ReportPeriod.month;
});

String _periodQueryValue(ReportPeriod period) {
  switch (period) {
    case ReportPeriod.week:
      return '7d';
    case ReportPeriod.month:
      return '30d';
    case ReportPeriod.thisMonth:
      return 'this_month';
  }
}

({String start, String end}) _periodDates(ReportPeriod period) {
  final now = DateTime.now();
  final fmt = DateFormat('yyyy-MM-dd');
  final end = fmt.format(now);
  switch (period) {
    case ReportPeriod.week:
      return (start: fmt.format(now.subtract(const Duration(days: 7))), end: end);
    case ReportPeriod.month:
      return (start: fmt.format(now.subtract(const Duration(days: 30))), end: end);
    case ReportPeriod.thisMonth:
      return (start: fmt.format(DateTime(now.year, now.month, 1)), end: end);
  }
}

final salesAnalyticsProvider = FutureProvider.autoDispose
    .family<SalesAnalytics, ({String teamId, ReportPeriod period})>(
        (ref, params) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(reportsRepositoryProvider).getSalesAnalytics(
        params.teamId,
        period: _periodQueryValue(params.period),
      );
});

// --- Screen ---

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'csv') {
                _exportCsv(context, ref, teamId, period);
              } else if (value == 'whatsapp') {
                _shareWhatsApp(context, ref, analyticsAsync, period, cop);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Exportar CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.chat_outlined, size: 20),
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
                  selected: period == ReportPeriod.week,
                  onTap: () => ref.read(_selectedPeriodProvider.notifier).state =
                      ReportPeriod.week,
                ),
                const SizedBox(width: AppSpacing.sm),
                _PeriodChip(
                  label: '30 dias',
                  selected: period == ReportPeriod.month,
                  onTap: () => ref.read(_selectedPeriodProvider.notifier).state =
                      ReportPeriod.month,
                ),
                const SizedBox(width: AppSpacing.sm),
                _PeriodChip(
                  label: 'Este mes',
                  selected: period == ReportPeriod.thisMonth,
                  onTap: () => ref.read(_selectedPeriodProvider.notifier).state =
                      ReportPeriod.thisMonth,
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(salesAnalyticsProvider(
                    (teamId: teamId, period: period)));
              },
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Error: $e'),
                          TextButton(
                            onPressed: () => ref.invalidate(
                                salesAnalyticsProvider(
                                    (teamId: teamId, period: period))),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                data: (data) => _ReportBody(data: data, cop: cop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref, String teamId,
      ReportPeriod period) async {
    try {
      final dates = _periodDates(period);
      final csv = await ref.read(reportsRepositoryProvider).exportSalesCsv(
            teamId,
            startDate: dates.start,
            endDate: dates.end,
          );
      // ignore: deprecated_member_use
      await Share.share(csv, subject: 'Ventas.csv');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  void _shareWhatsApp(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SalesAnalytics> analyticsAsync,
    ReportPeriod period,
    NumberFormat cop,
  ) {
    final data = analyticsAsync.value;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando datos...')),
      );
      return;
    }

    final dates = _periodDates(period);
    final topProduct =
        data.topProducts.isNotEmpty ? data.topProducts.first : null;

    final message = StringBuffer()
      ..writeln('\u{1F4CA} *Inventario - Reporte*')
      ..writeln('\u{1F4C5} Periodo: ${dates.start} - ${dates.end}')
      ..writeln()
      ..writeln('\u{1F4B0} Total ventas: ${cop.format(data.totalRevenue)}')
      ..writeln('\u{1F4E6} Transacciones: ${data.totalTransactions}');

    if (topProduct != null) {
      message.writeln(
          '\u{1F3C6} Top producto: ${topProduct.name} (${cop.format(topProduct.revenue)})');
    }

    message
      ..writeln()
      ..writeln('Generado por Inventario App');

    final encoded = Uri.encodeComponent(message.toString());
    final url = Uri.parse('https://wa.me/?text=$encoded');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

// --- Period Chip ---

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// --- Report Body ---

class _ReportBody extends StatelessWidget {
  final SalesAnalytics data;
  final NumberFormat cop;

  const _ReportBody({required this.data, required this.cop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final changePercent = data.changePercent;
    final isPositive = changePercent >= 0;

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 4, vertical: AppSpacing.sm),
      children: [
        // Hero card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          color: colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total ventas',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cop.format(data.totalRevenue),
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(1)}% vs periodo anterior',
                      style: textTheme.bodySmall?.copyWith(
                        color:
                            isPositive ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${data.totalTransactions} transacciones',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Revenue line chart
        if (data.dailyRevenue.isNotEmpty) ...[
          Text('Ventas por dia', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 200,
            child: _RevenueLineChart(
              dailyRevenue: data.dailyRevenue,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Top products
        if (data.topProducts.isNotEmpty) ...[
          Text('Top productos', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 220,
            child: _TopProductsChart(
              products: data.topProducts.take(5).toList(),
              cop: cop,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Payment methods
        if (data.paymentMethods.isNotEmpty) ...[
          Text('Metodos de pago', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _PaymentMethodsBar(methods: data.paymentMethods, cop: cop),
          const SizedBox(height: AppSpacing.sm),
          // Legend
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: data.paymentMethods.asMap().entries.map((entry) {
              final color = _paymentMethodColors[entry.key %
                  _paymentMethodColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.value.method} (${cop.format(entry.value.amount)})',
                    style: textTheme.bodySmall,
                  ),
                ],
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// --- Revenue Line Chart ---

class _RevenueLineChart extends StatelessWidget {
  final List<DailyRevenue> dailyRevenue;
  final Color color;

  const _RevenueLineChart({required this.dailyRevenue, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = dailyRevenue.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    final revenues = dailyRevenue.map((e) => e.revenue).toList();
    final maxY = revenues.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.15,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _bottomInterval(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dailyRevenue.length) {
                  return const SizedBox.shrink();
                }
                final date = DateTime.tryParse(dailyRevenue[idx].date);
                if (date == null) return const SizedBox.shrink();
                final labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                final label = dailyRevenue.length <= 7
                    ? labels[(date.weekday - 1) % 7]
                    : '${date.day}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
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
            dotData: const FlDotData(show: false),
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
    );
  }

  double _bottomInterval() {
    if (dailyRevenue.length <= 7) return 1;
    if (dailyRevenue.length <= 15) return 2;
    return (dailyRevenue.length / 7).ceilToDouble();
  }
}

// --- Top Products Bar Chart ---

class _TopProductsChart extends StatelessWidget {
  final List<TopProduct> products;
  final NumberFormat cop;

  const _TopProductsChart({required this.products, required this.cop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxRevenue = products
        .map((e) => e.revenue)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRevenue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${products[group.x.toInt()].name}\n${cop.format(rod.toY)}',
                TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= products.length) {
                  return const SizedBox.shrink();
                }
                final name = products[idx].name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 8)}...' : name,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: products.asMap().entries.map((entry) {
          final barColor = _barColors[entry.key % _barColors.length];
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.revenue,
                color: barColor,
                width: 28,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

const _barColors = [
  AppColors.info,
  AppColors.success,
  AppColors.warning,
  Color(0xFF9B59B6),
  Color(0xFF1ABC9C),
];

// --- Payment Methods Segmented Bar ---

const _paymentMethodColors = [
  AppColors.info,
  AppColors.success,
  AppColors.warning,
  Color(0xFF9B59B6),
  Color(0xFF1ABC9C),
];

class _PaymentMethodsBar extends StatelessWidget {
  final List<PaymentMethodBreakdown> methods;
  final NumberFormat cop;

  const _PaymentMethodsBar({required this.methods, required this.cop});

  @override
  Widget build(BuildContext context) {
    final total = methods.fold<double>(0, (sum, m) => sum + m.amount);
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 28,
        child: Row(
          children: methods.asMap().entries.map((entry) {
            final fraction = entry.value.amount / total;
            final color = _paymentMethodColors[
                entry.key % _paymentMethodColors.length];
            return Expanded(
              flex: (fraction * 1000).round().clamp(1, 1000),
              child: Container(
                color: color,
                alignment: Alignment.center,
                child: fraction > 0.12
                    ? Text(
                        '${(fraction * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
