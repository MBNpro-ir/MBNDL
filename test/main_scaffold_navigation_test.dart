import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:mbn_downloader/core/theme/app_appearance.dart';
import 'package:mbn_downloader/core/router/main_scaffold.dart';
import 'package:mbn_downloader/core/utils/floating_navigation_insets.dart';

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

  testWidgets('wide layouts use an extended navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('compact tablet layouts keep bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Material floating navigation is compact over faded content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBody, isTrue);
    expect(
      find.byKey(const ValueKey('floating-navigation-fade')),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('material-floating-navigation-surface')),
    );
    final surfaceColor = (surface.decoration as ShapeDecoration).color!;
    expect(surfaceColor.toARGB32() >> 24, lessThan(192));
    final navigationSize = tester.widget<SizedBox>(
      find.byKey(const ValueKey('material-floating-navigation')),
    );
    expect(navigationSize.width, lessThanOrEqualTo(324));
    expect(navigationSize.height, 64);
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('floating-navigation-content')),
          )
          .dy,
      greaterThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('material-floating-navigation')),
            )
            .dy,
      ),
    );
  });

  testWidgets('Reduced motion collapses floating navigation immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.pump();

    final expanded = tester.widget<SizedBox>(
      find.byKey(const ValueKey('material-floating-navigation')),
    );
    final navigation = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('primary-bottom-navigation')),
    );
    expect(navigation.animationDuration, Duration.zero);

    await tester.drag(find.text('Home body'), const Offset(0, -120));
    await tester.pump();

    final collapsed = tester.widget<SizedBox>(
      find.byKey(const ValueKey('material-floating-navigation')),
    );
    expect(collapsed.width, lessThan(expanded.width!));
    expect(collapsed.height, 50);
  });

  testWidgets('Liquid Glass navigation reserves space and shrinks on scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scrollRouter = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, _) => Scaffold(
                body: ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: floatingNavigationScrollClearance(context),
                  ),
                  itemExtent: 72,
                  itemCount: 40,
                  itemBuilder: (_, index) => Text('Row $index'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(scrollRouter.dispose);
    const appearance = AppAppearanceSettings(
      surfaceStyle: AppSurfaceStyle.liquidGlass,
      floatingNavigation: true,
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: const [AppSurfaceTheme(appearance)]),
        routerConfig: scrollRouter,
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    LiquidGlassScaffold glassScaffold = tester.widget(
      find.byType(LiquidGlassScaffold),
    );
    final expanded =
        (glassScaffold.bottomNavigationBar as LiquidGlassBottomNavBar).width;
    final glassNavigation =
        glassScaffold.bottomNavigationBar as LiquidGlassBottomNavBar;
    expect(glassNavigation.pillStyle.mode, LiquidGlassPillMode.impellerOnly);
    expect(glassScaffold.useImpellerBackdrop, isFalse);
    expect(glassScaffold.realTimeCapture, isFalse);
    expect(glassScaffold.body, isA<Stack>());
    expect(
      find.byKey(const ValueKey('floating-navigation-fade')),
      findsOneWidget,
    );
    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(82));

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));
    glassScaffold = tester.widget(find.byType(LiquidGlassScaffold));
    final compact =
        (glassScaffold.bottomNavigationBar as LiquidGlassBottomNavBar).width;

    expect(compact, lessThan(expanded));

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Row 39'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Row 39')).dy,
      lessThanOrEqualTo(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('primary-liquid-glass-navigation')),
            )
            .dy,
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    glassScaffold = tester.widget(find.byType(LiquidGlassScaffold));
    final expandedAgain =
        (glassScaffold.bottomNavigationBar as LiquidGlassBottomNavBar).width;
    expect(expandedAgain, closeTo(expanded, 0.1));
    expect(tester.takeException(), isNull);
  });
}
