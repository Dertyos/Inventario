import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/supplier_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_modal.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/suppliers_repository.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final nitController = TextEditingController();
    final contactController = TextEditingController();

    showAppModal(
      context: context,
      title: 'Nuevo proveedor',
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: nitController,
          decoration: const InputDecoration(
            labelText: 'NIT',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: contactController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de contacto',
            prefixIcon: Icon(Icons.person_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;
            final teamId = ref.read(authProvider).teamId;
            final ctx = context;
            try {
              await ref
                  .read(suppliersRepositoryProvider)
                  .createSupplier(teamId, {
                'name': nameController.text.trim(),
                if (nitController.text.isNotEmpty)
                  'nit': nitController.text.trim(),
                if (contactController.text.isNotEmpty)
                  'contactName': contactController.text.trim(),
                if (phoneController.text.isNotEmpty)
                  'phone': phoneController.text.trim(),
              });
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

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final suppliers = ref.watch(suppliersProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      body: Column(
        children: [
          AppSearchField(
            hintText: 'Buscar proveedores...',
            value: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          Expanded(
            child: suppliers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                var filtered = items;
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((s) =>
                          s.name.toLowerCase().contains(q) ||
                          (s.nit?.toLowerCase().contains(q) ?? false) ||
                          (s.phone?.contains(q) ?? false))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: items.isEmpty ? 'Sin proveedores' : 'Sin resultados',
                    subtitle: items.isEmpty
                        ? 'Agrega tu primer proveedor'
                        : null,
                    actionLabel: items.isEmpty ? 'Agregar proveedor' : null,
                    onAction: items.isEmpty ? _showAddSupplierDialog : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(suppliersProvider(teamId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final supplier = filtered[index];
                      return AppListTile.initial(
                        initial: supplier.name[0],
                        title: supplier.name,
                        subtitle: [
                          supplier.nit,
                          supplier.contactName,
                          supplier.phone,
                          supplier.email,
                        ]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
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
        onPressed: _showAddSupplierDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
