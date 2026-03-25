import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable search field with clear button.
/// Used in: Products, Customers, and any future list screen.
class AppSearchField extends StatelessWidget {
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;

  const AppSearchField({
    super.key,
    required this.hintText,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(''),
                )
              : null,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
