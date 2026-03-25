import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/credit_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/credits_repository.dart';
import 'credit_detail_screen.dart';

final _currencyFormat =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  int _selectedFilter = 0; // 0=Todos, 1=Activos, 2=Pagados, 3=Vencidos

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final creditsAsync = ref.watch(creditsProvider(teamId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _buildFilterChip(0, 'Todos', Icons.list),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(1, 'Activos', Icons.schedule),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(2, 'Pagados', Icons.check_circle_outline),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip(3, 'Vencidos', Icons.warning_amber_rounded),
              ],
            ),
          ),
          // List
          Expanded(
            child: creditsAsync.when(
              data: (credits) {
                final filtered = _applyFilter(credits);
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Sin créditos',
                    subtitle: _selectedFilter == 0
                        ? 'No hay cuentas de crédito registradas'
                        : 'No hay créditos con este filtro',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(creditsProvider(teamId).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _CreditCard(credit: filtered[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colorScheme.error),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(creditsProvider(teamId)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CreditAccountModel> _applyFilter(List<CreditAccountModel> credits) {
    switch (_selectedFilter) {
      case 1:
        return credits
            .where((c) => c.status == CreditStatus.active)
            .toList();
      case 2:
        return credits
            .where((c) => c.status == CreditStatus.paid)
            .toList();
      case 3:
        return credits
            .where((c) =>
                c.status == CreditStatus.defaulted || c.isOverdue)
            .toList();
      default:
        return credits;
    }
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => setState(() => _selectedFilter = index),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
}

class _CreditCard extends ConsumerWidget {
  final CreditAccountModel credit;

  const _CreditCard({required this.credit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreditDetailScreen(creditId: credit.id),
            ),
          );
          final teamId = ref.read(authProvider).teamId;
          ref.invalidate(creditsProvider(teamId));
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: customer name + status badge
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credit.customer?.name ?? 'Cliente',
                          style: textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${credit.installments} cuotas',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(credit: credit),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Amounts row
              Row(
                children: [
                  Expanded(
                    child: _AmountInfo(
                      label: 'Total',
                      amount: credit.totalAmount,
                    ),
                  ),
                  Expanded(
                    child: _AmountInfo(
                      label: 'Pagado',
                      amount: credit.paidAmount,
                    ),
                  ),
                  Expanded(
                    child: _AmountInfo(
                      label: 'Saldo',
                      amount: credit.balance,
                      highlight: credit.balance > 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: credit.progressPercent,
                  minHeight: 6,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest,
                  color: credit.status == CreditStatus.paid
                      ? AppColors.success
                      : credit.isOverdue
                          ? AppColors.danger
                          : colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Progress label
              Text(
                '${(credit.progressPercent * 100).toStringAsFixed(0)}% pagado',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CreditAccountModel credit;

  const _StatusBadge({required this.credit});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;

    switch (credit.status) {
      case CreditStatus.paid:
        bgColor = AppColors.successBg(context);
        fgColor = AppColors.success;
        break;
      case CreditStatus.defaulted:
        bgColor = AppColors.dangerBg(context);
        fgColor = AppColors.danger;
        break;
      case CreditStatus.active:
        if (credit.isOverdue) {
          bgColor = AppColors.warningBg(context);
          fgColor = AppColors.warning;
        } else {
          bgColor = AppColors.infoBg(context);
          fgColor = AppColors.info;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        credit.isOverdue && credit.status == CreditStatus.active
            ? 'Vencido'
            : credit.statusLabel,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AmountInfo extends StatelessWidget {
  final String label;
  final double amount;
  final bool highlight;

  const _AmountInfo({
    required this.label,
    required this.amount,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.danger : null,
              ),
        ),
      ],
    );
  }
}
