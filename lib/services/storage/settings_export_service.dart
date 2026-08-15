import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/settings/domain/custom_preset.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
import '../logger/app_logger.dart';
import 'presets_storage_service.dart';
import 'settings_storage_service.dart';
import 'storage_service.dart';

class SettingsImportResult {
  const SettingsImportResult({
    required this.schemaVersion,
    required this.preferenceCount,
    required this.presetCount,
  });

  final int schemaVersion;
  final int preferenceCount;
  final int presetCount;
}

class SettingsExportService {
  SettingsExportService._();

  static final SettingsExportService instance = SettingsExportService._();
  static const int currentSchemaVersion = 2;

  /// Only portable, non-secret values belong in a settings backup. YouTube
  /// cookies, download history and onboarding state intentionally stay local.
  static const portablePreferenceKeys = <String>{
    'theme_mode',
    'theme_color',
    'log_level',
    'delete_preference',
    'windows_close_behavior',
    'app_update_automatic_checks',
    'app_update_background_downloads',
    'surface_style',
    'liquid_glass_enabled',
    'glass_quality',
    'glass_blur',
    'glass_opacity',
    'glass_vibrancy',
    'glass_refraction',
    'glass_chromatic_aberration',
    'glass_depth_effect',
    'floating_navigation',
    'motion_mode',
  };

