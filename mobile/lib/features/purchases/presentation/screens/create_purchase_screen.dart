import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/supplier_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../suppliers/data/suppliers_repository.dart';
import '../../data/purchases_repository.dart';

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() =>
      _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final List<_CartItem> _cart = [];
  final _notesController = TextEditingController();
  SupplierModel? _selectedSupplier;
  bool _isSaving = false;

  double get _total =>
      _cart.fold(0, (sum, item) => sum + (item.unitCost * item.quantity));

  void _addToCart(ProductModel product) {
    final existing = _cart.indexWhere((c) => c.product.id == product.id);
    if (existing >= 0) {
      setState(() => _cart[existing].quantity++);
    } else {
      setState(() => _cart.add(_CartItem(
            product: product,
            unitCost: product.cost ?? 0,
          )));
    }
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) _cart.removeAt(index);
    });
  }

  void _editUnitCost(int index) {
    final controller =
        TextEditingController(text: _cart[index].unitCost.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Costo unitario'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            labelText: 'Costo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                setState(() => _cart[index].unitCost = value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showSupplierPicker(String teamId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (ctx, scrollController) {
            return Consumer(
              builder: (ctx, ref, _) {
                final suppliersAsync = ref.watch(suppliersProvider(teamId));
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Selecciona un proveedor',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Crear nuevo proveedor'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreateSupplierDialog(teamId);
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: suppliersAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Error: $e')),
                        data: (suppliers) {
                          if (suppliers.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                    'No hay proveedores. Crea uno nuevo.'),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: suppliers.length,
                            itemBuilder: (_, i) {
                              final s = suppliers[i];
                              final selected =
                                  _selectedSupplier?.id == s.id;
                              return ListTile(
                                leading: Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? Theme.of(ctx).colorScheme.primary
                                      : null,
                                ),
                                title: Text(s.name),
                                subtitle: s.phone != null
                                    ? Text(s.phone!)
                                    : null,
                                onTap: () {
                                  setState(
                                      () => _selectedSupplier = s);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateSupplierDialog(String teamId) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Tel\u00e9fono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final supplier = await ref
                    .read(suppliersRepositoryProvider)
                    .createSupplier(teamId, {
                  'name': name,
                  if (phoneController.text.trim().isNotEmpty)
                    'phone': phoneController.text.trim(),
                });
                ref.invalidate(suppliersProvider(teamId));
                if (mounted) {
                  setState(() => _selectedSupplier = supplier);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un proveedor')),
      );
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text(
          '\u00bfRegistrar orden de compra por ${cop.format(_total)} '
          'a ${_selectedSupplier!.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    final teamId = ref.read(authProvider).teamId;

    try {
      await ref.read(purchasesRepositoryProvider).createPurchase(teamId, {
        'supplierId': _selectedSupplier!.id,
        'items': _cart
            .map((c) => {
                  'productId': c.product.id,
                  'quantity': c.quantity,
                  'unitCost': c.unitCost,
                })
            .toList(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });
      ref.invalidate(purchasesProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden de compra creada')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final products = ref.watch(productsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva compra'),
      ),
      body: Column(
        children: [
          // Supplier selector
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () => _showSupplierPicker(teamId),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Proveedor',
                  prefixIcon: const Icon(Icons.business_outlined),
                  suffixIcon: _selectedSupplier != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _selectedSupplier = null),
                        )
                      : const Icon(Icons.arrow_drop_down),
                  isDense: true,
                ),
                child: Text(
                  _selectedSupplier?.name ?? 'Seleccionar proveedor',
                  style: _selectedSupplier == null
                      ? TextStyle(color: Theme.of(context).hintColor)
                      : null,
                ),
              ),
            ),
          ),

          // Product picker
          Expanded(
            flex: 1,
            child: products.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No hay productos registrados',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Crea productos en la pesta\u00f1a Productos',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final product = items[index];
                    final inCart =
                        _cart.any((c) => c.product.id == product.id);
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: inCart
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            product.name[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: inCart
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      title: Text(product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'Costo: ${product.cost != null ? cop.format(product.cost) : 'N/A'} \u00b7 Stock: ${product.stock}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          inCart
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: inCart ? colorScheme.primary : null,
                        ),
                        onPressed: () => _addToCart(product),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Cart section
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (_cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Toca un producto para agregarlo',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm),
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20),
                                onPressed: () =>
                                    _updateQuantity(index, -1),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                '${item.quantity}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall,
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20),
                                onPressed: () =>
                                    _updateQuantity(index, 1),
                                visualDensity: VisualDensity.compact,
                              ),
                              GestureDetector(
                                onTap: () => _editUnitCost(index),
                                child: SizedBox(
                                  width: 80,
                                  child: Text(
                                    cop.format(
                                        item.unitCost * item.quantity),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          decoration:
                                              TextDecoration.underline,
                                          decorationStyle:
                                              TextDecorationStyle.dotted,
                                        ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 16,
                                    color: colorScheme.error),
                                onPressed: () =>
                                    _removeFromCart(index),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Notes field
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    child: TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Notas (opcional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              cop.format(_total),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Crear orden'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(140, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItem {
  final ProductModel product;
  int quantity = 1;
  double unitCost;

  _CartItem({
    required this.product,
    required this.unitCost,
  });
}
