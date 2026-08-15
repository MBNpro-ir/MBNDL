import 'package:flutter/material.dart';

enum AppSurfaceStyle {
  expressive('Material Expressive'),
  liquidGlass('Liquid Glass (Beta)');

  const AppSurfaceStyle(this.displayName);
  final String displayName;
}

enum GlassQuality {
  adaptive('Adaptive', 'Balances the effect for the current device'),
  efficient('Efficient', 'Less blur and fewer GPU effects'),
  balanced('Balanced', 'Full glass with moderate rendering cost'),
  vivid('Vivid', 'Strongest refraction and depth');

  const GlassQuality(this.displayName, this.description);
  final String displayName;
  final String description;
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
    this.glassQuality = GlassQuality.adaptive,
    this.glassBlur = 18,
    this.glassOpacity = 0.64,
    this.glassVibrancy = 0.55,
    this.glassRefraction = 0.42,
    this.chromaticAberration = true,
    this.depthEffect = true,
    this.floatingNavigation = true,
    this.motionMode = AppMotionMode.system,
  });

  final AppSurfaceStyle surfaceStyle;
  final GlassQuality glassQuality;
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
    GlassQuality? glassQuality,
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
    glassQuality: glassQuality ?? this.glassQuality,
    glassBlur: glassBlur ?? this.glassBlur,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassVibrancy: glassVibrancy ?? this.glassVibrancy,
    glassRefraction: glassRefraction ?? this.glassRefraction,
    chromaticAberration: chromaticAberration ?? this.chromaticAberration,
    depthEffect: depthEffect ?? this.depthEffect,
    floatingNavigation: floatingNavigation ?? this.floatingNavigation,
    motionMode: motionMode ?? this.motionMode,
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
