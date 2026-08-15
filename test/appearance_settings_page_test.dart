import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/core/theme/app_appearance.dart';
import 'package:mbn_downloader/core/theme/app_theme.dart';
import 'package:mbn_downloader/features/settings/presentation/appearance_settings_page.dart';
import 'package:mbn_downloader/shared/providers/settings_provider.dart';
import 'package:mbn_downloader/services/storage/settings_export_service.dart';
import 'package:mbn_downloader/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('portable backup includes every appearance control', () {
    expect(
      SettingsExportService.portablePreferenceKeys,
      containsAll(const {
        'surface_style',
        'liquid_glass_enabled',
        'glass_blur',
        'glass_opacity',
        'glass_vibrancy',
        'glass_refraction',
        'glass_chromatic_aberration',
        'glass_depth_effect',
        'floating_navigation',
        'motion_mode',
      }),
    );
    expect(
      SettingsExportService.portablePreferenceKeys,
      isNot(contains('permission_onboarding_complete')),
    );
  });

  testWidgets('Liquid Glass controls fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'surface_style': AppSurfaceStyle.liquidGlass.index,
      'liquid_glass_enabled': true,
    });
    await StorageService.initialize();
    const appearance = AppAppearanceSettings(
      surfaceStyle: AppSurfaceStyle.liquidGlass,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme(AppThemeColor.materialYou, appearance),
          home: const AppearanceSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Liquid Glass (Beta)'), findsWidgets);
    expect(find.text('Quality'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Lens refraction'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lens refraction'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Reduced motion'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reduced motion'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearanceSettingsPage)),
    );
    expect(
      container.read(appearanceSettingsProvider).motionMode,
      AppMotionMode.reduced,
    );
    expect(
      find.byKey(const ValueKey('motion-mode-reduced-selected')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('Liquid Glass defaults match the v1.0.7 visual baseline', () {
    final appearance = const AppAppearanceSettings().enableLiquidGlass();
    expect(appearance.glassBlur, 4);
    expect(appearance.glassOpacity, 0.20);
    expect(appearance.glassVibrancy, 1);
    expect(appearance.glassRefraction, 0);
    expect(appearance.chromaticAberration, isTrue);
    expect(appearance.depthEffect, isFalse);
  });
}
