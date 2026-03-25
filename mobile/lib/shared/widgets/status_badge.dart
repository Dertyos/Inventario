import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Small colored badge for status indicators (stock level, transaction type, etc).
/// Replaces hardcoded Container+Text patterns with Colors.green/orange/red.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  /// Green badge for positive status.
  factory StatusBadge.success(String label) => StatusBadge(
        label: label,
        color: AppColors.success,
      );

  /// Orange badge for warning status.
  factory StatusBadge.warning(String label) => StatusBadge(
        label: label,
        color: AppColors.warning,
      );

  /// Red badge for danger/error status.
  factory StatusBadge.danger(String label) => StatusBadge(
        label: label,
        color: AppColors.danger,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
