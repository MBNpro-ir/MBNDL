import 'package:flutter/material.dart';

enum AppSurfaceStyle {
  expressive('Material Expressive'),
  liquidGlass('Liquid Glass (Beta)');

  const AppSurfaceStyle(this.displayName);
  final String displayName;
}

enum AppMotionMode {
  system('Follow system'),
  full('Full motion'),
  reduced('Reduced motion');

  const AppMotionMode(this.displayName);
  final String displayName;
}

@immutable
class AppAppearanceSettings {
  const AppAppearanceSettings({
    this.surfaceStyle = AppSurfaceStyle.expressive,
    this.glassBlur = 4,
    this.glassOpacity = 0.20,
    this.glassVibrancy = 1,
    this.glassRefraction = 0,
    this.chromaticAberration = true,
    this.depthEffect = false,
    this.floatingNavigation = true,
    this.motionMode = AppMotionMode.system,
  });

  final AppSurfaceStyle surfaceStyle;
  final double glassBlur;
  final double glassOpacity;
  final double glassVibrancy;
  final double glassRefraction;
  final bool chromaticAberration;
  final bool depthEffect;
  final bool floatingNavigation;
  final AppMotionMode motionMode;

  bool get liquidGlassEnabled => surfaceStyle == AppSurfaceStyle.liquidGlass;

  AppAppearanceSettings copyWith({
    AppSurfaceStyle? surfaceStyle,
    double? glassBlur,
    double? glassOpacity,
    double? glassVibrancy,
    double? glassRefraction,
    bool? chromaticAberration,
    bool? depthEffect,
    bool? floatingNavigation,
    AppMotionMode? motionMode,
  }) => AppAppearanceSettings(
    surfaceStyle: surfaceStyle ?? this.surfaceStyle,
    glassBlur: glassBlur ?? this.glassBlur,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassVibrancy: glassVibrancy ?? this.glassVibrancy,
    glassRefraction: glassRefraction ?? this.glassRefraction,
    chromaticAberration: chromaticAberration ?? this.chromaticAberration,
    depthEffect: depthEffect ?? this.depthEffect,
    floatingNavigation: floatingNavigation ?? this.floatingNavigation,
    motionMode: motionMode ?? this.motionMode,
  );

  AppAppearanceSettings enableLiquidGlass() => copyWith(
    surfaceStyle: AppSurfaceStyle.liquidGlass,
    floatingNavigation: true,
    glassBlur: 4,
    glassOpacity: 0.20,
    glassVibrancy: 1,
    glassRefraction: 0,
    chromaticAberration: true,
    depthEffect: false,
  );
}

@immutable
class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  const AppSurfaceTheme(this.settings);

  final AppAppearanceSettings settings;

  @override
  AppSurfaceTheme copyWith({AppAppearanceSettings? settings}) =>
      AppSurfaceTheme(settings ?? this.settings);

  @override
  AppSurfaceTheme lerp(covariant AppSurfaceTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
