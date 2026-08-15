import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_appearance.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
import '../../services/logger/app_logger.dart';
import '../../services/storage/settings_storage_service.dart';
import '../../services/storage/storage_service.dart';
import '../models/delete_preference.dart';
import '../models/windows_close_behavior.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final value = StorageService.instance.getString(
      'theme_mode',
      defaultValue: 'system',
    );
    return AppThemeMode.fromString(value ?? 'system');
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await StorageService.instance.setString(
      'theme_mode',
      mode.toStorageString(),
    );
  }
}

final themeColorProvider = NotifierProvider<ThemeColorNotifier, AppThemeColor>(
  ThemeColorNotifier.new,
);

class ThemeColorNotifier extends Notifier<AppThemeColor> {
  @override
  AppThemeColor build() {
    final index =
        StorageService.instance.getInt(
          'theme_color',
          defaultValue: AppThemeColor.materialYou.index,
        ) ??
        AppThemeColor.materialYou.index;
    return AppThemeColor.values.elementAtOrNull(index) ??
        AppThemeColor.materialYou;
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    state = color;
    await StorageService.instance.setInt('theme_color', color.index);
  }
}

final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppAppearanceSettings>(
      AppearanceSettingsNotifier.new,
    );

class AppearanceSettingsNotifier extends Notifier<AppAppearanceSettings> {
  @override
  AppAppearanceSettings build() {
    final storage = StorageService.instance;
    final legacyEnabled =
        storage.getBool('liquid_glass_enabled', defaultValue: false) ?? false;
    final styleIndex = storage.getInt(
      'surface_style',
      defaultValue: legacyEnabled
          ? AppSurfaceStyle.liquidGlass.index
          : AppSurfaceStyle.expressive.index,
    );
    return AppAppearanceSettings(
      surfaceStyle:
          AppSurfaceStyle.values.elementAtOrNull(styleIndex ?? 0) ??
          AppSurfaceStyle.expressive,
      glassQuality:
          GlassQuality.values.elementAtOrNull(
            storage.getInt(
                  'glass_quality',
                  defaultValue: GlassQuality.adaptive.index,
                ) ??
                GlassQuality.adaptive.index,
          ) ??
          GlassQuality.adaptive,
      glassBlur: storage.getDouble('glass_blur', defaultValue: 18) ?? 18,
      glassOpacity:
          storage.getDouble('glass_opacity', defaultValue: 0.64) ?? 0.64,
      glassVibrancy:
          storage.getDouble('glass_vibrancy', defaultValue: 0.55) ?? 0.55,
      glassRefraction:
          storage.getDouble('glass_refraction', defaultValue: 0.42) ?? 0.42,
      chromaticAberration:
          storage.getBool('glass_chromatic_aberration', defaultValue: true) ??
          true,
      depthEffect:
          storage.getBool('glass_depth_effect', defaultValue: true) ?? true,
      floatingNavigation:
          storage.getBool('floating_navigation', defaultValue: true) ?? true,
      motionMode:
          AppMotionMode.values.elementAtOrNull(
            storage.getInt(
                  'motion_mode',
                  defaultValue: AppMotionMode.system.index,
                ) ??
                AppMotionMode.system.index,
          ) ??
          AppMotionMode.system,
    );
  }

  Future<void> update(AppAppearanceSettings value) async {
    state = value;
    final storage = StorageService.instance;
    await Future.wait([
      storage.setInt('surface_style', value.surfaceStyle.index),
      storage.setBool('liquid_glass_enabled', value.liquidGlassEnabled),
      storage.setInt('glass_quality', value.glassQuality.index),
      storage.setDouble('glass_blur', value.glassBlur),
      storage.setDouble('glass_opacity', value.glassOpacity),
      storage.setDouble('glass_vibrancy', value.glassVibrancy),
      storage.setDouble('glass_refraction', value.glassRefraction),
      storage.setBool('glass_chromatic_aberration', value.chromaticAberration),
      storage.setBool('glass_depth_effect', value.depthEffect),
      storage.setBool('floating_navigation', value.floatingNavigation),
      storage.setInt('motion_mode', value.motionMode.index),
    ]);
  }
}

final logLevelProvider = NotifierProvider<LogLevelNotifier, LogLevel>(
  LogLevelNotifier.new,
);

class LogLevelNotifier extends Notifier<LogLevel> {
  @override
  LogLevel build() {
    final fallback = kDebugMode ? LogLevel.trace : LogLevel.warning;
    final index =
        StorageService.instance.getInt(
          'log_level',
          defaultValue: fallback.index,
        ) ??
        fallback.index;
    final level = LogLevel.values.elementAtOrNull(index) ?? fallback;
    AppLogger.setLogLevel(level);
    return level;
  }

  Future<void> setLogLevel(LogLevel level) async {
    state = level;
    AppLogger.setLogLevel(level);
    await StorageService.instance.setInt('log_level', level.index);
  }
}

