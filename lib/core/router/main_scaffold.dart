import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const _destinations = <_AppDestination>[
    _AppDestination(
      label: 'Home',
      route: '/home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _AppDestination(
      label: 'History',
      route: '/history',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
    ),
    _AppDestination(
      label: 'Settings',
      route: '/settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  Offset? _touchStart;
  DateTime? _touchStartedAt;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings') ||
        location.startsWith('/ytdlp-settings')) {
      return 2;
    }
    return 0;
  }

  void _select(BuildContext context, int index) {
    context.go(_destinations[index].route);
  }

  void _pointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch &&
        event.kind != PointerDeviceKind.stylus) {
      return;
    }
    _touchStart = event.position;
    _touchStartedAt = DateTime.now();
  }

  void _pointerUp(PointerUpEvent event, int currentIndex) {
    final start = _touchStart;
    final startedAt = _touchStartedAt;
    _touchStart = null;
    _touchStartedAt = null;
    if (start == null || startedAt == null) return;
    if (DateTime.now().difference(startedAt) >
        const Duration(milliseconds: 750)) {
      return;
    }

    final delta = event.position - start;
    if (delta.dx.abs() < 72 || delta.dx.abs() < delta.dy.abs() * 1.35) return;
    final nextIndex = delta.dx < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= _destinations.length) return;
    _select(context, nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _currentIndex(context);
    final useRail = width >= 600;
    final swipableChild = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerUp: (event) => _pointerUp(event, selectedIndex),
      onPointerCancel: (_) {
        _touchStart = null;
        _touchStartedAt = null;
      },
      child: widget.child,
    );

    if (!useRail) {
      return Scaffold(
        body: swipableChild,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _select(context, index),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= 1000;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minWidth: 80,
              minExtendedWidth: 224,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _select(context, index),
              groupAlignment: -0.72,
              leading: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Text(
                        'MBNDL',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
            Expanded(child: swipableChild),
          ],
        ),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
}
