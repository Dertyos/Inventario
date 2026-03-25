import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable card + list tile with leading avatar.
/// Eliminates the duplicated Card>ListTile>Container pattern across 5+ screens.
class AppListTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// Creates a list tile with a colored initial avatar as leading widget.
  factory AppListTile.initial({
    Key? key,
    required String initial,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
    double size = AppDimensions.avatarLg,
  }) {
    return AppListTile(
      key: key,
      leading: _InitialAvatar(
        initial: initial,
        size: size,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Creates a list tile with a colored icon as leading widget.
  factory AppListTile.icon({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? iconColor,
    double size = AppDimensions.avatarMd,
  }) {
    return AppListTile(
      key: key,
      leading: _IconAvatar(
        icon: icon,
        size: size,
        backgroundColor: backgroundColor,
        iconColor: iconColor,
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: leading,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _InitialAvatar({
    required this.initial,
    required this.size,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: foregroundColor ?? colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const _IconAvatar({
    required this.icon,
    required this.size,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor ?? colorScheme.onPrimaryContainer,
          size: AppDimensions.iconSizeMd,
        ),
      ),
    );
  }
}
