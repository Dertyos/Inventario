import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/models/inventory_movement_model.dart';
import '../../../../shared/models/purchase_model.dart';
import '../../../../shared/models/supplier_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_modal.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../purchases/data/purchases_repository.dart';
import '../../data/suppliers_repository.dart';

final _currency =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _date = DateFormat('d MMM yyyy', 'es');

final _supplierPurchasesProvider = FutureProvider.autoDispose
    .family<List<PurchaseModel>, ({String teamId, String supplierId})>(
        (ref, params) {
  return ref
      .read(purchasesRepositoryProvider)
      .getPurchases(params.teamId, supplierId: params.supplierId);
});

final _supplierMovementsProvider = FutureProvider.autoDispose
    .family<List<InventoryMovementModel>, ({String teamId, String supplierId})>(
        (ref, params) {
  return ref
      .read(inventoryRepositoryProvider)
      .getMovements(params.teamId, supplierId: params.supplierId);
});

class SupplierDetailScreen extends ConsumerWidget {
  final String supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final supplierAsync = ref.watch(
      supplierDetailProvider((teamId: teamId, supplierId: supplierId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: supplierAsync.maybeWhen(
          data: (s) => Text(s.name),
          orElse: () => const Text('Proveedor'),
        ),
        actions: [
          supplierAsync.maybeWhen(
            data: (s) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => _showEditModal(context, ref, teamId, s),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: supplierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(supplierDetailProvider(
                      (teamId: teamId, supplierId: supplierId))),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (supplier) => _SupplierBody(supplier: supplier),
      ),
    );
  }

  void _showEditModal(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    SupplierModel supplier,
  ) {
    final nameCtrl = TextEditingController(text: supplier.name);
    final phoneCtrl = TextEditingController(text: supplier.phone ?? '');
    final nitCtrl = TextEditingController(text: supplier.nit ?? '');
    final contactCtrl =
        TextEditingController(text: supplier.contactName ?? '');

    showAppModal(
      context: context,
      title: 'Editar proveedor',
      children: [
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: nitCtrl,
          decoration: const InputDecoration(
            labelText: 'NIT',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: contactCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de contacto',
            prefixIcon: Icon(Icons.person_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final ctx = context;
            try {
              await ref.read(suppliersRepositoryProvider).updateSupplier(
                teamId,
                supplier.id,
                {
                  'name': nameCtrl.text.trim(),
                  if (nitCtrl.text.trim().isNotEmpty)
                    'nit': nitCtrl.text.trim(),
                  if (contactCtrl.text.trim().isNotEmpty)
                    'contactName': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                },
              );
              ref.invalidate(supplierDetailProvider(
                  (teamId: teamId, supplierId: supplier.id)));
              ref.invalidate(suppliersProvider(teamId));
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SupplierBody extends ConsumerWidget {
  final SupplierModel supplier;

  const _SupplierBody({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final teamName = ref.watch(authProvider).activeTeam?.name ?? '';
    final purchasesAsync = ref.watch(
      _supplierPurchasesProvider((teamId: teamId, supplierId: supplier.id)),
    );
    final movementsAsync = ref.watch(
      _supplierMovementsProvider((teamId: teamId, supplierId: supplier.id)),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(supplierDetailProvider(
            (teamId: teamId, supplierId: supplier.id)));
        ref.invalidate(_supplierPurchasesProvider(
            (teamId: teamId, supplierId: supplier.id)));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Info card ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            supplier.name[0].toUpperCase(),
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier.name,
                                style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600)),
                            if (supplier.nit != null)
                              Text(
                                'NIT: ${supplier.nit}',
                                style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (supplier.contactName != null) ...[
                    _InfoRow(
                      icon: Icons.person_outlined,
                      text: supplier.contactName!,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (supplier.phone != null) ...[
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      text: supplier.phone!,
                      onTap: () => openPhone(context, supplier.phone!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (supplier.email != null)
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text: supplier.email!,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Acciones ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone_rounded),
                  label: const Text('Llamar'),
                  onPressed: supplier.phone != null
                      ? () => openPhone(context, supplier.phone!)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: supplier.phone != null
                        ? const Color(0xFF25D366)
                        : null,
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WhatsApp'),
                  onPressed: supplier.phone != null
                      ? () => openWhatsApp(
                            context,
                            supplier.phone!,
                            'Hola ${supplier.contactName ?? supplier.name}, te escribo de $teamName.',
                          )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Historial de compras ───────────────────────────────
          Text('Historial de compras',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),

          purchasesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Error al cargar compras',
                  style: TextStyle(color: colorScheme.error)),
            ),
            data: (purchases) {
              if (purchases.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Center(
                    child: Text(
                      'Sin compras registradas',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              final totalSpent =
                  purchases.fold<double>(0, (sum, p) => sum + p.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatChip(
                          label: '${purchases.length} órdenes',
                          icon: Icons.shopping_bag_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      _StatChip(
                          label: _currency.format(totalSpent),
                          icon: Icons.attach_money_rounded),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...purchases.map((p) => _PurchaseTile(purchase: p)),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Movimientos de inventario ─────────────────────────
          Text('Movimientos de inventario',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),

          movementsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Error al cargar movimientos',
                  style: TextStyle(color: colorScheme.error)),
            ),
            data: (movements) {
              if (movements.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Center(
                    child: Text(
                      'Sin movimientos registrados',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              return Column(
                children: movements.map((m) => _MovementTile(movement: m)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onTap != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final PurchaseModel purchase;

  const _PurchaseTile({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    StatusBadge badge;
    switch (purchase.status) {
      case 'received':
        badge = StatusBadge.success('Recibida');
        break;
      case 'cancelled':
        badge = StatusBadge.danger('Cancelada');
        break;
      default:
        badge = StatusBadge.warning('Pendiente');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shopping_bag_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onTertiaryContainer),
        ),
        title: Text(
          purchase.purchaseNumber.isNotEmpty
              ? '#${purchase.purchaseNumber}'
              : 'Orden',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _date.format(purchase.createdAt),
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currency.format(purchase.total),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            badge,
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryMovementModel movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEntry = movement.type == 'in' || movement.type == 'purchase';
    final sign = isEntry ? '+' : '-';
    final color = isEntry ? AppColors.success : AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEntry
                ? AppColors.successBg(context)
                : AppColors.dangerBg(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isEntry ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: color,
          ),
        ),
        title: Text(
          movement.productName,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            movement.typeLabel,
            if (movement.reason != null && movement.reason!.isNotEmpty)
              movement.reason!,
          ].join(' · '),
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${movement.quantity}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              _date.format(movement.createdAt),
              style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
