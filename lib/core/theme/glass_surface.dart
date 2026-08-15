import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_appearance.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding,
    this.fallbackColor,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appearance = Theme.of(context).extension<AppSurfaceTheme>()?.settings;
    final settings = appearance ?? const AppAppearanceSettings();
    if (!settings.liquidGlassEnabled) {
      return Material(
        color: fallbackColor ?? colors.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        borderRadius: borderRadius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }

    final effectiveBlur = switch (settings.glassQuality) {
      GlassQuality.efficient => settings.glassBlur.clamp(4, 10),
      GlassQuality.balanced => settings.glassBlur,
      GlassQuality.vivid => (settings.glassBlur * 1.25).clamp(6, 32),
      GlassQuality.adaptive =>
        Platform.isAndroid
            ? (settings.glassBlur * 0.72).clamp(4, 18)
            : settings.glassBlur,
    };
    final tintAlpha = settings.glassOpacity.clamp(0.18, 0.92);
    final vibrancy = settings.glassVibrancy.clamp(0, 1);
    final refraction = settings.glassRefraction.clamp(0, 1);
    final borderColor = Color.alphaBlend(
      colors.primary.withValues(
        alpha: 0.12 + vibrancy * 0.14 + refraction * 0.16,
      ),
      colors.outlineVariant.withValues(alpha: 0.46),
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            if (settings.depthEffect)
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            if (settings.chromaticAberration)
              BoxShadow(
                color: colors.tertiary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(-2, 1),
              ),
            if (settings.chromaticAberration)
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(2, -1),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur.toDouble(),
              sigmaY: effectiveBlur.toDouble(),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: borderColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceContainerHigh.withValues(
                      alpha: (tintAlpha + 0.05 + refraction * 0.08).clamp(0, 1),
                    ),
                    Color.alphaBlend(
                      colors.primary.withValues(
                        alpha: vibrancy * 0.10 + refraction * 0.04,
                      ),
                      colors.surfaceContainer.withValues(alpha: tintAlpha),
                    ),
                    colors.surfaceContainerLow.withValues(
                      alpha: (tintAlpha - 0.08 - refraction * 0.04).clamp(
                        0.08,
                        1,
                      ),
                    ),
                  ],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = Theme.of(context).extension<AppSurfaceTheme>()?.settings;
    if (settings?.liquidGlassEnabled != true) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.9),
          radius: 1.45,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.44),
            colors.tertiaryContainer.withValues(alpha: 0.18),
            colors.surface,
          ],
          stops: const [0, 0.46, 1],
        ),
      ),
      child: child,
    );
  }
}
