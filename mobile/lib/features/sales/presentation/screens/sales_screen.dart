import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/sale_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/sales_repository.dart';

final salesProvider =
    FutureProvider.autoDispose.family<List<SaleModel>, String>((ref, teamId) {
  return ref.read(salesRepositoryProvider).getSales(teamId);
});

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final sales = ref.watch(salesProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sin ventas',
              subtitle: 'Registra tu primera venta',
              actionLabel: 'Nueva venta',
              onAction: () => context.push('/sales/new'),
            );
          }

          // Group by date
          final grouped = <String, List<SaleModel>>{};
          for (final sale in items) {
            final key = dateFormat.format(sale.createdAt);
            grouped.putIfAbsent(key, () => []).add(sale);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(salesProvider(teamId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final date = grouped.keys.elementAt(index);
                final daySales = grouped[date]!;
                final dayTotal = daySales
                    .where((s) => !s.isCancelled)
                    .fold<double>(0, (sum, s) => sum + s.totalAmount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            cop.format(dayTotal),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    ...daySales.map(
                      (sale) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: sale.isCancelled
                                  ? colorScheme.errorContainer
                                  : sale.isCredit
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              sale.isCancelled
                                  ? Icons.cancel_outlined
                                  : sale.isCredit
                                      ? Icons.credit_score_outlined
                                      : Icons.receipt_outlined,
                              size: 20,
                              color: sale.isCancelled
                                  ? colorScheme.onErrorContainer
                                  : sale.isCredit
                                      ? Colors.orange
                                      : colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                cop.format(sale.totalAmount),
                                style: TextStyle(
                                  decoration: sale.isCancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (sale.isCancelled) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Cancelada',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                              ],
                              if (sale.isCredit && !sale.isCancelled) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sale.creditBalance > 0
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sale.creditBalance > 0
                                        ? 'Debe ${cop.format(sale.creditBalance)}'
                                        : 'Pagado',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: sale.creditBalance > 0
                                              ? Colors.orange
                                              : Colors.green,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  sale.saleNumber,
                                  sale.customerName ?? 'Venta directa',
                                  if (sale.isCredit) ...[
                                    if (sale.creditInstallments != null)
                                      '${sale.creditInstallments} cuotas',
                                    sale.creditFrequencyLabel,
                                    if (sale.creditInterestRate != null &&
                                        sale.creditInterestRate! > 0)
                                      '${sale.creditInterestRate}%',
                                  ],
                                ].join(' · '),
                              ),
                              if (sale.isCredit &&
                                  sale.creditNextPayment != null &&
                                  sale.creditBalance > 0)
                                Text(
                                  'Próx. cuota: ${DateFormat('dd MMM yyyy', 'es').format(sale.creditNextPayment!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.orange),
                                ),
                            ],
                          ),
                          trailing: Text(
                            DateFormat('HH:mm').format(sale.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta'),
      ),
    );
  }
}
