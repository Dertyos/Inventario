import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../../shared/models/inventory_movement_model.dart';
import '../../data/inventory_repository.dart';

final movementsProvider = FutureProvider.autoDispose
    .family<List<InventoryMovementModel>, String>((ref, teamId) {
  return ref.read(inventoryRepositoryProvider).getMovements(teamId);
});

final lowStockProvider =
    FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, teamId) {
  return ref.read(productsRepositoryProvider).getLowStock(teamId);
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Movimientos'),
            Tab(text: 'Stock bajo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MovementsTab(teamId: teamId),
          _LowStockTab(teamId: teamId),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMovementDialog(context, ref, teamId),
        child: const Icon(Icons.swap_vert),
      ),
    );
  }

  void _showAddMovementDialog(
      BuildContext context, WidgetRef ref, String teamId) {
    final products = ref.read(productsProvider(teamId)).value ?? [];
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos disponibles')),
      );
      return;
    }

    String? selectedProductId;
    String type = 'in';
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nuevo movimiento',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Producto'),
                items: products
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedProductId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('Entrada')),
                  ButtonSegment(value: 'out', label: Text('Salida')),
                  ButtonSegment(value: 'adjustment', label: Text('Ajuste')),
                ],
                selected: {type},
                onSelectionChanged: (v) =>
                    setSheetState(() => type = v.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Razón (opcional)'),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () async {
                  if (selectedProductId == null ||
                      quantityController.text.isEmpty) {
                    return;
                  }
                  try {
                    await ref
                        .read(inventoryRepositoryProvider)
                        .createMovement(teamId, {
                      'productId': selectedProductId,
                      'type': type,
                      'quantity': int.parse(quantityController.text),
                      if (reasonController.text.isNotEmpty)
                        'reason': reasonController.text,
                    });
                    ref.invalidate(movementsProvider(teamId));
                    ref.invalidate(productsProvider(teamId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  final String teamId;

  const _MovementsTab({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM HH:mm', 'es');

    return movements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.swap_vert_outlined,
            title: 'Sin movimientos',
            subtitle: 'Los movimientos de inventario aparecerán aquí',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(movementsProvider(teamId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final m = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: m.isPositive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      m.isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color: m.isPositive ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(m.productName ?? 'Producto'),
                  subtitle: Text(
                    '${m.typeLabel} · ${m.reason ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${m.isPositive ? '+' : '-'}${m.quantity}',
                        style: TextStyle(
                          color: m.isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        dateFormat.format(m.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LowStockTab extends ConsumerWidget {
  final String teamId;

  const _LowStockTab({required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider(teamId));

    return lowStock.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: '¡Todo bien!',
            subtitle: 'No hay productos con stock bajo',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(lowStockProvider(teamId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final p = items[index];
              final pct = p.minStock > 0 ? (p.stock / p.minStock) : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${p.stock}/${p.minStock}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          color: Colors.orange,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
