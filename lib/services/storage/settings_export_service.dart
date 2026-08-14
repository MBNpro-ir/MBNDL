import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../logger/app_logger.dart';
import 'settings_storage_service.dart';
import 'presets_storage_service.dart';
import '../../features/settings/domain/custom_preset.dart';

class SettingsExportService {
  static SettingsExportService? _instance;
  static SettingsExportService get instance {
    _instance ??= SettingsExportService._();
    return _instance!;
  }

  SettingsExportService._();

  /// Export all settings to JSON file
  Future<String?> exportSettings() async {
    try {
      final settings = await SettingsStorageService.instance.getAllSettings();
      final customPresets = PresetsStorageService.instance.getCustomPresets();

      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'settings': settings,
        'customPresets': customPresets.map((p) => p.toJson()).toList(),
      };

      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      String? outputPath;

      if (Platform.isAndroid) {
        // For Android, use a temporary file and share it
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}mbn_settings_export.json',
        );
        await file.writeAsString(jsonString);
        outputPath = file.path;

        // Share the file
        // ignore: deprecated_member_use
        final result = await Share.shareXFiles([XFile(file.path)]);
        if (result.status == ShareResultStatus.success) {
          AppLogger.info('Settings file shared successfully');
        }
      } else {
        // For desktop, let user choose location
        final result = await FilePicker.saveFile(
          dialogTitle: 'Export Settings',
          fileName:
              'mbn_settings_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(utf8.encode(jsonString)),
        );

        if (result != null) {
          outputPath = result;
        }
      }

      if (outputPath != null) {
        AppLogger.info('Settings exported to: $outputPath');
      }

      return outputPath;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to export settings', e, stackTrace);
      rethrow;
    }
  }

  /// Export logs to text file
  Future<String?> exportLogs() async {
    try {
      String appData;
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use app-specific directory
        appData = (await getApplicationDocumentsDirectory()).path;
      } else {
        // For desktop platforms
        appData =
            Platform.environment['APPDATA'] ??
            Platform.environment['HOME'] ??
            (await getApplicationDocumentsDirectory()).path;
      }

      final logFile = File(
        '$appData${Platform.pathSeparator}MBNDownloader${Platform.pathSeparator}logs${Platform.pathSeparator}app_log.txt',
      );

      if (!await logFile.exists()) {
        throw Exception('Log file not found');
      }

      final logContent = await logFile.readAsString();

      String? outputPath;

      if (Platform.isAndroid) {
        // For Android, share the log file
        final tempDir = await getTemporaryDirectory();
        final tempLogFile = File(
          '${tempDir.path}${Platform.pathSeparator}mbn_logs_export.txt',
        );
        await tempLogFile.writeAsString(logContent);
        outputPath = tempLogFile.path;

        // ignore: deprecated_member_use
        final result = await Share.shareXFiles([XFile(tempLogFile.path)]);
        if (result.status == ShareResultStatus.success) {
          AppLogger.info('Log file shared successfully');
        }
      } else {
        // For desktop, let user choose location
        final result = await FilePicker.saveFile(
          dialogTitle: 'Export Logs',
          fileName: 'mbn_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
          type: FileType.custom,
          allowedExtensions: ['txt'],
          bytes: Uint8List.fromList(utf8.encode(logContent)),
        );

        if (result != null) {
          outputPath = result;
        }
      }

      if (outputPath != null) {
        AppLogger.info('Logs exported to: $outputPath');
      }

      return outputPath;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to export logs', e, stackTrace);
      rethrow;
    }
  }

  /// Open config folder in file explorer
  Future<void> openConfigFolder() async {
    try {
      String appData;
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use app-specific directory
        appData = (await getApplicationDocumentsDirectory()).path;
      } else {
        // For desktop platforms
        appData =
            Platform.environment['APPDATA'] ??
            Platform.environment['HOME'] ??
            (await getApplicationDocumentsDirectory()).path;
      }

      final configDir = Directory(
        '$appData${Platform.pathSeparator}MBNDownloader',
      );

      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      if (Platform.isWindows) {
        await Process.run('explorer', [configDir.path]);
        AppLogger.info('Opened config folder: ${configDir.path}');
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [configDir.path]);
        AppLogger.info('Opened config folder: ${configDir.path}');
      } else if (Platform.isMacOS) {
        await Process.run('open', [configDir.path]);
        AppLogger.info('Opened config folder: ${configDir.path}');
      } else if (Platform.isAndroid || Platform.isIOS) {
        // On Android/iOS, we can't directly open folder
        // The path will be returned to the caller for display
        AppLogger.info('Config folder path: ${configDir.path}');
        throw UnsupportedError(
          'Cannot open folders directly on mobile platforms. Path: ${configDir.path}',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to open config folder', e, stackTrace);
      rethrow;
    }
  }

  /// Import settings from JSON file
  Future<bool> importSettings() async {
    try {
      FilePickerResult? result;

      if (Platform.isAndroid) {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          dialogTitle: 'Import Settings',
        );
      } else {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          dialogTitle: 'Import Settings',
        );
      }

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Import settings
      if (data['settings'] != null) {
        final settings = data['settings'] as Map<String, dynamic>;
        await SettingsStorageService.instance.saveAllSettings(settings);
      }

      // Import custom presets
      if (data['customPresets'] != null) {
        final presetsList = data['customPresets'] as List<dynamic>;
        for (final presetJson in presetsList) {
          final preset = CustomPreset.fromJson(
            presetJson as Map<String, dynamic>,
          );
          await PresetsStorageService.instance.addPreset(preset);
        }
      }

      AppLogger.info('Settings imported successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to import settings', e, stackTrace);
      rethrow;
    }
  }
}
