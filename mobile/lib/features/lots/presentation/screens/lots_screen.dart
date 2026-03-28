import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_lot_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/lots_repository.dart';

enum _LotFilter { todos, porVencer, expirados }

class LotsScreen extends ConsumerStatefulWidget {
  const LotsScreen({super.key});

  @override
  ConsumerState<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends ConsumerState<LotsScreen> {
  _LotFilter _filter = _LotFilter.todos;
  final _dateFormat = DateFormat('dd MMM yyyy', 'es');

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final lotsAsync = ref.watch(lotsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'mark_expired') {
                await _markExpired(teamId);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'mark_expired',
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Marcar expirados'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _filter == _LotFilter.todos,
                  onSelected: () =>
                      setState(() => _filter = _LotFilter.todos),
                ),
                _FilterChip(
                  label: 'Por vencer',
                  selected: _filter == _LotFilter.porVencer,
                  onSelected: () =>
                      setState(() => _filter = _LotFilter.porVencer),
                ),
                _FilterChip(
                  label: 'Expirados',
                  selected: _filter == _LotFilter.expirados,
                  onSelected: () =>
                      setState(() => _filter = _LotFilter.expirados),
                ),
              ],
            ),
          ),

          // Lots list
          Expanded(
            child: lotsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e'),
              ),
              data: (lots) {
                final filtered = _applyFilter(lots);

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: lots.isEmpty
                        ? 'Sin lotes'
                        : 'Sin resultados',
                    subtitle: lots.isEmpty
                        ? 'Crea tu primer lote de producto'
                        : 'No hay lotes con este filtro',
                    actionLabel: lots.isEmpty ? 'Nuevo lote' : null,
                    onAction: lots.isEmpty
                        ? () => context.push('/lots/new')
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(lotsProvider(teamId));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final lot = filtered[index];
                      return _LotCard(
                        lot: lot,
                        dateFormat: _dateFormat,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>('/lots/new');
          if (created == true) {
            ref.invalidate(lotsProvider(teamId));
          }
        },
        tooltip: 'Nuevo lote',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<ProductLotModel> _applyFilter(List<ProductLotModel> lots) {
    switch (_filter) {
      case _LotFilter.todos:
        return lots;
      case _LotFilter.porVencer:
        return lots
            .where((l) => l.status == 'active' && l.isExpiringSoon(30))
            .toList();
      case _LotFilter.expirados:
        return lots.where((l) => l.isExpired).toList();
    }
  }

  Future<void> _markExpired(String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('\u00bfMarcar lotes expirados?'),
        content: const Text(
          'Esta acci\u00f3n marcar\u00e1 todos los lotes vencidos como expirados. '
          'Los lotes expirados no se pueden usar en ventas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar expirados'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count =
          await ref.read(lotsRepositoryProvider).markExpired(teamId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '$count lote(s) marcado(s) como expirado(s)'
              : 'No hay lotes por expirar'),
        ),
      );
      ref.invalidate(lotsProvider(teamId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _LotCard extends StatelessWidget {
  final ProductLotModel lot;
  final DateFormat dateFormat;
  final ColorScheme colorScheme;

  const _LotCard({
    required this.lot,
    required this.dateFormat,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = lot.statusLabel;
    final statusColor = _colorForStatus(statusLabel);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: lot number + status badge
            Row(
              children: [
                Container(
                  width: AppDimensions.avatarMd,
                  height: AppDimensions.avatarMd,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.inventory_2,
                      size: AppDimensions.iconSizeMd,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lot.lotNumber,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lot.productName != null)
                        Text(
                          lot.productName!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // Details row
            Row(
              children: [
                _DetailItem(
                  icon: Icons.straighten,
                  label: 'Disponible',
                  value: '${lot.availableQuantity} / ${lot.quantity}',
                ),
                const Spacer(),
                if (lot.expirationDate != null)
                  _DetailItem(
                    icon: Icons.event,
                    label: 'Vencimiento',
                    value: dateFormat.format(lot.expirationDate!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForStatus(String label) {
    switch (label) {
      case 'Activo':
        return AppColors.success;
      case 'Por vencer':
        return AppColors.warning;
      case 'Expirado':
        return AppColors.danger;
      case 'Agotado':
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: AppDimensions.iconSizeSm,
            color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
      ),
    );
  }
}
