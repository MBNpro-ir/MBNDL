import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logger/app_logger.dart';

class RequiredPermissionState {
  const RequiredPermissionState({
    required this.sdkInt,
    required this.downloadFolderReady,
    required this.storageRequired,
    required this.storageGranted,
    required this.notificationRequired,
    required this.notificationGranted,
  });

  final int sdkInt;
  final bool downloadFolderReady;
  final bool storageRequired;
  final bool storageGranted;
  final bool notificationRequired;
  final bool notificationGranted;

  bool get allGranted =>
      downloadFolderReady &&
      (!storageRequired || storageGranted) &&
      (!notificationRequired || notificationGranted);
}

/// Requests only permissions that MBNDL actually needs.
///
/// Android 10+ publishes app-created files through MediaStore, so requesting
/// broad "all files" access would add risk without improving downloads.
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();
  static const _channel = MethodChannel('com.mbn.dl/ytdlp');

  int? _sdkInt;

  Future<int> getAndroidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    if (_sdkInt != null) return _sdkInt!;
    _sdkInt = await _channel.invokeMethod<int>('getSdkInt') ?? 0;
    return _sdkInt!;
  }

  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid || await getAndroidSdkInt() >= 29) return true;
    return _hasNativePermission('storage');
  }

  Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid || await getAndroidSdkInt() < 33) return true;
    return _hasNativePermission('notification');
  }

  Future<RequiredPermissionState> getRequiredPermissionState() async {
    if (!Platform.isAndroid) {
      return const RequiredPermissionState(
        sdkInt: 0,
        downloadFolderReady: true,
        storageRequired: false,
        storageGranted: true,
        notificationRequired: false,
        notificationGranted: true,
      );
    }

    final sdk = await getAndroidSdkInt();
    final storageRequired = sdk < 29;
    final notificationRequired = sdk >= 33;
    return RequiredPermissionState(
      sdkInt: sdk,
      downloadFolderReady: true,
      storageRequired: storageRequired,
      storageGranted: !storageRequired || await _hasNativePermission('storage'),
      notificationRequired: notificationRequired,
      notificationGranted:
          !notificationRequired || await _hasNativePermission('notification'),
    );
  }

  Future<bool> hasRequiredPermissions() async {
    return (await getRequiredPermissionState()).allGranted;
  }

  Future<bool> requestAllRequiredPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdk = await getAndroidSdkInt();
    if (sdk < 29 && !await _hasNativePermission('storage')) {
      if (!await _requestNativePermission('storage')) return false;
    }
    if (sdk >= 33 && !await _hasNativePermission('notification')) {
      if (!await _requestNativePermission('notification')) return false;
    }
    return hasRequiredPermissions();
  }

  Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid || await getAndroidSdkInt() >= 29) return true;
    try {
      final granted = await _requestNativePermission('storage');
      if (!granted && context.mounted) showPermissionDeniedSnackbar(context);
      return granted;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to request storage permission',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid || await getAndroidSdkInt() < 33) return true;
    if (await _hasNativePermission('notification')) return true;
    return _requestNativePermission('notification');
  }

  Future<bool> _hasNativePermission(String permission) async {
    return await _channel.invokeMethod<bool>('hasPermission', {
          'permission': permission,
        }) ??
        false;
  }

  Future<bool> _requestNativePermission(String permission) async {
    return await _channel.invokeMethod<bool>('requestPermission', {
          'permission': permission,
        }) ??
        false;
  }

  Future<bool> openApplicationSettings() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  void showPermissionDeniedSnackbar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Required access is still disabled.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openApplicationSettings,
        ),
      ),
    );
  }

  Future<bool> checkAndRequestPermission(BuildContext context) async {
    if (await hasStoragePermission()) return true;
    if (!context.mounted) return false;
    return requestStoragePermission(context);
  }

  Future<Map<String, bool>> getPermissionStatuses() async {
    final state = await getRequiredPermissionState();
    return {
      'Downloads / MBNDL': state.downloadFolderReady,
      if (state.storageRequired) 'Storage': state.storageGranted,
      if (state.notificationRequired)
        'Notifications': state.notificationGranted,
    };
  }

  Future<bool> requestSpecificPermission(String permissionName) async {
    if (!Platform.isAndroid) return true;
    if (permissionName == 'Notifications') {
      return requestNotificationPermission();
    }
    if (permissionName == 'Storage' && await getAndroidSdkInt() < 29) {
      return _requestNativePermission('storage');
    }
    return true;
  }
}
