import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// # Modal Pattern Guide
///
/// Use `showAppModal` for:
///   - Forms (create/edit customer, supplier, etc.)
///   - Selection lists (team switcher, product picker)
///   - Any content that benefits from more vertical space
///
/// Use `showAppConfirmation` for:
///   - Destructive confirmations (delete, logout, cancel)
///   - Simple yes/no decisions
///
/// Do NOT use raw `showDialog`/`showModalBottomSheet` directly.

/// Shows a modal bottom sheet with consistent padding and keyboard handling.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required String title,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

/// Shows a confirmation dialog for destructive or irreversible actions.
/// Returns `true` if confirmed, `false` or `null` otherwise.
Future<bool?> showAppConfirmation({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDestructive = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
