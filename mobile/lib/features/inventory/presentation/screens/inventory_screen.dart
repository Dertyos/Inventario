import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/supplier_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../suppliers/data/suppliers_repository.dart';
import '../../../../shared/models/inventory_movement_model.dart';
import '../../../../core/providers/cache_for.dart';
import '../../data/inventory_repository.dart';

final movementsProvider = FutureProvider.autoDispose
    .family<List<InventoryMovementModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(inventoryRepositoryProvider).getMovements(teamId);
});

final lowStockProvider =
    FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear código',
            onPressed: () => context.push('/scanner'),
          ),
        ],
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
          _LowStockTab(
            teamId: teamId,
            onAddStock: (product) => _showAddMovementDialog(
              context, ref, teamId,
              preselectedProduct: product,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMovementDialog(context, ref, teamId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddMovementDialog(
    BuildContext context,
    WidgetRef ref,
    String teamId, {
    ProductModel? preselectedProduct,
  }) async {
    final List<ProductModel> products;
    final List<SupplierModel> suppliers;
    try {
      products = await ref.read(productsProvider(teamId).future);
      if (!mounted) return;
      suppliers = await ref.read(suppliersProvider(teamId).future);
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
      return;
    }

    String? selectedProductId = preselectedProduct?.id;
    String type = 'in';
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    SupplierModel? selectedSupplier;

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
                preselectedProduct != null
                    ? 'Agregar stock: ${preselectedProduct.name}'
                    : 'Nuevo movimiento',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              if (preselectedProduct != null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory_2_rounded,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    title: Text(preselectedProduct.name),
                    subtitle: Text(
                      'Stock actual: ${preselectedProduct.stock} / Mín: ${preselectedProduct.minStock}',
                    ),
                  ),
                )
              else if (products.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Primero crea productos en la pestaña Productos',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: ctx,
                      builder: (innerCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Selecciona un producto',
                                style: Theme.of(innerCtx).textTheme.titleMedium,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: products.length,
                                itemBuilder: (_, i) {
                                  final p = products[i];
                                  return ListTile(
                                    leading: Icon(
                                      p.id == selectedProductId
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: p.id == selectedProductId
                                          ? Theme.of(innerCtx).colorScheme.primary
                                          : null,
                                    ),
                                    title: Text(p.name),
                                    subtitle: Text('Stock: ${p.stock}'),
                                    onTap: () {
                                      setSheetState(() => selectedProductId = p.id);
                                      Navigator.pop(innerCtx);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      selectedProductId != null
                          ? products.firstWhere((p) => p.id == selectedProductId, orElse: () => products.first).name
                          : 'Seleccionar producto',
                      style: selectedProductId == null
                          ? TextStyle(color: Theme.of(ctx).hintColor)
                          : null,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
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
              if (type == 'in') ...[
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: () {
                    if (suppliers.isEmpty) {
                      _showCreateSupplierDialog(ctx, ref, teamId, setSheetState, (s) {
                        selectedSupplier = s;
                        suppliers.add(s);
                      });
                      return;
                    }
                    showModalBottomSheet(
                      context: ctx,
                      builder: (innerCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Selecciona un proveedor',
                                style: Theme.of(innerCtx).textTheme.titleMedium,
                              ),
                            ),
                            if (selectedSupplier != null)
                              ListTile(
                                leading: const Icon(Icons.close),
                                title: const Text('Sin proveedor'),
                                onTap: () {
                                  setSheetState(() => selectedSupplier = null);
                                  Navigator.pop(innerCtx);
                                },
                              ),
                            ...suppliers.map((s) => ListTile(
                                  leading: Icon(
                                    s.id == selectedSupplier?.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: s.id == selectedSupplier?.id
                                        ? Theme.of(innerCtx).colorScheme.primary
                                        : null,
                                  ),
                                  title: Text(s.name),
                                  subtitle: s.phone != null ? Text(s.phone!) : null,
                                  onTap: () {
                                    setSheetState(() => selectedSupplier = s);
                                    Navigator.pop(innerCtx);
                                  },
                                )),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Proveedor',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      selectedSupplier?.name ?? 'Sin proveedor',
                      style: selectedSupplier == null
                          ? TextStyle(color: Theme.of(ctx).hintColor)
                          : null,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showCreateSupplierDialog(
                      ctx, ref, teamId, setSheetState, (s) {
                        selectedSupplier = s;
                        suppliers.add(s);
                      },
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(suppliers.isEmpty
                        ? 'Crear proveedor'
                        : 'Nuevo proveedor'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                autofocus: preselectedProduct != null,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Razón (opcional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(quantityController.text.trim());
                  if (selectedProductId == null ||
                      quantityController.text.isEmpty ||
                      qty == null ||
                      qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona un producto y una cantidad válida'),
                      ),
                    );
                    return;
                  }
                  try {
                    await ref
                        .read(inventoryRepositoryProvider)
                        .createMovement(teamId, {
                      'productId': selectedProductId,
                      'type': type,
                      'quantity': qty,
                      if (reasonController.text.isNotEmpty)
                        'reason': reasonController.text,
                      if (selectedSupplier != null)
                        'supplierId': selectedSupplier!.id,
                    });
                    ref.invalidate(movementsProvider(teamId));
                    ref.invalidate(productsProvider(teamId));
                    ref.invalidate(lowStockProvider(teamId));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Movimiento registrado')),
                      );
                    }
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
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateSupplierDialog(
    BuildContext ctx,
    WidgetRef ref,
    String teamId,
    StateSetter setSheetState,
    void Function(SupplierModel supplier) onCreated,
  ) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre del proveedor',
                hintText: 'Ej: Distribuidora El Éxito',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                hintText: 'Ej: 3115551234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx, {
                'name': name,
                if (phoneController.text.trim().isNotEmpty)
                  'phone': phoneController.text.trim(),
              });
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != null && ctx.mounted) {
      try {
        final supplier = await ref
            .read(suppliersRepositoryProvider)
            .createSupplier(teamId, result);
        ref.invalidate(suppliersProvider(teamId));
        setSheetState(() => onCreated(supplier));
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Proveedor "${result['name']}" creado')),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
    nameController.dispose();
    phoneController.dispose();
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
            subtitle: 'Toca + para agregar entrada o salida de productos',
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
                    [
                      m.typeLabel,
                      if (m.supplierName != null) m.supplierName!,
                      if (m.reason != null && m.reason!.isNotEmpty) m.reason!,
                    ].join(' · '),
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
  final void Function(ProductModel product) onAddStock;

  const _LowStockTab({required this.teamId, required this.onAddStock});

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
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onAddStock(p),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  if (p.barcode != null && p.barcode!.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.qr_code,
                                          size: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            p.barcode!,
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontFamily: 'monospace',
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
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
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Toca para agregar stock',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
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
