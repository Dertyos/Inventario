import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/sale_model.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../data/sales_repository.dart';
import 'sales_screen.dart';

final saleDetailProvider =
    FutureProvider.autoDispose.family<SaleModel, ({String teamId, String saleId})>(
        (ref, params) {
  return ref
      .read(salesRepositoryProvider)
      .getSales(params.teamId)
      .then((sales) => sales.firstWhere((s) => s.id == params.saleId));
});

class EditSaleScreen extends ConsumerStatefulWidget {
  final String saleId;

  const EditSaleScreen({super.key, required this.saleId});

  @override
  ConsumerState<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends ConsumerState<EditSaleScreen> {
  final _notesController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _interestController = TextEditingController();
  String? _creditFrequency;
  DateTime? _creditNextPayment;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _isSaving = false;
  bool _initialized = false;

  void _initFromSale(SaleModel sale) {
    if (_initialized) return;
    _initialized = true;
    _notesController.text = sale.notes ?? '';
    _selectedCustomerId = sale.customerId;
    _selectedCustomerName = sale.customerName;
    if (sale.isCredit) {
      _installmentsController.text =
          sale.creditInstallments?.toString() ?? '1';
      _paidAmountController.text =
          sale.creditPaidAmount?.toStringAsFixed(0) ?? '';
      _interestController.text =
          sale.creditInterestRate?.toStringAsFixed(1) ?? '';
      _creditFrequency = sale.creditFrequency ?? 'monthly';
      _creditNextPayment = sale.creditNextPayment;
    }
  }

  void _showCustomerPicker(BuildContext context, String teamId) {
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
                        setState(() {
                          _selectedCustomerId = null;
                          _selectedCustomerName = null;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: customersAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (customers) {
                          if (customers.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Text('No hay clientes registrados.'),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: customers.length,
                            itemBuilder: (_, i) {
                              final c = customers[i];
                              final selected = _selectedCustomerId == c.id;
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
                                subtitle:
                                    c.phone != null ? Text(c.phone!) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCustomerId = c.id;
                                    _selectedCustomerName = c.name;
                                  });
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

  Future<void> _save(SaleModel original) async {
    setState(() => _isSaving = true);
    final teamId = ref.read(authProvider).teamId;

    final data = <String, dynamic>{};

    if (_notesController.text != (original.notes ?? '')) {
      data['notes'] = _notesController.text;
    }
    if (_selectedCustomerId != original.customerId) {
      data['customerId'] = _selectedCustomerId;
    }
    if (original.isCredit) {
      final installments = int.tryParse(_installmentsController.text);
      if (installments != null && installments != original.creditInstallments) {
        data['creditInstallments'] = installments;
      }
      final paid = double.tryParse(_paidAmountController.text);
      if (paid != null && paid != original.creditPaidAmount) {
        data['creditPaidAmount'] = paid;
      }
      final interest = double.tryParse(_interestController.text);
      if (interest != null && interest != original.creditInterestRate) {
        data['creditInterestRate'] = interest;
      }
      if (_creditFrequency != null &&
          _creditFrequency != original.creditFrequency) {
        data['creditFrequency'] = _creditFrequency;
      }
      if (_creditNextPayment != null &&
          _creditNextPayment != original.creditNextPayment) {
        data['creditNextPayment'] =
            _creditNextPayment!.toIso8601String().split('T').first;
      }
    }

    if (data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin cambios')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      await ref
          .read(salesRepositoryProvider)
          .updateSale(teamId, widget.saleId, data);
      ref.invalidate(salesProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta actualizada')),
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
    _installmentsController.dispose();
    _paidAmountController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final saleAsync = ref.watch(
      saleDetailProvider((teamId: teamId, saleId: widget.saleId)),
    );
    final cop =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar venta')),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sale) {
          _initFromSale(sale);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sale header info (read-only)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text('${sale.saleNumber} - ${cop.format(sale.totalAmount)}'),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy HH:mm', 'es')
                          .format(sale.createdAt),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Items (read-only)
                Text(
                  'Productos (no editables)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${item.quantity} x ${cop.format(item.unitPrice)} = ${cop.format(item.subtotal)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Editable: Customer
                GestureDetector(
                  onTap: () => _showCustomerPicker(context, teamId),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Cliente',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: _selectedCustomerId != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                _selectedCustomerId = null;
                                _selectedCustomerName = null;
                              }),
                            )
                          : const Icon(Icons.arrow_drop_down),
                      isDense: true,
                    ),
                    child: Text(
                      _selectedCustomerName ?? 'Venta directa',
                      style: _selectedCustomerId == null
                          ? TextStyle(color: Theme.of(context).hintColor)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Editable: Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    prefixIcon: Icon(Icons.notes_outlined),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),

                // Credit-specific fields
                if (sale.isCredit) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Datos de credito',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
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
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Interes %',
                            prefixIcon: Icon(Icons.percent),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _creditNextPayment ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 2)),
                              locale: const Locale('es'),
                            );
                            if (picked != null) {
                              setState(() => _creditNextPayment = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Proxima cuota',
                              prefixIcon: Icon(Icons.event_outlined),
                              suffixIcon: Icon(Icons.edit_calendar),
                              isDense: true,
                            ),
                            child: Text(
                              _creditNextPayment != null
                                  ? DateFormat('dd MMM yyyy', 'es')
                                      .format(_creditNextPayment!)
                                  : 'Sin fecha',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _paidAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Monto pagado',
                            prefixIcon: Icon(Icons.payments_outlined),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'monthly', label: Text('Mensual')),
                      ButtonSegment(value: 'weekly', label: Text('Semanal')),
                      ButtonSegment(value: 'daily', label: Text('Diaria')),
                    ],
                    selected: {_creditFrequency ?? 'monthly'},
                    onSelectionChanged: (v) =>
                        setState(() => _creditFrequency = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(
                        Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : () => _save(sale),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
