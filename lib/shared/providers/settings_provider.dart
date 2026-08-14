import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_mode.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
import '../../services/logger/app_logger.dart';
import '../../services/storage/settings_storage_service.dart';
import '../../services/storage/storage_service.dart';
import '../models/delete_preference.dart';

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
