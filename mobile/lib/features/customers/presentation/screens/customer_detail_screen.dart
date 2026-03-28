import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/models/sale_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_modal.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../sales/data/sales_repository.dart';
import '../../data/customers_repository.dart';
import 'customers_screen.dart';

final _currency =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _date = DateFormat('d MMM yyyy', 'es');

final _customerSalesProvider = FutureProvider.autoDispose
    .family<List<SaleModel>, ({String teamId, String customerId})>(
        (ref, params) {
  return ref
      .read(salesRepositoryProvider)
      .getSales(params.teamId, customerId: params.customerId);
});

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final customerAsync = ref.watch(
      customerDetailProvider((teamId: teamId, customerId: customerId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: customerAsync.maybeWhen(
          data: (c) => Text(c.name),
          orElse: () => const Text('Cliente'),
        ),
        actions: [
          customerAsync.maybeWhen(
            data: (c) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => _showEditModal(context, ref, teamId, c),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: customerAsync.when(
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
                  onPressed: () => ref.invalidate(customerDetailProvider(
                      (teamId: teamId, customerId: customerId))),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (customer) => _CustomerBody(customer: customer),
      ),
    );
  }

  void _showEditModal(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    CustomerModel customer,
  ) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? '');
    final emailCtrl = TextEditingController(text: customer.email ?? '');

    showAppModal(
      context: context,
      title: 'Editar cliente',
      children: [
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
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
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final ctx = context;
            try {
              await ref.read(customersRepositoryProvider).updateCustomer(
                teamId,
                customer.id,
                {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                },
              );
              ref.invalidate(
                  customerDetailProvider((teamId: teamId, customerId: customer.id)));
              ref.invalidate(customersProvider(teamId));
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

class _CustomerBody extends ConsumerWidget {
  final CustomerModel customer;

  const _CustomerBody({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final teamName = ref.watch(authProvider).activeTeam?.name ?? '';
    final salesAsync = ref.watch(
      _customerSalesProvider((teamId: teamId, customerId: customer.id)),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
            customerDetailProvider((teamId: teamId, customerId: customer.id)));
        ref.invalidate(
            _customerSalesProvider((teamId: teamId, customerId: customer.id)));
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
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            customer.name[0].toUpperCase(),
                            style: textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
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
                            Text(customer.name,
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (customer.documentType != null &&
                                customer.documentNumber != null)
                              Text(
                                '${customer.documentType} ${customer.documentNumber}',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (customer.phone != null) ...[
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      text: customer.phone!,
                      onTap: () => openPhone(context, customer.phone!),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (customer.email != null) ...[
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text: customer.email!,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (customer.address != null)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: customer.address!,
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
                  onPressed: customer.phone != null
                      ? () => openPhone(context, customer.phone!)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: customer.phone != null
                        ? const Color(0xFF25D366)
                        : null,
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('WhatsApp'),
                  onPressed: customer.phone != null
                      ? () => openWhatsApp(
                            context,
                            customer.phone!,
                            'Hola ${customer.name}, te escribo de $teamName.',
                          )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Historial de ventas ────────────────────────────────
          Text('Historial de ventas',
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),

          salesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Error al cargar ventas',
                  style: TextStyle(color: colorScheme.error)),
            ),
            data: (sales) {
              if (sales.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'Sin ventas registradas',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              // Resumen
              final totalRevenue =
                  sales.fold<double>(0, (sum, s) => sum + s.totalAmount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                          label: '${sales.length} ventas',
                          icon: Icons.receipt_long_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      _StatChip(
                          label: _currency.format(totalRevenue),
                          icon: Icons.attach_money_rounded),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // List
                  ...sales.map((sale) => _SaleTile(sale: sale)),
                ],
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

class _SaleTile extends StatelessWidget {
  final SaleModel sale;

  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    StatusBadge badge;
    switch (sale.status) {
      case 'cancelled':
        badge = StatusBadge.danger('Cancelada');
        break;
      case 'completed':
        badge = StatusBadge.success('Completada');
        break;
      default:
        badge = StatusBadge.warning(sale.status);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.receipt_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        title: Text(
          sale.saleNumber.isNotEmpty ? '#${sale.saleNumber}' : 'Venta',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _date.format(sale.createdAt),
          style:
              textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currency.format(sale.totalAmount),
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
