import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/credit_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/credits_repository.dart';

final _currencyFormat =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dateFormat = DateFormat('dd MMM yyyy', 'es');

class CreditDetailScreen extends ConsumerWidget {
  final String creditId;

  const CreditDetailScreen({super.key, required this.creditId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(authProvider).teamId;
    final creditAsync = ref.watch(
      creditDetailProvider((teamId: teamId, creditId: creditId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Crédito'),
      ),
      body: creditAsync.when(
        data: (credit) => _CreditDetailBody(credit: credit),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(creditDetailProvider(
                      (teamId: teamId, creditId: creditId))),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditDetailBody extends ConsumerWidget {
  final CreditAccountModel credit;

  const _CreditDetailBody({required this.credit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () {
        final teamId = ref.read(authProvider).teamId;
        return ref.refresh(
          creditDetailProvider((teamId: teamId, creditId: credit.id)).future,
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer & status
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              credit.customer?.name ?? 'Cliente',
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              'Inicio: ${_formatDate(credit.startDate)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(context),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  // Amounts grid
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Total',
                          value: _currencyFormat.format(credit.totalAmount),
                          icon: Icons.account_balance_wallet,
                          color: colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Pagado',
                          value: _currencyFormat.format(credit.paidAmount),
                          icon: Icons.check_circle,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Saldo',
                          value: _currencyFormat.format(credit.balance),
                          icon: Icons.pending,
                          color: credit.balance > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Interés',
                          value: credit.interestType == InterestType.none
                              ? 'Sin interés'
                              : '${credit.interestRate.toStringAsFixed(1)}% ${credit.interestTypeLabel.toLowerCase()}',
                          icon: Icons.percent,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: credit.progressPercent,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: credit.status == CreditStatus.paid
                          ? AppColors.success
                          : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${(credit.progressPercent * 100).toStringAsFixed(0)}% completado - ${credit.installments} cuotas',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Installments header
          Text(
            'Cuotas',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Installments list
          ...credit.creditInstallments.map(
            (installment) => _InstallmentTile(
              installment: installment,
              creditId: credit.id,
              creditStatus: credit.status,
              customerName: credit.customer?.name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return _dateFormat.format(date);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstallmentTile extends ConsumerWidget {
  final CreditInstallmentModel installment;
  final String creditId;
  final CreditStatus creditStatus;
  final String? customerName;

  const _InstallmentTile({
    required this.installment,
    required this.creditId,
    required this.creditStatus,
    this.customerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPaid = installment.status == InstallmentStatus.paid;
    final canPay = !isPaid && creditStatus != CreditStatus.paid;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _installmentColor(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${installment.installmentNumber}',
              style: textTheme.titleSmall?.copyWith(
                color: _installmentColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _currencyFormat.format(installment.amount),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration:
                      isPaid ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            _buildInstallmentBadge(context),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Vence: ${_formatDate(installment.dueDate)}',
              style: textTheme.bodySmall?.copyWith(
                color: installment.isOverdue
                    ? AppColors.danger
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (installment.paidAmount > 0 && !isPaid)
              Text(
                'Abonado: ${_currencyFormat.format(installment.paidAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                ),
              ),
          ],
        ),
        trailing: canPay
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_outlined, size: 20),
                    tooltip: 'Cobrar por WhatsApp',
                    onPressed: () => _sendWhatsAppReminder(context),
                    color: AppColors.success,
                  ),
                  IconButton(
                    icon: Icon(Icons.payment, color: colorScheme.primary),
                    tooltip: 'Registrar abono',
                    onPressed: () => _showPayDialog(context, ref),
                  ),
                ],
              )
            : isPaid
                ? Icon(Icons.check_circle, color: AppColors.success, size: 24)
                : null,
      ),
    );
  }

  Color _installmentColor(BuildContext context) {
    if (installment.status == InstallmentStatus.paid) return AppColors.success;
    if (installment.isOverdue) return AppColors.danger;
    if (installment.status == InstallmentStatus.partial) {
      return AppColors.warning;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildInstallmentBadge(BuildContext context) {
    Color bgColor;
    Color fgColor;
    final label = installment.statusLabel;

    switch (installment.status) {
      case InstallmentStatus.paid:
        bgColor = AppColors.successBg(context);
        fgColor = AppColors.success;
        break;
      case InstallmentStatus.overdue:
        bgColor = AppColors.dangerBg(context);
        fgColor = AppColors.danger;
        break;
      case InstallmentStatus.partial:
        bgColor = installment.isOverdue
            ? AppColors.dangerBg(context)
            : AppColors.warningBg(context);
        fgColor =
            installment.isOverdue ? AppColors.danger : AppColors.warning;
        break;
      case InstallmentStatus.pending:
        if (installment.isOverdue) {
          bgColor = AppColors.dangerBg(context);
          fgColor = AppColors.danger;
        } else {
          bgColor = AppColors.infoBg(context);
          fgColor = AppColors.info;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return _dateFormat.format(date);
  }

  void _sendWhatsAppReminder(BuildContext context) {
    final name = customerName ?? 'Cliente';
    final amount = _currencyFormat.format(installment.balance);
    final dueDate = _formatDate(installment.dueDate);
    final message =
        'Hola $name, te recuerdo que tienes un pago pendiente de $amount con vencimiento $dueDate. Gracias!';
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/?text=$encoded');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _showPayDialog(BuildContext context, WidgetRef ref) {
    final remaining = installment.balance;
    final amountController =
        TextEditingController(text: remaining.toStringAsFixed(0));
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar Abono'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuota #${installment.installmentNumber} - Saldo: ${_currencyFormat.format(remaining)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$ ',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa un monto';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Monto inválido';
                    }
                    if (amount > remaining) {
                      return 'Excede el saldo pendiente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    hintText: 'Ej: NEQUI-123',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final amount = double.parse(amountController.text);
              final data = <String, dynamic>{'amount': amount};
              if (referenceController.text.isNotEmpty) {
                data['reference'] = referenceController.text;
              }
              if (notesController.text.isNotEmpty) {
                data['notes'] = notesController.text;
              }

              Navigator.of(dialogContext).pop();

              try {
                final teamId = ref.read(authProvider).teamId;
                final repo = ref.read(creditsRepositoryProvider);
                await repo.payInstallment(
                  teamId,
                  creditId,
                  installment.id,
                  data,
                );
                ref.invalidate(creditDetailProvider(
                    (teamId: teamId, creditId: creditId)));
                ref.invalidate(creditsProvider(teamId));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Abono de ${_currencyFormat.format(amount)} registrado',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
  }
}
