import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../logger/app_logger.dart';

class SettingsStorageService {
  static SettingsStorageService? _instance;
  static File? _settingsFile;

  SettingsStorageService._();

  static SettingsStorageService get instance {
    _instance ??= SettingsStorageService._();
    return _instance!;
  }

  /// Initialize settings storage - creates settings file in app data directory
  /// Windows: %APPDATA%\MBNDownloader\settings.json
  /// Android: /data/data/com.mbn.dl/files/settings.json
  /// iOS: ~/Library/Application Support/settings.json
  static Future<void> initialize() async {
    try {
      String settingsPath;

      if (Platform.isWindows) {
        // Use APPDATA on Windows (same directory as logs)
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          throw Exception('APPDATA environment variable not found');
        }
        settingsPath = '$appData\\MBNDownloader';
      } else if (Platform.isAndroid) {
        // Use app-specific directory on Android
        final directory = await getApplicationDocumentsDirectory();
        settingsPath = directory.path;
      } else if (Platform.isIOS) {
        // Use Application Support directory on iOS
        final directory = await getApplicationSupportDirectory();
        settingsPath = directory.path;
      } else {
        // Fallback for other platforms
        final directory = await getApplicationDocumentsDirectory();
        settingsPath = directory.path;
      }

      // Create directory if it doesn't exist
      final settingsDir = Directory(settingsPath);
      if (!await settingsDir.exists()) {
        await settingsDir.create(recursive: true);
      }

      // Create settings file
      final separator = Platform.isWindows ? '\\' : '/';
      _settingsFile = File('$settingsPath${separator}settings.json');

      // Create empty settings file if it doesn't exist
      if (!await _settingsFile!.exists()) {
        await _settingsFile!.writeAsString('{}');
        AppLogger.info('Created settings file at: ${_settingsFile!.path}');
      } else {
        AppLogger.debug('Settings file exists at: ${_settingsFile!.path}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize settings storage', e, stackTrace);
      debugPrint('Failed to initialize settings storage: $e');
    }
  }

  /// Save settings as JSON to file
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    if (_settingsFile == null) {
      AppLogger.warning('Settings file not initialized');
      return false;
    }

    try {
      // Convert to pretty-printed JSON for readability
      final jsonString = const JsonEncoder.withIndent('  ').convert(settings);
      await _settingsFile!.writeAsString(jsonString);
      AppLogger.debug('Settings saved successfully to ${_settingsFile!.path}');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save settings', e, stackTrace);
      return false;
    }
  }

  /// Load settings from JSON file
  Future<Map<String, dynamic>?> loadSettings() async {
    if (_settingsFile == null) {
      AppLogger.warning('Settings file not initialized');
      return null;
    }

    try {
      if (!await _settingsFile!.exists()) {
        AppLogger.debug(
          'Settings file does not exist, returning empty settings',
        );
        return {};
      }

      final jsonString = await _settingsFile!.readAsString();
      if (jsonString.isEmpty || jsonString == '{}') {
        AppLogger.debug('Settings file is empty, returning empty settings');
        return {};
      }

      final settings = jsonDecode(jsonString) as Map<String, dynamic>;
      AppLogger.debug(
        'Settings loaded successfully from ${_settingsFile!.path}',
      );
      return settings;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', e, stackTrace);
      return null;
    }
  }

  /// Get settings file path
  String? getSettingsFilePath() {
    return _settingsFile?.path;
  }

  /// Clear all settings (reset to empty)
  Future<bool> clearSettings() async {
    if (_settingsFile == null) {
      AppLogger.warning('Settings file not initialized');
      return false;
    }

    try {
      await _settingsFile!.writeAsString('{}');
      AppLogger.info('Settings cleared successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear settings', e, stackTrace);
      return false;
    }
  }

  /// Check if settings file exists
  Future<bool> settingsFileExists() async {
    if (_settingsFile == null) return false;
    return await _settingsFile!.exists();
  }

  /// Get settings file size in bytes
  Future<int> getSettingsFileSize() async {
    if (_settingsFile == null || !await _settingsFile!.exists()) {
      return 0;
    }
    return await _settingsFile!.length();
  }

  /// Delete settings file
  Future<bool> deleteSettingsFile() async {
    if (_settingsFile == null) {
      AppLogger.warning('Settings file not initialized');
      return false;
    }

    try {
      if (await _settingsFile!.exists()) {
        await _settingsFile!.delete();
        AppLogger.info('Settings file deleted successfully');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete settings file', e, stackTrace);
      return false;
    }
  }

  /// Export settings to a custom path
  Future<bool> exportSettings(String exportPath) async {
    if (_settingsFile == null || !await _settingsFile!.exists()) {
      AppLogger.warning('Settings file not initialized or does not exist');
      return false;
    }

    try {
      final content = await _settingsFile!.readAsString();
      final exportFile = File(exportPath);
      await exportFile.writeAsString(content);
      AppLogger.info('Settings exported to: $exportPath');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to export settings', e, stackTrace);
      return false;
    }
  }

  /// Import settings from a custom path
  Future<bool> importSettings(String importPath) async {
    if (_settingsFile == null) {
      AppLogger.warning('Settings file not initialized');
      return false;
    }

    try {
      final importFile = File(importPath);
      if (!await importFile.exists()) {
        AppLogger.warning('Import file does not exist: $importPath');
        return false;
      }

      final content = await importFile.readAsString();
      // Validate JSON
      jsonDecode(content);

      // Copy to settings file
      await _settingsFile!.writeAsString(content);
      AppLogger.info('Settings imported from: $importPath');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to import settings', e, stackTrace);
      return false;
    }
  }

  /// Get all settings as a map
  Future<Map<String, dynamic>> getAllSettings() async {
    final settings = await loadSettings();
    return settings ?? {};
  }

  /// Save all settings from a map
  Future<void> saveAllSettings(Map<String, dynamic> settings) async {
    await saveSettings(settings);
  }
}