final ytDlpSettingsProvider =
    NotifierProvider<YtDlpSettingsNotifier, YtDlpSettings>(
      YtDlpSettingsNotifier.new,
    );

class YtDlpSettingsNotifier extends Notifier<YtDlpSettings> {
  @override
  YtDlpSettings build() {
    Future<void>.microtask(_loadSettings);
    return const YtDlpSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final document = await SettingsStorageService.instance.loadSettings();
      final raw = document?['ytdlp_settings'];
      if (raw is! Map) return;

      var loaded = YtDlpSettings.fromJson(
        Map<String, dynamic>.from(raw),
      ).normalizedForAppPolicy();
      if (Platform.isAndroid &&
          loaded.downloadPath.isNotEmpty &&
          !loaded.downloadPath.contains('/Android/data/com.mbn.dl/') &&
          !loaded.downloadPath.contains('/Android/data/com.mbn.downloader/')) {
        loaded = loaded.copyWith(downloadPath: '');
      }
      state = loaded;
      AppLogger.info(
        'Loaded yt-dlp settings from '
        '${SettingsStorageService.instance.getSettingsFilePath()}',
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load yt-dlp settings', error, stackTrace);
    }
  }

  Future<void> updateSettings(YtDlpSettings settings) async {
    var normalized = settings.normalizedForAppPolicy();
    if (!Platform.isAndroid && normalized.useAria2c) {
      normalized = normalized.copyWith(useAria2c: false);
    }
    state = normalized;
    try {
      final document = Map<String, dynamic>.from(
        await SettingsStorageService.instance.loadSettings() ?? const {},
      );
      document['ytdlp_settings'] = normalized.toJson();
      final saved = await SettingsStorageService.instance.saveSettings(
        document,
      );
      if (!saved) AppLogger.error('Failed to save yt-dlp settings');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save yt-dlp settings', error, stackTrace);
    }
  }

  Future<void> loadPreset(String name) async {
    final preset = switch (name) {
      'speed' => YtDlpSettings.speedPreset(),
      'resilient' => YtDlpSettings.resilientPreset(),
      'gentle_youtube' => YtDlpSettings.gentleYouTubePreset(),
      'limited_bandwidth' => YtDlpSettings.limitedBandwidthPreset(),
      _ => YtDlpSettings.defaultPreset(),
    };
    await applyTransportPreset(name: name, preset: preset);
  }

  Future<void> applyTransportPreset({
    required String name,
    required YtDlpSettings preset,
  }) async {
    // Presets tune transport behavior only. They must never erase the user's
    // download location, engine channel, caption defaults, or advanced choices.
    await updateSettings(
      state.copyWith(
        preset: name,
        concurrentFragments: preset.concurrentFragments,
        retries: preset.retries,
        fragmentRetries: preset.fragmentRetries,
        fileAccessRetries: preset.fileAccessRetries,
        extractorRetries: preset.extractorRetries,
        rateLimit: preset.rateLimit,
        throttledRate: preset.throttledRate,
        useAria2c: preset.useAria2c,
        bufferSize: preset.bufferSize,
        httpChunkSize: preset.httpChunkSize,
        socketTimeout: preset.socketTimeout,
        minSleepInterval: preset.minSleepInterval,
        maxSleepInterval: preset.maxSleepInterval,
        retrySleep: preset.retrySleep,
        sleepRequests: preset.sleepRequests,
      ),
    );
  }
}

final deletePreferenceProvider =
    NotifierProvider<DeletePreferenceNotifier, DeletePreference>(
      DeletePreferenceNotifier.new,
    );

class DeletePreferenceNotifier extends Notifier<DeletePreference> {
  @override
  DeletePreference build() {
    final index =
        StorageService.instance.getInt(
          'delete_preference',
          defaultValue: DeletePreference.ask.index,
        ) ??
        DeletePreference.ask.index;
    return DeletePreference.values.elementAtOrNull(index) ??
        DeletePreference.ask;
  }

  Future<void> setPreference(DeletePreference preference) async {
    state = preference;
    await StorageService.instance.setInt('delete_preference', preference.index);
  }
}

final windowsCloseBehaviorProvider =
    NotifierProvider<WindowsCloseBehaviorNotifier, WindowsCloseBehavior>(
      WindowsCloseBehaviorNotifier.new,
    );

class WindowsCloseBehaviorNotifier extends Notifier<WindowsCloseBehavior> {
  static const _storageKey = 'windows_close_behavior';

  @override
  WindowsCloseBehavior build() {
    final index =
        StorageService.instance.getInt(
          _storageKey,
          defaultValue: WindowsCloseBehavior.ask.index,
        ) ??
        WindowsCloseBehavior.ask.index;
    return WindowsCloseBehavior.values.elementAtOrNull(index) ??
        WindowsCloseBehavior.ask;
  }

  Future<void> setBehavior(WindowsCloseBehavior behavior) async {
    state = behavior;
    await StorageService.instance.setInt(_storageKey, behavior.index);
  }
}
