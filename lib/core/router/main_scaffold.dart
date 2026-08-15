import 'dart:io';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/app_appearance.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
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
  late final AnimationController _navigationCollapseController;

  @override
  void initState() {
    super.initState();
    _navigationCollapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _navigationCollapseController.dispose();
    super.dispose();
  }

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

  bool _handleUserScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final bool? collapse = switch (notification) {
      UserScrollNotification(direction: ScrollDirection.reverse) => true,
      UserScrollNotification(direction: ScrollDirection.forward) => false,
      ScrollUpdateNotification(scrollDelta: final delta?)
          when notification.dragDetails != null && delta.abs() > 0.5 =>
        delta > 0,
      _ => null,
    };
    if (collapse == null) return false;
    _setNavigationCollapsed(collapse);
    return false;
  }

  void _setNavigationCollapsed(bool collapse) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _navigationCollapseController.value = collapse ? 1 : 0;
    } else if (collapse) {
      _navigationCollapseController.forward();
    } else {
      _navigationCollapseController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _currentIndex(context);
    final appearance =
        Theme.of(context).extension<AppSurfaceTheme>()?.settings ??
        const AppAppearanceSettings();
    final colors = Theme.of(context).colorScheme;
    final useRail = width >= 760;
    final isPrimaryPage = _isPrimaryPage(context);
    Widget mobileChild = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) {
        if (event.delta.dy.abs() <= 1) return;
        _setNavigationCollapsed(event.delta.dy < 0);
      },
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
        _setNavigationCollapsed(event.scrollDelta.dy > 0);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleUserScroll,
        child: widget.child,
      ),
    );
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
            child: mobileChild,
          )
        : mobileChild;

    if (!useRail) {
      if (appearance.liquidGlassEnabled && appearance.floatingNavigation) {
        return AnimatedBuilder(
          animation: _navigationCollapseController,
          builder: (context, _) => _buildLiquidGlassNavigation(
            context: context,
            body: swipableChild,
            selectedIndex: selectedIndex,
            appearance: appearance,
            availableWidth: width,
          ),
        );
      }

      if (appearance.floatingNavigation) {
        return AnimatedBuilder(
          animation: _navigationCollapseController,
          builder: (context, _) {
            final curved = Curves.easeInOutCubic.transform(
              _navigationCollapseController.value,
            );
            final maximumWidth = (width - 28).clamp(216.0, 340.0);
            final barWidth = lerpDouble(
              maximumWidth.clamp(288.0, 324.0),
              maximumWidth.clamp(216.0, 236.0),
              curved,
            )!;
            final barHeight = lerpDouble(64, 50, curved)!;
            final showLabels = curved < 0.58;
            final reduceMotion =
                MediaQuery.maybeOf(context)?.disableAnimations ?? false;
            final navigation = _buildMaterialNavigationBar(
              context: context,
              selectedIndex: selectedIndex,
              height: barHeight,
              showLabels: showLabels,
              reduceMotion: reduceMotion,
            );
            return Scaffold(
              extendBody: true,
              body: _buildFadedNavigationBody(context, swipableChild),
              bottomNavigationBar: SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: lerpDouble(10, 7, curved)!),
                child: Align(
                  heightFactor: 1,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    key: const ValueKey('material-floating-navigation'),
                    width: barWidth,
                    height: barHeight,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 3,
                      shadowColor: colors.shadow.withValues(alpha: 0.18),
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: DecoratedBox(
                          key: const ValueKey(
                            'material-floating-navigation-surface',
                          ),
                          decoration: ShapeDecoration(
                            color: colors.surfaceContainer.withValues(
                              alpha: 0.52,
                            ),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                          ),
                          child: navigation,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }

      final navigation = _buildMaterialNavigationBar(
        context: context,
        selectedIndex: selectedIndex,
        height: 80,
        showLabels: true,
        reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      );
      return Scaffold(
        extendBody: false,
        body: swipableChild,
        bottomNavigationBar: navigation,
      );
    }

    final extended = width >= 1240;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(30),
                child: NavigationRail(
                  extended: extended,
                  minWidth: 72,
                  minExtendedWidth: 212,
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
                            borderRadius: BorderRadius.circular(18),
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
              ),
            ),
            Expanded(child: swipableChild),
          ],
        ),
      ),
    );
  }

  NavigationBar _buildMaterialNavigationBar({
    required BuildContext context,
    required int selectedIndex,
    required double height,
    required bool showLabels,
    required bool reduceMotion,
  }) {
    return NavigationBar(
      key: const ValueKey('primary-bottom-navigation'),
      height: height,
      backgroundColor: Colors.transparent,
      elevation: 0,
      animationDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      labelBehavior: showLabels
          ? NavigationDestinationLabelBehavior.alwaysShow
          : NavigationDestinationLabelBehavior.alwaysHide,
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
    );
  }

  Widget _buildFadedNavigationBody(BuildContext context, Widget body) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey('floating-navigation-body'),
          child: KeyedSubtree(
            key: const ValueKey('floating-navigation-content'),
            child: body,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 82 + media.padding.bottom,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('floating-navigation-fade'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.48, 0.78, 1],
                  colors: [
                    colors.surface.withValues(alpha: 0),
                    colors.surface.withValues(alpha: 0.04),
                    colors.surface.withValues(alpha: 0.10),
                    colors.surface.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiquidGlassNavigation({
    required BuildContext context,
    required Widget body,
    required int selectedIndex,
    required AppAppearanceSettings appearance,
    required double availableWidth,
  }) {
    final colors = Theme.of(context).colorScheme;
    final curved = Curves.easeInOutCubic.transform(
      _navigationCollapseController.value,
    );
    final maximumWidth = (availableWidth - 28).clamp(220.0, 360.0);
    final expandedWidth = maximumWidth.clamp(288.0, 324.0);
    final compactWidth = maximumWidth.clamp(216.0, 236.0);
    final barWidth = lerpDouble(expandedWidth, compactWidth, curved)!;
    final barHeight = lerpDouble(64, 50, curved)!;
    final bottomMargin = lerpDouble(10, 7, curved)!;
    final showLabels = curved < 0.58;
    final blur = (1.4 + appearance.glassBlur / 6).clamp(2.0, 6.5);
    final refraction = appearance.glassRefraction.clamp(0.0, 1.0);
    final qualityScale = switch (appearance.glassQuality) {
      GlassQuality.efficient => 0.58,
      GlassQuality.balanced => 0.78,
      GlassQuality.vivid => 1.0,
      GlassQuality.adaptive => Platform.isAndroid ? 0.72 : 0.66,
    };
    final tintAlpha = (appearance.glassOpacity * 0.34).clamp(0.08, 0.34);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final style = LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: barHeight / 2,
        borderWidth: appearance.depthEffect ? 1.25 : 0.8,
        lightIntensity: appearance.depthEffect ? 1.35 : 0.82,
        lightDirection: 42,
        borderType: OpticalBorder(
          borderSaturation: 1 + appearance.glassVibrancy * 0.75,
          ambientIntensity: appearance.depthEffect ? 1.1 : 0.55,
          borderSolidity: appearance.depthEffect ? 0.12 : 0.04,
          lightSpread: 0.68,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: colors.surfaceContainerHigh.withValues(alpha: tintAlpha),
        blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
        saturation: 1 + appearance.glassVibrancy * 0.42,
      ),
      refraction: LiquidGlassRefraction(
        distortion: 0.035 + refraction * 0.095,
        distortionWidth: 18 + refraction * 18,
        magnification: 1 + refraction * 0.025,
        chromaticAberration: appearance.chromaticAberration
            ? 0.001 + refraction * 0.003
            : 0,
      ),
    );

    final navBar = LiquidGlassBottomNavBar(
      key: const ValueKey('primary-liquid-glass-navigation'),
      items: [
        for (final destination in _destinations)
          LiquidGlassTabBarItem(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: showLabels ? destination.label : null,
          ),
      ],
      selectedIndex: selectedIndex,
      onChanged: (index) => _select(context, index),
      width: barWidth,
      height: barHeight,
      margin: EdgeInsets.only(bottom: bottomMargin),
      itemPadding: lerpDouble(6, 4, curved)!,
      style: style,
      itemStyle: LiquidGlassNavItemStyle(
        selectedColor: colors.onSurface,
        unselectedColor: colors.onSurfaceVariant,
        iconSize: lerpDouble(24, 21, curved)!,
        labelFontSize: lerpDouble(10.5, 9, curved)!,
        iconLabelGap: lerpDouble(2, 0, curved)!,
        selectedFontWeight: FontWeight.w700,
      ),
      pillStyle: LiquidGlassNavPillStyle(
        // Android Impeller gets the live dual-pipeline morphing lens. The
        // nested Skia capture path can crash flutter_windows.dll while the
        // page and bar resize together, so Windows uses the stable single-lens
        // renderer below while retaining the optical capsule and slide motion.
        mode: LiquidGlassPillMode.impellerOnly,
        animated: !reduceMotion,
        color: colors.primary.withValues(alpha: 0.16),
        growHeight: reduceMotion ? 0 : (appearance.depthEffect ? 9 : 5),
        distortion: 0.04 + refraction * 0.06,
        distortionWidth: 10 + refraction * 8,
        magnification: 1 + refraction * 0.02,
        enableInnerRadiusTransparent: true,
      ),
    );

    return LiquidGlassScaffold(
      backgroundColor: colors.surface,
      pixelRatio: qualityScale,
      realTimeCapture: !Platform.isWindows,
      useSync: appearance.glassQuality != GlassQuality.efficient,
      useImpellerBackdrop: Platform.isWindows ? false : null,
      body: _buildFadedNavigationBody(context, body),
      bottomNavigationBar: navBar,
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
