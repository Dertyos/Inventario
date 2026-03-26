import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Paths de navegación ──────────────────────────────────────────────────────
const _kPaths = [
  '/dashboard',
  '/products',
  '/sales',
  '/inventory',
  '/settings',
];

// ─── Definición de cada tab ───────────────────────────────────────────────────
const _kNavItems = [
  _NavItem(icon: Icons.dashboard_rounded,      label: 'Inicio',      color: Color(0xFF4F6BF6)),
  _NavItem(icon: Icons.inventory_2_rounded,    label: 'Productos',   color: Color(0xFF2ECC71)),
  _NavItem(icon: Icons.point_of_sale_rounded,  label: 'Ventas',      color: Color(0xFFFF6B6B)),
  _NavItem(icon: Icons.swap_vert_rounded,      label: 'Inventario',  color: Color(0xFFFF9F43)),
  _NavItem(icon: Icons.more_horiz_rounded,     label: 'Más',         color: Color(0xFF9B59B6)),
];

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  const _NavItem({required this.icon, required this.label, required this.color});
}

// ─── Shell principal ──────────────────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _kPaths.indexWhere((p) => location.startsWith(p));
    final safeIdx = idx < 0 ? 0 : idx;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(safeIdx), child: child),
      ),
      bottomNavigationBar: _WaterDropNavBar(
        currentIndex: safeIdx,
        onTap: (i) {
          if (i != safeIdx) context.go(_kPaths[i]);
        },
      ),
    );
  }
}

// ─── Water-drop navigation bar ────────────────────────────────────────────────
class _WaterDropNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _WaterDropNavBar({required this.currentIndex, required this.onTap});

  @override
  State<_WaterDropNavBar> createState() => _WaterDropNavBarState();
}

class _WaterDropNavBarState extends State<_WaterDropNavBar>
    with TickerProviderStateMixin {
  // El borde que «sale primero» (lead) y el que «arrastra» (follow)
  late AnimationController _lead;
  late AnimationController _follow;
  int _from = 0;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void initState() {
    super.initState();
    _from = widget.currentIndex;
    _lead   = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _follow = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    // Empieza en posición final (sin animación inicial)
    _lead.value   = 1;
    _follow.value = 1;
  }

  @override
  void didUpdateWidget(_WaterDropNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _from = old.currentIndex;
      _lead.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 55), () {
        if (mounted) _follow.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _lead.dispose();
    _follow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemW  = constraints.maxWidth / _kNavItems.length;
              const vPad   = 6.0;
              const hPad   = 10.0;

              return AnimatedBuilder(
                animation: Listenable.merge([_lead, _follow]),
                builder: (context, _) {
                  final to  = widget.currentIndex;
                  final goRight = to > _from;

                  final leadT   = CurvedAnimation(parent: _lead,   curve: Curves.easeOut).value;
                  final followT = CurvedAnimation(parent: _follow, curve: Curves.easeOut).value;

                  // Calcula bordes izquierdo y derecho del pill
                  final double leftX, rightX;
                  if (goRight) {
                    // Derecha se adelanta, izquierda arrastra
                    rightX = _lerp(_from * itemW + itemW - hPad, to * itemW + itemW - hPad, leadT);
                    leftX  = _lerp(_from * itemW + hPad,         to * itemW + hPad,         followT);
                  } else {
                    // Izquierda se adelanta, derecha arrastra
                    leftX  = _lerp(_from * itemW + hPad,         to * itemW + hPad,         leadT);
                    rightX = _lerp(_from * itemW + itemW - hPad, to * itemW + itemW - hPad, followT);
                  }

                  final pillColor = _kNavItems[to].color;

                  return Stack(
                    children: [
                      // ── Pill deslizante ────────────────────────────────────
                      Positioned(
                        left:   leftX,
                        top:    vPad,
                        bottom: vPad,
                        child: Container(
                          width: rightX - leftX,
                          decoration: BoxDecoration(
                            color: pillColor.withValues(alpha: isDark ? 0.22 : 0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      // ── Iconos + labels ────────────────────────────────────
                      Row(
                        children: List.generate(_kNavItems.length, (i) {
                          final item     = _kNavItems[i];
                          final selected = i == to;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onTap(i),
                            child: SizedBox(
                              width: itemW,
                              height: 64,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: selected ? 1.15 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      item.icon,
                                      size: 23,
                                      color: selected
                                          ? item.color
                                          : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? item.color
                                          : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                      fontFamily:
                                          theme.textTheme.labelSmall?.fontFamily,
                                    ),
                                    child: Text(item.label),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
