import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Shows a modal bottom sheet with consistent padding and keyboard handling.
/// Replaces the duplicated showModalBottomSheet pattern in Customers and Inventory.
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
