import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/products_repository.dart';
import 'products_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final teamId = ref.read(authProvider).teamId;
      final product = await ref
          .read(productsRepositoryProvider)
          .getProduct(teamId, widget.productId!);
      _nameController.text = product.name;
      _skuController.text = product.sku;
      _barcodeController.text = product.barcode ?? '';
      _descriptionController.text = product.description ?? '';
      _priceController.text = product.price.toStringAsFixed(0);
      _costController.text = product.cost?.toStringAsFixed(0) ?? '';
      _minStockController.text = product.minStock.toString();
      _selectedCategoryId = product.categoryId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final teamId = ref.read(authProvider).teamId;
    final data = {
      'name': _nameController.text.trim(),
      if (_skuController.text.trim().isNotEmpty)
        'sku': _skuController.text.trim(),
      if (_barcodeController.text.isNotEmpty)
        'barcode': _barcodeController.text.trim(),
      if (_descriptionController.text.isNotEmpty)
        'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text),
      if (_costController.text.isNotEmpty)
        'cost': double.parse(_costController.text),
      'minStock': int.parse(_minStockController.text),
      if (_selectedCategoryId != null)
        'categoryId': _selectedCategoryId,
    };

    try {
      if (isEditing) {
        await ref
            .read(productsRepositoryProvider)
            .updateProduct(teamId, widget.productId!, data);
      } else {
        await ref
            .read(productsRepositoryProvider)
            .createProduct(teamId, data);
      }
      ref.invalidate(productsProvider(teamId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Producto actualizado' : 'Producto creado'),
          ),
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text(
          'Esta acción no se puede deshacer. Se eliminará el producto y su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final teamId = ref.read(authProvider).teamId;
      try {
        await ref
            .read(productsRepositoryProvider)
            .deleteProduct(teamId, widget.productId!);
        ref.invalidate(productsProvider(teamId));
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showCategoryPicker(List<CategoryModel> cats) {
    if (cats.isEmpty) {
      _showCreateCategoryDialog();
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Selecciona una categoría',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_selectedCategoryId != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Sin categoría'),
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  Navigator.pop(ctx);
                },
              ),
            ...cats.map((c) => ListTile(
                  leading: Icon(
                    c.id == _selectedCategoryId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: c.id == _selectedCategoryId
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(c.name),
                  onTap: () {
                    setState(() => _selectedCategoryId = c.id);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Bebidas, Snacks, Lácteos...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final teamId = ref.read(authProvider).teamId;
        final category = await ref
            .read(productsRepositoryProvider)
            .createCategory(teamId, {'name': result});
        ref.invalidate(categoriesProvider(teamId));
        setState(() => _selectedCategoryId = category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoría "$result" creada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
    nameController.dispose();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final categories = ref.watch(categoriesProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      prefixIcon: Icon(Icons.tag),
                      helperText: 'Opcional, se genera automáticamente',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código de barras',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            categories.whenOrNull(
                  data: (cats) {
                    final selectedName = cats
                        .where((c) => c.id == _selectedCategoryId)
                        .map((c) => c.name)
                        .firstOrNull;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () => _showCategoryPicker(cats),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                              prefixIcon: Icon(Icons.category_outlined),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              selectedName ?? 'Sin categoría',
                              style: selectedName != null
                                  ? null
                                  : TextStyle(color: Theme.of(context).hintColor),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showCreateCategoryDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(cats.isEmpty ? 'Crear categoría' : 'Nueva categoría'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ) ??
                const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Precio y costos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      prefixText: '\$ ',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (double.tryParse(v) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _minStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock mínimo',
                prefixIcon: Icon(Icons.inventory_outlined),
                helperText: 'Te alertamos cuando el stock baje de este número',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Guardar cambios' : 'Crear producto'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
