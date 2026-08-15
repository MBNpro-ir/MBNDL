import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_appearance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_mode.dart';
import '../../../core/utils/floating_navigation_insets.dart';
import '../../../shared/providers/settings_provider.dart';
import '../widgets/settings_section.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(appearanceSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              36 + floatingNavigationScrollClearance(context),
            ),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settings.surfaceStyle.displayName,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  settings.liquidGlassEnabled
                                      ? 'Shader refraction on the bottom navigation only'
                                      : 'Material 3 Expressive surfaces and motion',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const [
                            (Icons.home_rounded, 'Home'),
                            (Icons.history_rounded, 'History'),
                            (Icons.tune_rounded, 'Settings'),
                          ])
                            Chip(
                              avatar: Icon(item.$1, size: 18),
                              label: Text(item.$2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SettingsSection(
                title: 'Theme',
                icon: Icons.palette_outlined,
                children: [
                  ListTile(
                    leading: Icon(themeMode.icon),
                    title: const Text('Theme mode'),
                    subtitle: Text(themeMode.displayName),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _selectThemeMode(context, ref, themeMode),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.color_lens_outlined,
                      color: _previewColor(themeColor),
                    ),
                    title: const Text('Color source'),
                    subtitle: Text(AppTheme.getThemeColorName(themeColor)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _selectThemeColor(context, ref, themeColor),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on_rounded),
                    title: const Text('Liquid Glass (Beta)'),
                    subtitle: const Text(
                      'Real-time lensing and optical edges on the bottom bar',
                    ),
                    value: settings.liquidGlassEnabled,
                    onChanged: (enabled) => unawaited(
                      notifier.update(
                        settings.copyWith(
                          surfaceStyle: enabled
                              ? AppSurfaceStyle.liquidGlass
                              : AppSurfaceStyle.expressive,
                          floatingNavigation: enabled
                              ? true
                              : settings.floatingNavigation,
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.space_bar_rounded),
                    title: const Text('Floating navigation'),
                    subtitle: const Text(
                      'Float the bottom bar above content without hiding it',
                    ),
                    value: settings.floatingNavigation,
                    onChanged: (value) => unawaited(
                      notifier.update(
                        settings.copyWith(floatingNavigation: value),
                      ),
                    ),
                  ),
                ],
              ),
              if (settings.liquidGlassEnabled) ...[
                const SizedBox(height: 16),
                SettingsSection(
                  title: 'Glass rendering',
                  icon: Icons.water_drop_outlined,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.speed_rounded),
                      title: const Text('Quality'),
                      subtitle: Text(settings.glassQuality.description),
                      trailing: DropdownButton<GlassQuality>(
                        value: settings.glassQuality,
                        underline: const SizedBox.shrink(),
                        onChanged: (value) {
                          if (value == null) return;
                          unawaited(
                            notifier.update(
                              settings.copyWith(glassQuality: value),
                            ),
                          );
                        },
                        items: [
                          for (final value in GlassQuality.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.palette_outlined,
                        color: _previewColor(themeColor),
                      ),
                      title: const Text('Navigation tint'),
                      subtitle: Text(
                        'Follows ${AppTheme.getThemeColorName(themeColor)} color source',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _selectThemeColor(context, ref, themeColor),
                    ),
                    _GlassSlider(
                      icon: Icons.blur_circular_rounded,
                      title: 'Blur radius',
                      value: settings.glassBlur,
                      min: 4,
                      max: 30,
                      label: '${settings.glassBlur.round()} px',
                      onChanged: (value) => unawaited(
                        notifier.update(settings.copyWith(glassBlur: value)),
                      ),
                    ),
                    _GlassSlider(
                      icon: Icons.opacity_rounded,
                      title: 'Navigation opacity',
                      value: settings.glassOpacity,
                      min: 0.2,
                      max: 0.9,
                      label: '${(settings.glassOpacity * 100).round()}%',
                      onChanged: (value) => unawaited(
                        notifier.update(settings.copyWith(glassOpacity: value)),
                      ),
                    ),
                    _GlassSlider(
                      icon: Icons.tonality_rounded,
                      title: 'Vibrancy',
                      value: settings.glassVibrancy,
                      min: 0,
                      max: 1,
                      label: '${(settings.glassVibrancy * 100).round()}%',
                      onChanged: (value) => unawaited(
                        notifier.update(
                          settings.copyWith(glassVibrancy: value),
                        ),
                      ),
                    ),
                    _GlassSlider(
                      icon: Icons.lens_blur_outlined,
                      title: 'Lens refraction',
                      value: settings.glassRefraction,
                      min: 0,
                      max: 1,
                      label: '${(settings.glassRefraction * 100).round()}%',
                      onChanged: (value) => unawaited(
                        notifier.update(
                          settings.copyWith(glassRefraction: value),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.gradient_rounded),
                      title: const Text('Chromatic edge'),
                      subtitle: const Text('Subtle color separation at edges'),
                      value: settings.chromaticAberration,
                      onChanged: (value) => unawaited(
                        notifier.update(
                          settings.copyWith(chromaticAberration: value),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.layers_outlined),
                      title: const Text('Depth effect'),
                      subtitle: const Text('Light and shadow separation'),
                      value: settings.depthEffect,
                      onChanged: (value) => unawaited(
                        notifier.update(settings.copyWith(depthEffect: value)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card.filled(
                  color: colors.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.battery_saver_outlined,
                      color: colors.onTertiaryContainer,
                    ),
                    title: Text(
                      'The shader runs only on the bottom navigation.',
                      style: TextStyle(color: colors.onTertiaryContainer),
                    ),
                    subtitle: Text(
                      'Adaptive or Efficient quality is recommended on older phones; Windows uses the stable single-lens Skia renderer.',
                      style: TextStyle(
                        color: colors.onTertiaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SettingsSection(
                title: 'Motion',
                icon: Icons.animation_rounded,
                children: [
                  for (final mode in AppMotionMode.values)
                    ListTile(
                      key: ValueKey('motion-mode-${mode.name}'),
                      selected: settings.motionMode == mode,
                      leading: Icon(_motionIcon(mode)),
                      title: Text(mode.displayName),
                      subtitle: Text(_motionDescription(mode)),
                      trailing: settings.motionMode == mode
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey(
                                'motion-mode-${mode.name}-selected',
                              ),
                              color: colors.primary,
                            )
                          : const Icon(Icons.circle_outlined),
                      onTap: () => unawaited(
                        notifier.update(settings.copyWith(motionMode: mode)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    unawaited(notifier.update(const AppAppearanceSettings())),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset appearance'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _motionIcon(AppMotionMode mode) => switch (mode) {
    AppMotionMode.system => Icons.settings_suggest_outlined,
    AppMotionMode.full => Icons.animation_rounded,
    AppMotionMode.reduced => Icons.motion_photos_off_outlined,
  };

  String _motionDescription(AppMotionMode mode) => switch (mode) {
    AppMotionMode.system =>
      'Follow the Android or Windows accessibility preference.',
    AppMotionMode.full => 'Keep page and navigation animations enabled.',
    AppMotionMode.reduced =>
      'Remove page transitions and make navigation changes immediate.',
  };

  Future<void> _selectThemeMode(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final value = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in AppThemeMode.values)
                ListTile(
                  selected: mode == current,
                  leading: Icon(mode.icon),
                  title: Text(mode.displayName),
                  trailing: mode == current
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      await ref.read(themeModeProvider.notifier).setThemeMode(value);
    }
  }

  Future<void> _selectThemeColor(
    BuildContext context,
    WidgetRef ref,
    AppThemeColor current,
  ) async {
    final value = await showModalBottomSheet<AppThemeColor>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in AppThemeColor.values)
                ChoiceChip(
                  selected: color == current,
                  avatar: CircleAvatar(backgroundColor: _previewColor(color)),
                  label: Text(AppTheme.getThemeColorName(color)),
                  onSelected: (_) => Navigator.pop(context, color),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      await ref.read(themeColorProvider.notifier).setThemeColor(value);
    }
  }

  Color _previewColor(AppThemeColor color) => switch (color) {
    AppThemeColor.materialYou => const Color(0xFF87D3DF),
    AppThemeColor.violet => const Color(0xFF7455C6),
    AppThemeColor.blue => const Color(0xFF0067C0),
    AppThemeColor.teal => const Color(0xFF006B66),
    AppThemeColor.green => const Color(0xFF3C6D24),
    AppThemeColor.orange => const Color(0xFF8C5000),
    AppThemeColor.pink => const Color(0xFFA33E69),
    AppThemeColor.red => const Color(0xFFBA1A1A),
    AppThemeColor.indigo => const Color(0xFF4D5BC7),
  };
}

class _GlassSlider extends StatelessWidget {
  const _GlassSlider({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final slider = Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          label: label,
          onChanged: onChanged,
        );
        if (constraints.maxWidth >= 520) {
          return Row(
            children: [
              Icon(icon),
              const SizedBox(width: 16),
              SizedBox(width: 118, child: Text(title)),
              Expanded(child: slider),
              SizedBox(width: 54, child: Text(label, textAlign: TextAlign.end)),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 16),
                Expanded(child: Text(title)),
                Text(label),
              ],
            ),
            Padding(padding: const EdgeInsets.only(left: 24), child: slider),
          ],
        );
      },
    ),
  );
}
