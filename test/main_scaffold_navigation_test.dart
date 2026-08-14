import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbn_downloader/core/router/main_scaffold.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('Home body')),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) => const Center(child: Text('History body')),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, _) => Center(
                child: FilledButton(
                  onPressed: () => context.push('/ytdlp-settings'),
                  child: const Text('Open yt-dlp settings'),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/ytdlp-settings',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('Nested yt-dlp settings')),
          ),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('primary pages can be changed with a horizontal swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Home body'), const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('History body'), findsOneWidget);
  });

  testWidgets('nested yt-dlp settings ignores the primary-page swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open yt-dlp settings'));
    await tester.pumpAndSettle();
    expect(find.text('Nested yt-dlp settings'), findsOneWidget);

    await tester.drag(
      find.text('Nested yt-dlp settings'),
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nested yt-dlp settings'), findsOneWidget);
    expect(find.text('History body'), findsNothing);
  });
}
