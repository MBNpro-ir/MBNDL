import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/ytdlp_settings_page.dart';
import '../theme/app_appearance.dart';
import 'main_scaffold.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => _buildPageWithAnimation(
            context: context,
            state: state,
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => _buildPageWithAnimation(
            context: context,
            state: state,
            child: const HistoryPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPageWithAnimation(
            context: context,
            state: state,
            child: const SettingsPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/ytdlp-settings',
      pageBuilder: (context, state) => _buildPageWithAnimation(
        context: context,
        state: state,
        child: const YtDlpSettingsPage(),
      ),
    ),
  ],
);

Future<void> openAppUpdateSettings() async {
  appRouter.go('/settings');
  for (final delay in const [80, 180, 320]) {
    await Future<void>.delayed(Duration(milliseconds: delay));
    final context = appUpdatesSettingsSectionKey.currentContext;
    if (context == null || !context.mounted) continue;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.12,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    return;
  }
}

Page _buildPageWithAnimation({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final appearance = Theme.of(context).extension<AppSurfaceTheme>()?.settings;
  final reduceMotion =
      appearance?.motionMode == AppMotionMode.reduced ||
      (appearance?.motionMode == AppMotionMode.system &&
          MediaQuery.maybeOf(context)?.disableAnimations == true);
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 340),
    reverseTransitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
