import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Data class for each action in the expandable FAB.
class FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? foregroundColor;

  const FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.foregroundColor,
  });
}

/// An expandable FAB that reveals child action buttons with animation.
/// Replaces stacked FABs with a cleaner, standard speed-dial pattern.
class ExpandableFab extends StatefulWidget {
  final List<FabAction> actions;

  const ExpandableFab({super.key, required this.actions});

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Child actions (appear above the main FAB)
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: 1.0,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: widget.actions.map((action) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ActionChip(
                      icon: action.icon,
                      label: action.label,
                      color: action.color ?? colorScheme.secondaryContainer,
                      foregroundColor: action.foregroundColor ??
                          colorScheme.onSecondaryContainer,
                      onPressed: () {
                        _toggle();
                        action.onPressed();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Main FAB
        if (_open)
          FloatingActionButton.extended(
            heroTag: 'expandable_fab',
            onPressed: _toggle,
            icon: const Icon(Icons.close),
            label: const Text('Cerrar'),
          )
        else
          FloatingActionButton(
            heroTag: 'expandable_fab',
            onPressed: _toggle,
            child: const Icon(Icons.add),
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            boxShadow: AppShadows.sm(context),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FloatingActionButton.small(
          heroTag: 'fab_$label',
          onPressed: onPressed,
          backgroundColor: color,
          foregroundColor: foregroundColor,
          elevation: 2,
          child: Icon(icon),
        ),
      ],
    );
  }
}