  Future<String?> exportSettings() async {
    try {
      await PresetsStorageService.instance.initialize();
      final package = await PackageInfo.fromPlatform();
      final settings = _settingsForExport(
        await SettingsStorageService.instance.getAllSettings(),
      );
      final preferences = StorageService.instance.exportValues(
        portablePreferenceKeys,
      );
      final customPresets = PresetsStorageService.instance.getCustomPresets();
      final exportData = <String, dynamic>{
        'schemaVersion': currentSchemaVersion,
        'app': 'MBNDL',
        'appVersion': package.version,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': settings,
        'preferences': preferences,
        'customPresets': customPresets
            .map((preset) => preset.toJson())
            .toList(),
        'excluded': const [
          'YouTube account cookies',
          'proxy credentials',
          'download history',
          'device permissions',
          'device-specific paths and custom command arguments',
        ],
      };
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );

      String? outputPath;
      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}'
          'mbndl-settings-v$currentSchemaVersion-$timestamp.json',
        );
        await file.writeAsString(jsonString, flush: true);
        outputPath = file.path;
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'application/json'),
        ], subject: 'MBNDL settings backup');
      } else {
        outputPath = await FilePicker.saveFile(
          dialogTitle: 'Export MBNDL settings',
          fileName: 'mbndl-settings-v$currentSchemaVersion-$timestamp.json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: Uint8List.fromList(utf8.encode(jsonString)),
        );
      }

      if (outputPath != null) {
        AppLogger.info('Settings backup exported', outputPath);
      }
      return outputPath;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to export settings', error, stackTrace);
      rethrow;
    }
  }

  Future<SettingsImportResult?> importSettings() async {
    try {
      await PresetsStorageService.instance.initialize();
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: 'Import MBNDL settings',
      );
      if (picked == null || picked.files.isEmpty) return null;

      final selected = picked.files.single;
      final jsonString = utf8.decode(await selected.readAsBytes());
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        throw const FormatException('Backup root must be a JSON object');
      }
      final data = Map<String, dynamic>.from(decoded);
      final schemaVersion = _readSchemaVersion(data);
      if (schemaVersion > currentSchemaVersion) {
        throw FormatException(
          'This backup uses schema $schemaVersion, but this version of MBNDL '
          'supports up to schema $currentSchemaVersion.',
        );
      }

      final settings = _validatedSettings(data['settings']);
      final preferences = _validatedMap(data['preferences']);
      final presets = _validatedPresets(data['customPresets']);

      // Everything is parsed and validated before the first write so a broken
      // backup cannot leave half of the application restored.
      await SettingsStorageService.instance.saveAllSettings(settings);
      await StorageService.instance.importValues(
        preferences,
        allowedKeys: portablePreferenceKeys,
      );
      final presetCount = await PresetsStorageService.instance.mergePresets(
        presets,
      );

      final importedLevel = preferences['log_level'];
      if (importedLevel is int) {
        final level = LogLevel.values.elementAtOrNull(importedLevel);
        if (level != null) AppLogger.setLogLevel(level);
      }
      AppLogger.info(
        'Settings backup imported (schema $schemaVersion, '
        '${preferences.length} preferences, $presetCount presets)',
      );
      return SettingsImportResult(
        schemaVersion: schemaVersion,
        preferenceCount: preferences.length,
        presetCount: presetCount,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to import settings', error, stackTrace);
      rethrow;
    }
  }

  int _readSchemaVersion(Map<String, dynamic> data) {
    final modern = data['schemaVersion'];
    if (modern is int && modern > 0) return modern;
    // v1.0 backups used a string `version` and contained only yt-dlp settings
    // and presets.
    if (data['version'] != null) return 1;
    throw const FormatException('This is not an MBNDL settings backup');
  }

  Map<String, dynamic> _validatedSettings(Object? value) {
    final settings = _validatedMap(value);
    final rawYtDlp = settings['ytdlp_settings'];
    if (rawYtDlp == null) return settings;
    if (rawYtDlp is! Map) {
      throw const FormatException('ytdlp_settings must be a JSON object');
    }
    var parsed = YtDlpSettings.fromJson(
      Map<String, dynamic>.from(rawYtDlp),
    ).normalizedForAppPolicy();
    final path = parsed.downloadPath;
    final androidStyle =
        path.contains('/Android/') || path.startsWith('/storage/');
    final windowsStyle = RegExp(r'^(?:[a-zA-Z]:\\|\\\\)').hasMatch(path);
    if ((Platform.isAndroid && path.isNotEmpty) ||
        (Platform.isWindows && androidStyle) ||
        (!Platform.isWindows && !Platform.isAndroid && windowsStyle)) {
      parsed = parsed.copyWith(downloadPath: '');
    }
    settings['ytdlp_settings'] = parsed.toJson();
    return settings;
  }

  Map<String, dynamic> _settingsForExport(Map<String, dynamic> raw) {
    final settings = _validatedSettings(raw);
    final value = settings['ytdlp_settings'];
    if (value is! Map) return settings;
    final ytDlp = Map<String, dynamic>.from(value);
    final proxy = ytDlp['proxy']?.toString() ?? '';
    final parsedProxy = Uri.tryParse(
      proxy.contains('://') ? proxy : 'http://$proxy',
    );
    if (proxy.contains('@') || parsedProxy?.userInfo.isNotEmpty == true) {
      ytDlp['proxy'] = '';
    }
    // Paths and free-form arguments can contain local usernames, bearer
    // headers, or secrets and are not portable between devices.
    ytDlp['jsRuntimePath'] = '';
    ytDlp['downloadPath'] = '';
    ytDlp['downloadArchive'] = '';
    ytDlp['cookiesFile'] = '';
    ytDlp['cookiesFromBrowser'] = '';
    ytDlp['customArgs'] = const <String>[];
    settings['ytdlp_settings'] = ytDlp;
    return settings;
  }

  Map<String, dynamic> _validatedMap(Object? value) {
    if (value == null) return <String, dynamic>{};
    if (value is! Map) throw const FormatException('Expected a JSON object');
    return Map<String, dynamic>.from(value);
  }

  List<CustomPreset> _validatedPresets(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('customPresets must be a JSON list');
    }
    return value
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('A custom preset is not a JSON object');
          }
          final parsed = CustomPreset.fromJson(Map<String, dynamic>.from(raw));
          return parsed.copyWith(
            isBuiltIn: false,
            settings: parsed.settings.normalizedForAppPolicy(),
          );
        })
        .toList(growable: false);
  }

  Future<String?> exportLogs() async {
    try {
      final sourcePath = await AppLogger.getLogFilePath();
      if (sourcePath == null || !await File(sourcePath).exists()) {
        throw StateError('Log file not found');
      }
      final content = await File(sourcePath).readAsString();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}mbndl-logs-$timestamp.txt',
        );
        await file.writeAsString(content, flush: true);
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/plain'),
        ], subject: 'MBNDL diagnostics');
        return file.path;
      }
      return FilePicker.saveFile(
        dialogTitle: 'Export MBNDL logs',
        fileName: 'mbndl-logs-$timestamp.txt',
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to export logs', error, stackTrace);
      rethrow;
    }
  }

  Future<void> openConfigFolder() async {
    final String root;
    if (Platform.isWindows) {
      root =
          Platform.environment['APPDATA'] ??
          (await getApplicationDocumentsDirectory()).path;
    } else if (Platform.isAndroid || Platform.isIOS) {
      root = (await getApplicationDocumentsDirectory()).path;
    } else {
      root =
          Platform.environment['HOME'] ??
          (await getApplicationDocumentsDirectory()).path;
    }
    final directory = Directory('$root${Platform.pathSeparator}MBNDownloader');
    await directory.create(recursive: true);

    if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        directory.path,
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [
        directory.path,
      ], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [
        directory.path,
      ], mode: ProcessStartMode.detached);
    } else {
      throw UnsupportedError(
        'Cannot open folders directly on this platform. Path: ${directory.path}',
      );
    }
    AppLogger.info('Opened config folder: ${directory.path}');
  }
}
