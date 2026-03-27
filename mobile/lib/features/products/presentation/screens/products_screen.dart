import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../core/providers/cache_for.dart';
import '../../data/products_repository.dart';

final productsProvider =
    FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(productsRepositoryProvider).getProducts(teamId);
});

final categoriesProvider =
    FutureProvider.autoDispose.family<List<CategoryModel>, String>((ref, teamId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.read(productsRepositoryProvider).getCategories(teamId);
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final products = ref.watch(productsProvider(teamId));
    final categories = ref.watch(categoriesProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;
    final cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear código',
            onPressed: () => context.push('/scanner'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          AppSearchField(
            hintText: 'Buscar productos...',
            value: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),

          // Category chips
          categories.whenOrNull(
                data: (cats) => cats.isNotEmpty
                    ? SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          children: [
                            _CategoryChip(
                              label: 'Todos',
                              selected: _selectedCategory == null,
                              onSelected: () =>
                                  setState(() => _selectedCategory = null),
                            ),
                            ...cats.map(
                              (c) => _CategoryChip(
                                label: c.name,
                                selected: _selectedCategory == c.id,
                                onSelected: () =>
                                    setState(() => _selectedCategory = c.id),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),

          // Product list
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                var filtered = items;
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.sku.toLowerCase().contains(q) ||
                          (p.barcode?.toLowerCase().contains(q) ?? false))
                      .toList();
                }
                if (_selectedCategory != null) {
                  filtered = filtered
                      .where((p) => p.categoryId == _selectedCategory)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: items.isEmpty
                        ? 'Sin productos'
                        : 'Sin resultados',
                    subtitle: items.isEmpty
                        ? 'Agrega tu primer producto para empezar'
                        : 'Intenta con otro término de búsqueda',
                    actionLabel: items.isEmpty ? 'Agregar producto' : null,
                    onAction: items.isEmpty
                        ? () => context.push('/products/new')
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(productsProvider(teamId));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                product.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(cop.format(product.price)),
                                  const SizedBox(width: AppSpacing.sm),
                                  StatusBadge(
                                    label: 'Stock: ${product.stock}',
                                    color: product.isLowStock ? AppColors.warning : AppColors.success,
                                  ),
                                ],
                              ),
                              if (product.barcode != null && product.barcode!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.qr_code,
                                        size: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          product.barcode!,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                                fontFamily: 'monospace',
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/products/${product.id}/edit'),
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
      floatingActionButton: ref.watch(authProvider).hasPermission('inventory.create_product')
          ? FloatingActionButton(
              onPressed: () => context.push('/products/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
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
