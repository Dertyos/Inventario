import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../data/lots_repository.dart';

class CreateLotScreen extends ConsumerStatefulWidget {
  const CreateLotScreen({super.key});

  @override
  ConsumerState<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends ConsumerState<CreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lotNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy', 'es');

  ProductModel? _selectedProduct;
  DateTime? _expirationDate;
  DateTime? _manufacturingDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _lotNumberController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final productsAsync = ref.watch(productsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo lote'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Product selector
            Text(
              'Producto *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error cargando productos: $e'),
              data: (products) {
                return DropdownButtonFormField<ProductModel>(
                  value: _selectedProduct,
                  decoration: const InputDecoration(
                    hintText: 'Seleccionar producto',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  isExpanded: true,
                  items: products.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedProduct = v),
                  validator: (v) =>
                      v == null ? 'Selecciona un producto' : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Lot number
            Text(
              'Número de lote *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _lotNumberController,
              decoration: const InputDecoration(
                hintText: 'Ej: LOTE-2026-03-001',
                prefixIcon: Icon(Icons.tag),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Ingresa el número de lote'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Quantity
            Text(
              'Cantidad *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                hintText: 'Cantidad de unidades',
                prefixIcon: Icon(Icons.straighten),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ingresa la cantidad';
                }
                final n = int.tryParse(v);
                if (n == null || n < 1) {
                  return 'La cantidad debe ser al menos 1';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Expiration date
            Text(
              'Fecha de vencimiento',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerField(
              value: _expirationDate,
              hint: 'Seleccionar fecha de vencimiento',
              dateFormat: _dateFormat,
              onTap: () => _pickDate(
                initial: _expirationDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                onPicked: (d) => setState(() => _expirationDate = d),
              ),
              onClear: () => setState(() => _expirationDate = null),
            ),
            const SizedBox(height: AppSpacing.md),

            // Manufacturing date
            Text(
              'Fecha de fabricación',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerField(
              value: _manufacturingDate,
              hint: 'Seleccionar fecha de fabricación',
              dateFormat: _dateFormat,
              onTap: () => _pickDate(
                initial: _manufacturingDate,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now(),
                onPicked: (d) => setState(() => _manufacturingDate = d),
              ),
              onClear: () => setState(() => _manufacturingDate = null),
            ),
            const SizedBox(height: AppSpacing.md),

            // Notes
            Text(
              'Notas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Notas opcionales sobre el lote',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submit(teamId),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSubmitting ? 'Guardando...' : 'Crear lote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({
    DateTime? initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es'),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _submit(String teamId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final data = <String, dynamic>{
      'productId': _selectedProduct!.id,
      'lotNumber': _lotNumberController.text.trim(),
      'quantity': int.parse(_quantityController.text.trim()),
    };

    if (_expirationDate != null) {
      data['expirationDate'] =
          _expirationDate!.toIso8601String().split('T')[0];
    }
    if (_manufacturingDate != null) {
      data['manufacturingDate'] =
          _manufacturingDate!.toIso8601String().split('T')[0];
    }
    if (_notesController.text.trim().isNotEmpty) {
      data['notes'] = _notesController.text.trim();
    }

    try {
      await ref.read(lotsRepositoryProvider).createLot(teamId, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote creado exitosamente')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.value,
    required this.hint,
    required this.dateFormat,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          value != null ? dateFormat.format(value!) : hint,
          style: value != null
              ? Theme.of(context).textTheme.bodyMedium
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
        ),
      ),
    );
  }
}
