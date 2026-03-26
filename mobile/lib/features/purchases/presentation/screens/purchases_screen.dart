import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/purchase_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/purchases_repository.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final purchases = ref.watch(purchasesProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: purchases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Sin compras',
              subtitle: 'Registra tu primera orden de compra',
              actionLabel: 'Nueva compra',
              onAction: () => context.push('/purchases/new'),
            );
          }

          // Group by date
          final grouped = <String, List<PurchaseModel>>{};
          for (final purchase in items) {
            final key = dateFormat.format(purchase.createdAt);
            grouped.putIfAbsent(key, () => []).add(purchase);
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(purchasesProvider(teamId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final date = grouped.keys.elementAt(index);
                final dayPurchases = grouped[date]!;
                final dayTotal = dayPurchases
                    .where((p) => !p.isCancelled)
                    .fold<double>(0, (sum, p) => sum + p.total);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
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
                    ...dayPurchases.map(
                      (purchase) => Card(
                        margin:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          onTap: purchase.isPending
                              ? () => _showActions(
                                  context, ref, teamId, purchase)
                              : null,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _statusBgColor(
                                  context, purchase.status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _statusIcon(purchase.status),
                              size: 20,
                              color:
                                  _statusFgColor(purchase.status),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(cop.format(purchase.total)),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusBadge(
                                  label: purchase.statusLabel,
                                  status: purchase.status),
                            ],
                          ),
                          subtitle: Text(
                            [
                              purchase.purchaseNumber,
                              purchase.supplierName ?? 'Sin proveedor',
                              '${purchase.items.length} producto${purchase.items.length == 1 ? '' : 's'}',
                            ].join(' \u00b7 '),
                          ),
                          trailing: Text(
                            DateFormat('HH:mm').format(purchase.createdAt),
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
        onPressed: () => context.push('/purchases/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva compra'),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, String teamId,
      PurchaseModel purchase) {
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${purchase.purchaseNumber} \u00b7 ${cop.format(purchase.total)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (purchase.items.isNotEmpty)
              ...purchase.items.map(
                (item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined, size: 20),
                  title: Text(item.productName ?? 'Producto'),
                  trailing: Text(
                    '${item.quantity} x ${cop.format(item.unitCost)}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: AppColors.success),
              title: const Text('Recibir compra'),
              subtitle: const Text(
                  'Agrega el stock de los productos al inventario'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmReceive(context, ref, teamId, purchase);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.cancel_outlined, color: AppColors.danger),
              title: const Text('Cancelar compra'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmCancel(context, ref, teamId, purchase);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReceive(BuildContext context, WidgetRef ref,
      String teamId, PurchaseModel purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recibir compra'),
        content: Text(
          '\u00bfConfirmar la recepci\u00f3n de ${purchase.purchaseNumber}? '
          'Se agregar\u00e1 el stock de los productos al inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recibir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(purchasesRepositoryProvider)
          .receivePurchase(teamId, purchase.id);
      ref.invalidate(purchasesProvider(teamId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra recibida. Stock actualizado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref,
      String teamId, PurchaseModel purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar compra'),
        content: Text(
          '\u00bfCancelar ${purchase.purchaseNumber}? Esta acci\u00f3n no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('S\u00ed, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(purchasesRepositoryProvider)
          .cancelPurchase(teamId, purchase.id);
      ref.invalidate(purchasesProvider(teamId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra cancelada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _statusBgColor(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return AppColors.warningBg(context);
      case 'received':
        return AppColors.successBg(context);
      case 'cancelled':
        return AppColors.dangerBg(context);
      default:
        return AppColors.infoBg(context);
    }
  }

  Color _statusFgColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'received':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_outlined;
      case 'received':
        return Icons.check_circle_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.shopping_cart_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'pending':
        bg = AppColors.warningBg(context);
        fg = AppColors.warning;
        break;
      case 'received':
        bg = AppColors.successBg(context);
        fg = AppColors.success;
        break;
      case 'cancelled':
        bg = AppColors.dangerBg(context);
        fg = AppColors.danger;
        break;
      default:
        bg = AppColors.infoBg(context);
        fg = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
