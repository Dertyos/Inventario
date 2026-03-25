import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/payment_reminder_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/reminders_repository.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String? _statusFilter;
  bool _generating = false;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('d MMM yyyy', 'es');

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(authProvider).teamId;
    final asyncReminders =
        ref.watch(remindersProvider((teamId, _statusFilter)));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios de pago'),
        actions: [
          IconButton(
            onPressed: _generating ? null : () => _generate(teamId),
            tooltip: 'Generar recordatorios',
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _statusFilter == null,
                  onSelected: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Pendiente',
                  selected: _statusFilter == 'pending',
                  onSelected: () =>
                      setState(() => _statusFilter = 'pending'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Enviado',
                  selected: _statusFilter == 'sent',
                  onSelected: () => setState(() => _statusFilter = 'sent'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Fallido',
                  selected: _statusFilter == 'failed',
                  onSelected: () =>
                      setState(() => _statusFilter = 'failed'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: asyncReminders.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(e.toString(), textAlign: TextAlign.center),
                ),
              ),
              data: (reminders) {
                if (reminders.isEmpty) {
                  return const EmptyState(
                    icon: Icons.alarm_off,
                    title: 'Sin recordatorios',
                    subtitle:
                        'Pulsa el botón de generar para crear recordatorios automáticos.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(remindersProvider);
                  },
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _ReminderTile(
                          reminder: reminders[index],
                          currencyFormat: _currencyFormat,
                          dateFormat: _dateFormat,
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(String teamId) async {
    setState(() => _generating = true);
    try {
      final repo = ref.read(remindersRepositoryProvider);
      final count = await repo.generateReminders(teamId);
      ref.invalidate(remindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'Se generaron $count recordatorio(s)'
                : 'No hay cuotas próximas a vencer'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final PaymentReminderModel reminder;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _ReminderTile({
    required this.reminder,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel icon
          Container(
            width: AppDimensions.avatarMd,
            height: AppDimensions.avatarMd,
            decoration: BoxDecoration(
              color: _channelColor(reminder.channel)
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(
              _channelIcon(reminder.channel),
              size: AppDimensions.iconSizeMd,
              color: _channelColor(reminder.channel),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.customerName ?? 'Cliente',
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusBadge(status: reminder.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  currencyFormat.format(reminder.remainingAmount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(reminder.scheduledDate),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      _channelIcon(reminder.channel),
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reminder.channelLabel,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                    ),
                  ],
                ),
                if (reminder.message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reminder.message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return dateFormat.format(date);
    } catch (_) {
      return isoDate;
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'sms':
        return Icons.sms_outlined;
      case 'whatsapp':
        return Icons.chat_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'push':
        return Icons.notifications_outlined;
      case 'internal':
        return Icons.inbox_outlined;
      default:
        return Icons.send;
    }
  }

  Color _channelColor(String channel) {
    switch (channel) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'sms':
        return const Color(0xFF4F6BF6);
      case 'email':
        return const Color(0xFFFF9F43);
      default:
        return const Color(0xFF6C757D);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case 'pending':
        bg = AppColors.warningBg(context);
        fg = AppColors.warning;
        break;
      case 'sent':
        bg = AppColors.successBg(context);
        fg = AppColors.success;
        break;
      case 'failed':
        bg = AppColors.dangerBg(context);
        fg = AppColors.danger;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey;
    }

    final label = switch (status) {
      'pending' => 'Pendiente',
      'sent' => 'Enviado',
      'failed' => 'Fallido',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
