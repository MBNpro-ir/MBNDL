import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/core/notifications/app_notification.dart';
import 'package:mbn_downloader/core/theme/app_appearance.dart';

void main() {
  testWidgets('notification stays above floating navigation clearance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    const appearance = AppAppearanceSettings(
      surfaceStyle: AppSurfaceStyle.liquidGlass,
      floatingNavigation: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppSurfaceTheme(appearance)]),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => AppNotificationCenter.show(
                  context,
                  kind: AppNotificationKind.update,
                  title: 'Update ready',
                  message: 'Open update settings to install it.',
                  actionLabel: 'Open update settings',
                  onTap: () => opened = true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('app-notification-surface'));
    expect(surface, findsOneWidget);
    expect(tester.getBottomRight(surface).dy, lessThan(720));

    await tester.tap(find.text('Open update settings'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(surface, findsNothing);
  });
}
