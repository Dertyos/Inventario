import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/sale_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/providers/cache_for.dart';
import '../../../credits/data/credits_repository.dart';
import '../../data/sales_repository.dart';

final salesProvider =
    FutureProvider.autoDispose.family<List<SaleModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(salesRepositoryProvider).getSales(teamId);
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String? _expandedSaleId;

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final auth = ref.watch(authProvider);
    final sales = ref.watch(salesProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy', 'es');

    final canEdit = auth.hasPermission('sales.edit');
    final canDelete = auth.hasPermission('sales.delete');
    final canCancel = auth.hasPermission('sales.cancel');

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
                      (sale) => _SaleCard(
                        sale: sale,
                        isExpanded: _expandedSaleId == sale.id,
                        onTap: () {
                          setState(() {
                            _expandedSaleId =
                                _expandedSaleId == sale.id ? null : sale.id;
                          });
                        },
                        canEdit: canEdit,
                        canDelete: canDelete,
                        canCancel: canCancel,
                        onEdit: canEdit && !sale.isCancelled
                            ? () => context.push('/sales/${sale.id}/edit')
                            : null,
                        onCancel: canCancel && !sale.isCancelled
                            ? () => _confirmCancel(context, ref, teamId, sale)
                            : null,
                        onDelete: canDelete && sale.isCancelled
                            ? () => _confirmDelete(context, ref, teamId, sale)
                            : null,
                        onPaymentRegistered: () =>
                            ref.invalidate(salesProvider(teamId)),
                        cop: cop,
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

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    SaleModel sale,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar venta'),
        content: Text(
          '¿Cancelar la venta ${sale.saleNumber}? Se restaurará el stock de los productos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(salesRepositoryProvider).cancelSale(teamId, sale.id);
      ref.invalidate(salesProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta cancelada')),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    SaleModel sale,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar venta'),
        content: Text(
          '¿Eliminar permanentemente la venta ${sale.saleNumber}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(salesRepositoryProvider).deleteSale(teamId, sale.id);
      ref.invalidate(salesProvider(teamId));
      if (mounted) {
        setState(() => _expandedSaleId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta eliminada')),
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
}

class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool canEdit;
  final bool canDelete;
  final bool canCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onPaymentRegistered;
  final NumberFormat cop;

  const _SaleCard({
    required this.sale,
    required this.isExpanded,
    required this.onTap,
    required this.canEdit,
    required this.canDelete,
    required this.canCancel,
    this.onEdit,
    this.onCancel,
    this.onDelete,
    this.onPaymentRegistered,
    required this.cop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Header row (always visible)
            ListTile(
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
                    ].join(' \u00b7 '),
                  ),
                  if (sale.isCredit &&
                      sale.creditNextPayment != null &&
                      sale.creditBalance > 0)
                    Text(
                      'Prox. cuota: ${DateFormat('dd MMM yyyy', 'es').format(sale.creditNextPayment!)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.orange),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(sale.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Expandable detail section
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(context, colorScheme),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Items list
          if (sale.items.isNotEmpty) ...[
            Text(
              'Productos',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...sale.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName ?? item.productId,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.quantity} x ${cop.format(item.unitPrice)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 70,
                      child: Text(
                        cop.format(item.subtotal),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // Payment info
          Row(
            children: [
              Icon(
                _paymentIcon(sale.paymentMethod),
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _paymentLabel(sale.paymentMethod),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    sale.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
          // Quick pay button for credit sales
          if (sale.isCredit &&
              !sale.isCancelled &&
              sale.creditBalance > 0 &&
              sale.creditAccountId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await context.push('/credits/${sale.creditAccountId}');
                  onPaymentRegistered?.call();
                },
                icon: const Icon(Icons.payment_outlined, size: 18),
                label: Text(
                  'Registrar Abono · Debe ${cop.format(sale.creditBalance)}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          // Action buttons
          if (onEdit != null || onCancel != null || onDelete != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: Icon(Icons.block_outlined,
                        size: 18, color: colorScheme.error),
                    label: Text('Cancelar',
                        style: TextStyle(color: colorScheme.error)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: colorScheme.error),
                    label: Text('Eliminar',
                        style: TextStyle(color: colorScheme.error)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _paymentIcon(String? method) {
    switch (method) {
      case 'card':
        return Icons.credit_card_outlined;
      case 'transfer':
        return Icons.swap_horiz_outlined;
      case 'credit':
        return Icons.calendar_month_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'credit':
        return 'Credito';
      default:
        return 'Efectivo';
    }
  }
}
