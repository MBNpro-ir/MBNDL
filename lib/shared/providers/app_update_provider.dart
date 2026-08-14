import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/logger/app_logger.dart';
import '../../services/storage/storage_service.dart';
import '../../services/updater/app_update_service.dart';

enum AppUpdateStage {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  ready,
  installing,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    this.stage = AppUpdateStage.idle,
    this.automaticChecks = true,
    this.backgroundDownloads = true,
    this.currentVersion = '',
    this.release,
    this.progress = 0,
    this.packagePath,
    this.message,
  });

  final AppUpdateStage stage;
  final bool automaticChecks;
  final bool backgroundDownloads;
  final String currentVersion;
  final AppRelease? release;
  final double progress;
  final String? packagePath;
  final String? message;

  AppUpdateState copyWith({
    AppUpdateStage? stage,
    bool? automaticChecks,
    bool? backgroundDownloads,
    String? currentVersion,
    AppRelease? release,
    double? progress,
    String? packagePath,
    String? message,
    bool clearRelease = false,
    bool clearPackagePath = false,
    bool clearMessage = false,
  }) {
    return AppUpdateState(
      stage: stage ?? this.stage,
      automaticChecks: automaticChecks ?? this.automaticChecks,
      backgroundDownloads: backgroundDownloads ?? this.backgroundDownloads,
      currentVersion: currentVersion ?? this.currentVersion,
      release: clearRelease ? null : release ?? this.release,
      progress: progress ?? this.progress,
      packagePath: clearPackagePath ? null : packagePath ?? this.packagePath,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  static const _automaticKey = 'app_update_automatic_checks';
  static const _backgroundKey = 'app_update_background_downloads';
  bool _busy = false;

  @override
  AppUpdateState build() => AppUpdateState(
    automaticChecks:
        StorageService.instance.getBool(_automaticKey, defaultValue: true) ??
        true,
    backgroundDownloads:
        StorageService.instance.getBool(_backgroundKey, defaultValue: true) ??
        true,
  );

  Future<void> setAutomaticChecks(bool enabled) async {
    state = state.copyWith(automaticChecks: enabled);
    await StorageService.instance.setBool(_automaticKey, enabled);
  }

  Future<void> setBackgroundDownloads(bool enabled) async {
    state = state.copyWith(backgroundDownloads: enabled);
    await StorageService.instance.setBool(_backgroundKey, enabled);
  }

  Future<void> startAutomaticCheck() async {
    if (!state.automaticChecks || _busy) return;
    await checkForUpdates(downloadWhenAvailable: state.backgroundDownloads);
  }

  Future<void> checkForUpdates({bool downloadWhenAvailable = false}) async {
    if (_busy || (!Platform.isWindows && !Platform.isAndroid)) return;
    _busy = true;
    state = state.copyWith(stage: AppUpdateStage.checking, clearMessage: true);
    try {
      final current = await AppUpdateService.instance.currentVersion();
      final release = await AppUpdateService.instance.checkForUpdate();
      if (release == null) {
        state = state.copyWith(
          stage: AppUpdateStage.upToDate,
          currentVersion: current,
          clearRelease: true,
          clearPackagePath: true,
          progress: 0,
        );
        return;
      }
      state = state.copyWith(
        stage: AppUpdateStage.available,
        currentVersion: current,
        release: release,
        clearPackagePath: true,
        progress: 0,
      );
      if (downloadWhenAvailable) await _downloadRelease(release);
    } catch (error, stackTrace) {
      AppLogger.error('Application update check failed', error, stackTrace);
      state = state.copyWith(
        stage: AppUpdateStage.error,
        message: _friendlyError(error),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> downloadUpdate() async {
    if (_busy) return;
    final release = state.release;
    if (release == null) {
      await checkForUpdates(downloadWhenAvailable: true);
      return;
    }
    _busy = true;
    try {
      await _downloadRelease(release);
    } finally {
      _busy = false;
    }
  }

  Future<void> _downloadRelease(AppRelease release) async {
    state = state.copyWith(
      stage: AppUpdateStage.downloading,
      progress: 0,
      clearMessage: true,
    );
    try {
      final file = await AppUpdateService.instance.download(
        release,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        stage: AppUpdateStage.ready,
        progress: 1,
        packagePath: file.path,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Application update download failed', error, stackTrace);
      state = state.copyWith(
        stage: AppUpdateStage.error,
        message: _friendlyError(error),
      );
    }
  }

  Future<bool> installUpdate() async {
    final path = state.packagePath;
    if (path == null) return false;
    state = state.copyWith(stage: AppUpdateStage.installing);
    try {
      final started = await AppUpdateService.instance.install(File(path));
      if (!started) {
        state = state.copyWith(
          stage: AppUpdateStage.ready,
          message:
              'Allow MBNDL to install apps, then return to continue installation.',
        );
      } else if (Platform.isAndroid) {
        state = state.copyWith(
          stage: AppUpdateStage.ready,
          message:
              'Android’s installer was opened. Tap Install again if you cancelled it.',
        );
      }
      return started;
    } catch (error, stackTrace) {
      AppLogger.error('Application update install failed', error, stackTrace);
      state = state.copyWith(
        stage: AppUpdateStage.error,
        message: _friendlyError(error),
      );
      return false;
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('INSTALL_PERMISSION_REQUIRED')) {
      return 'Android needs permission to install updates from MBNDL.';
    }
    if (text.contains('SocketException') ||
        text.contains('HttpException') ||
        text.contains('TimeoutException')) {
      return 'Could not reach GitHub. Check the connection and try again.';
    }
    if (text.contains('integrity')) {
      return 'The update was incomplete or corrupted. Download it again.';
    }
    return 'The update could not be prepared. Try again from Settings.';
  }
}
