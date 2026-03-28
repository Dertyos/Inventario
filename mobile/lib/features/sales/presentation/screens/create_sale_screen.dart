import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../data/sales_repository.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'sales_screen.dart';

class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final List<_CartItem> _cart = [];
  bool _isCredit = false;
  bool _isSaving = false;
  CustomerModel? _selectedCustomer;
  final _cashAmountController = TextEditingController();
  final _cardAmountController = TextEditingController();
  final _transferAmountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  final _paidAmountController = TextEditingController();
  final _interestController = TextEditingController();
  String _creditFrequency = 'monthly';
  late DateTime _creditNextPayment = DateTime.now().add(const Duration(days: 30));

  double get _total =>
      _cart.fold(0, (sum, item) => sum + item.subtotal);

  String get _resolvedPaymentMethod {
    if (_isCredit) return 'credit';
    final cash = double.tryParse(_cashAmountController.text) ?? 0;
    final card = double.tryParse(_cardAmountController.text) ?? 0;
    final transfer = double.tryParse(_transferAmountController.text) ?? 0;
    final active = [
      if (cash > 0) 'cash',
      if (card > 0) 'card',
      if (transfer > 0) 'transfer',
    ];
    if (active.length > 1) return 'mixed';
    return active.isEmpty ? 'cash' : active.first;
  }

  double get _enteredAmount {
    if (_isCredit) return _total;
    final cash = double.tryParse(_cashAmountController.text) ?? 0;
    final card = double.tryParse(_cardAmountController.text) ?? 0;
    final transfer = double.tryParse(_transferAmountController.text) ?? 0;
    return cash + card + transfer;
  }

  DateTime _nextPaymentFor(String frequency) {
    final now = DateTime.now();
    switch (frequency) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'daily':
        return now.add(const Duration(days: 1));
      default:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  void _addToCart(ProductModel product) {
    final existing = _cart.indexWhere((c) => c.product.id == product.id);
    if (existing >= 0) {
      setState(() => _cart[existing].quantity++);
    } else {
      setState(() => _cart.add(_CartItem(product: product)));
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

  void _editPrice(int index) {
    final item = _cart[index];
    final unitPriceController =
        TextEditingController(text: item.unitPrice.toStringAsFixed(0));
    final totalController =
        TextEditingController(text: item.subtotal.toStringAsFixed(0));
    bool updatingFromUnit = false;
    bool updatingFromTotal = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(item.product.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Precio original: ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(item.product.price)}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario',
                      prefixIcon: Icon(Icons.attach_money),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      if (updatingFromTotal) return;
                      updatingFromUnit = true;
                      final unit = double.tryParse(v) ?? 0;
                      totalController.text =
                          (unit * item.quantity).toStringAsFixed(0);
                      updatingFromUnit = false;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: totalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total (${item.quantity} uds)',
                      prefixIcon: const Icon(Icons.functions),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      if (updatingFromUnit) return;
                      updatingFromTotal = true;
                      final total = double.tryParse(v) ?? 0;
                      unitPriceController.text =
                          (total / item.quantity).toStringAsFixed(0);
                      updatingFromTotal = false;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => item.overrideUnitPrice = null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Restaurar'),
                ),
                FilledButton(
                  onPressed: () {
                    final newUnit =
                        double.tryParse(unitPriceController.text) ?? item.product.price;
                    setState(() {
                      item.overrideUnitPrice =
                          newUnit == item.product.price ? null : newUnit;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomerPicker(
      BuildContext context, WidgetRef ref, String teamId) {
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
                final customersAsync = ref.watch(customersProvider(teamId));
                final salesAsync = ref.watch(salesProvider(teamId));
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Selecciona un cliente',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const Text('Venta directa (sin cliente)'),
                      onTap: () {
                        setState(() => _selectedCustomer = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: customersAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Error: $e')),
                        data: (customers) {
                          if (customers.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                    'No hay clientes. Crea uno en la pestaña Más > Clientes.'),
                              ),
                            );
                          }

                          // Recent customer IDs from existing sales
                          final recentIds = salesAsync.when(
                            data: (sales) {
                              final seen = <String>{};
                              return sales
                                  .where((s) => s.customerId != null)
                                  .map((s) => s.customerId!)
                                  .where((id) => seen.add(id))
                                  .take(5)
                                  .toList();
                            },
                            loading: () => <String>[],
                            error: (_, __) => <String>[],
                          );

                          final recentCustomers = recentIds
                              .map((id) => customers.firstWhere(
                                    (c) => c.id == id,
                                    orElse: () => customers.first,
                                  ))
                              .where((c) => recentIds.contains(c.id))
                              .toList();

                          final recentSet = recentIds.toSet();
                          final otherCustomers = customers
                              .where((c) => !recentSet.contains(c.id))
                              .toList()
                            ..sort((a, b) => a.name
                                .toLowerCase()
                                .compareTo(b.name.toLowerCase()));

                          ListTile customerTile(CustomerModel c) {
                            final selected = _selectedCustomer?.id == c.id;
                            return ListTile(
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? Theme.of(ctx).colorScheme.primary
                                    : null,
                              ),
                              title: Text(c.name),
                              subtitle: c.phone != null
                                  ? Text(c.phone!)
                                  : null,
                              onTap: () {
                                setState(() => _selectedCustomer = c);
                                Navigator.pop(ctx);
                              },
                            );
                          }

                          Widget sectionHeader(String label) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md, AppSpacing.sm,
                                    AppSpacing.md, 2),
                                child: Text(
                                  label,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              );

                          return ListView(
                            controller: scrollController,
                            children: [
                              if (recentCustomers.isNotEmpty) ...[
                                sectionHeader('ÚLTIMOS USADOS'),
                                ...recentCustomers.map(customerTile),
                                sectionHeader('TODOS'),
                              ],
                              ...otherCustomers.map(customerTile),
                            ],
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

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    // Validate payment amounts for non-credit sales
    if (!_isCredit && _enteredAmount > 0 && _enteredAmount < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El monto ingresado (\$${_enteredAmount.toStringAsFixed(0)}) es menor al total (\$${_total.toStringAsFixed(0)})',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar venta'),
        content: Text(
          '¿Registrar venta por ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(_total)}?',
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
      final sale = await ref.read(salesRepositoryProvider).createSale(teamId, {
        'items': _cart
            .map((c) => {
                  'productId': c.product.id,
                  'quantity': c.quantity,
                  'unitPrice': c.unitPrice,
                })
            .toList(),
        'paymentMethod': _resolvedPaymentMethod,
        if (_resolvedPaymentMethod == 'mixed') ...{
          'cashAmount': double.tryParse(_cashAmountController.text) ?? 0,
          'cardAmount': double.tryParse(_cardAmountController.text) ?? 0,
          'transferAmount': double.tryParse(_transferAmountController.text) ?? 0,
        },
        if (_selectedCustomer != null) 'customerId': _selectedCustomer!.id,
        if (_isCredit) ...{
          'creditInstallments':
              int.tryParse(_installmentsController.text) ?? 1,
          if (_paidAmountController.text.isNotEmpty)
            'creditPaidAmount':
                double.tryParse(_paidAmountController.text) ?? 0,
          if (_interestController.text.isNotEmpty)
            'creditInterestRate':
                double.tryParse(_interestController.text) ?? 0,
          'creditFrequency': _creditFrequency,
          'creditNextPayment':
              _creditNextPayment.toIso8601String().split('T').first,
        },
      });

      ref.invalidate(salesProvider(teamId));
      ref.invalidate(productsProvider(teamId));
      ref.invalidate(dashboardProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta registrada')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        final isOffline = message.contains('guardada localmente');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOffline ? message : 'Error: $message'),
            backgroundColor: isOffline ? Colors.orange : null,
          ),
        );
        if (isOffline) {
          context.pop();
          return;
        }
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _transferAmountController.dispose();
    _installmentsController.dispose();
    _paidAmountController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final products = ref.watch(productsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
      ),
      body: Column(
        children: [
          // Customer selector
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () => _showCustomerPicker(context, ref, teamId),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Cliente (opcional)',
                  prefixIcon: const Icon(Icons.person_outline),
                  suffixIcon: _selectedCustomer != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _selectedCustomer = null),
                        )
                      : const Icon(Icons.arrow_drop_down),
                  isDense: true,
                ),
                child: Text(
                  _selectedCustomer?.name ?? 'Venta directa',
                  style: _selectedCustomer == null
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                final available = items.where((p) => p.stock > 0).toList();
                if (available.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            items.isEmpty
                                ? 'No hay productos registrados'
                                : 'Todos los productos tienen stock en 0',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            items.isEmpty
                                ? 'Crea productos en la pestaña Productos'
                                : 'Agrega stock desde la pestaña Inventario',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final product = available[index];
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
                      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${cop.format(product.price)} · Stock: ${product.stock}'),
                      trailing: IconButton(
                        icon: Icon(
                          inCart ? Icons.check_circle : Icons.add_circle_outline,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                          'Toca un producto de arriba para agregarlo',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        final canOverridePrice = ref.watch(authProvider).hasPermission('sales.override_price');
                        final hasOverride = item.overrideUnitPrice != null;
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
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => _updateQuantity(index, -1),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                '${item.quantity}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: item.quantity < item.product.stock
                                    ? () => _updateQuantity(index, 1)
                                    : null,
                                visualDensity: VisualDensity.compact,
                              ),
                              GestureDetector(
                                onTap: canOverridePrice ? () => _editPrice(index) : null,
                                child: SizedBox(
                                  width: 80,
                                  child: Text(
                                    cop.format(item.subtotal),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: hasOverride ? colorScheme.primary : null,
                                      decoration: canOverridePrice ? TextDecoration.underline : null,
                                      decorationColor: hasOverride ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                      decorationStyle: TextDecorationStyle.dotted,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 16, color: colorScheme.error),
                                onPressed: () => _removeFromCart(index),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Modo de pago: Contado | Crédito
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.payments_outlined),
                          label: Text('Paga hoy'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.calendar_month_outlined),
                          label: Text('Paga después'),
                        ),
                      ],
                      selected: {_isCredit},
                      onSelectionChanged: (v) => setState(() {
                        _isCredit = v.first;
                        if (!_isCredit) {
                          _cashAmountController.clear();
                          _cardAmountController.clear();
                          _transferAmountController.clear();
                        }
                      }),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  // Campos de monto contado (efectivo + tarjeta + transferencia)
                  if (!_isCredit) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cashAmountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Efectivo',
                                prefixIcon: Icon(Icons.payments_outlined),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _cardAmountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tarjeta',
                                prefixIcon: Icon(Icons.credit_card_outlined),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _transferAmountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Transfer',
                                prefixIcon: Icon(Icons.swap_horiz_outlined),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_enteredAmount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 4, AppSpacing.md, 0,
                        ),
                        child: Builder(builder: (context) {
                          final diff = _enteredAmount - _total;
                          final cop = NumberFormat.currency(
                            locale: 'es_CO', symbol: '\$', decimalDigits: 0,
                          );
                          return Text(
                            diff == 0
                                ? 'Cuadra exacto'
                                : diff > 0
                                    ? 'Vuelto: ${cop.format(diff)}'
                                    : 'Faltan: ${cop.format(-diff)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: diff == 0
                                  ? Colors.green
                                  : diff > 0
                                      ? colorScheme.primary
                                      : colorScheme.error,
                            ),
                          );
                        }),
                      ),
                  ],
                  if (_isCredit) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _installmentsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cuotas',
                                prefixIcon: Icon(Icons.calendar_month_outlined),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _interestController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Interés %',
                                hintText: 'Sin interés',
                                prefixIcon: Icon(Icons.percent),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'monthly', label: Text('Mensual')),
                                ButtonSegment(value: 'weekly', label: Text('Semanal')),
                                ButtonSegment(value: 'daily', label: Text('Diaria')),
                              ],
                              selected: {_creditFrequency},
                              onSelectionChanged: (v) {
                                final freq = v.first;
                                setState(() {
                                  _creditFrequency = freq;
                                  _creditNextPayment = _nextPaymentFor(freq);
                                });
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                textStyle: WidgetStatePropertyAll(
                                  Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _creditNextPayment,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                  locale: const Locale('es'),
                                );
                                if (picked != null) {
                                  setState(() => _creditNextPayment = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Próxima cuota',
                                  prefixIcon: Icon(Icons.event_outlined),
                                  suffixIcon: Icon(Icons.edit_calendar),
                                  isDense: true,
                                ),
                                child: Text(
                                  DateFormat('dd MMM yyyy', 'es').format(_creditNextPayment),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _paidAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Abono inicial',
                                hintText: 'Sin abono',
                                prefixIcon: const Icon(Icons.payments_outlined),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              cop.format(_total),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Cobrar'),
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
  int quantity;
  double? overrideUnitPrice;

  _CartItem({required this.product, int quantity = 1, this.overrideUnitPrice})
      : quantity = quantity;

  double get unitPrice => overrideUnitPrice ?? product.price;
  double get subtotal => unitPrice * quantity;
}
