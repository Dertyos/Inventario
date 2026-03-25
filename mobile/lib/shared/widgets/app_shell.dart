import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_rounded, activeIcon: Icons.dashboard, label: 'Inicio', path: '/dashboard'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, label: 'Productos', path: '/products'),
    _TabItem(icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale_rounded, label: 'Ventas', path: '/sales'),
    _TabItem(icon: Icons.swap_vert_rounded, activeIcon: Icons.swap_vert_rounded, label: 'Inventario', path: '/inventory'),
    _TabItem(icon: Icons.more_horiz_rounded, activeIcon: Icons.more_horiz_rounded, label: 'Más', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        elevation: 0,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        onDestinationSelected: (index) {
          if (index != currentIndex) {
            context.go(_tabs[index].path);
          }
        },
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.path});
}
