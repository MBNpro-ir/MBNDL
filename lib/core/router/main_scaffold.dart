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

  double _horizontalDrag = 0;
  DateTime? _dragStartedAt;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return switch (location) {
      '/history' => 1,
      '/settings' => 2,
      _ => 0,
    };
  }

  bool _isPrimaryPage(BuildContext context) => const {
    '/home',
    '/history',
    '/settings',
  }.contains(GoRouterState.of(context).uri.path);

  void _select(BuildContext context, int index) {
    context.go(_destinations[index].route);
  }

  void _dragStart(DragStartDetails details) {
    _horizontalDrag = 0;
    _dragStartedAt = DateTime.now();
  }

  void _dragUpdate(DragUpdateDetails details) {
    _horizontalDrag += details.primaryDelta ?? 0;
  }

  void _dragEnd(DragEndDetails details, int currentIndex) {
    final startedAt = _dragStartedAt;
    final distance = _horizontalDrag;
    _horizontalDrag = 0;
    _dragStartedAt = null;
    if (startedAt == null) return;
    if (DateTime.now().difference(startedAt) >
        const Duration(milliseconds: 750)) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (distance.abs() < 72 && velocity.abs() < 650) return;
    final direction = distance.abs() >= 24 ? distance : velocity;
    final nextIndex = direction < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= _destinations.length) return;
    _select(context, nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _currentIndex(context);
    final useRail = width >= 600;
    final isPrimaryPage = _isPrimaryPage(context);
    final swipableChild = !useRail && isPrimaryPage
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _dragStart,
            onHorizontalDragUpdate: _dragUpdate,
            onHorizontalDragEnd: (details) => _dragEnd(details, selectedIndex),
            onHorizontalDragCancel: () {
              _horizontalDrag = 0;
              _dragStartedAt = null;
            },
            child: widget.child,
          )
        : widget.child;

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
