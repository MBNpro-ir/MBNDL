import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/ytdlp_settings_page.dart';
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
        GoRoute(
          path: '/ytdlp-settings',
          pageBuilder: (context, state) => _buildPageWithAnimation(
            context: context,
            state: state,
            child: const YtDlpSettingsPage(),
          ),
        ),
      ],
    ),
  ],
);

Page _buildPageWithAnimation({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}
