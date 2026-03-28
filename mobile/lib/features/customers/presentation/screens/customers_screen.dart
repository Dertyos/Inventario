import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_modal.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wa_icon_button.dart';
import '../../../../core/providers/cache_for.dart';
import '../../data/customers_repository.dart';

final customersProvider = FutureProvider.autoDispose
    .family<List<CustomerModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(customersRepositoryProvider).getCustomers(teamId);
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showAppModal(
      context: context,
      title: 'Nuevo cliente',
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
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
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
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
                  .read(customersRepositoryProvider)
                  .createCustomer(teamId, {
                'name': nameController.text.trim(),
                if (phoneController.text.isNotEmpty)
                  'phone': phoneController.text.trim(),
                if (emailController.text.isNotEmpty)
                  'email': emailController.text.trim(),
              });
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

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final customers = ref.watch(customersProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          AppSearchField(
            hintText: 'Buscar clientes...',
            value: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                var filtered = items;
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((c) =>
                          c.name.toLowerCase().contains(q) ||
                          (c.phone?.contains(q) ?? false) ||
                          (c.email?.toLowerCase().contains(q) ?? false))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outlined,
                    title: items.isEmpty ? 'Sin clientes' : 'Sin resultados',
                    subtitle: items.isEmpty
                        ? 'Agrega tu primer cliente'
                        : null,
                    actionLabel: items.isEmpty ? 'Agregar cliente' : null,
                    onAction: items.isEmpty ? _showAddCustomerDialog : null,
                  );
                }

                // Orden A-Z
                filtered.sort((a, b) => a.name
                    .toLowerCase()
                    .compareTo(b.name.toLowerCase()));

                final teamName =
                    ref.read(authProvider).activeTeam?.name ?? '';

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(customersProvider(teamId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return AppListTile.initial(
                        initial: customer.name[0],
                        title: customer.name,
                        subtitle: [customer.phone, customer.email]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
                        onTap: () =>
                            context.push('/customers/${customer.id}'),
                        trailing: WaIconButton(
                          phone: customer.phone,
                          message:
                              'Hola ${customer.name}, te escribo de $teamName.',
                        ),
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
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
