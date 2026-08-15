import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../features/settings/domain/custom_preset.dart';
import '../logger/app_logger.dart';

class PresetsStorageService {
  static PresetsStorageService? _instance;
  static PresetsStorageService get instance {
    _instance ??= PresetsStorageService._();
    return _instance!;
  }

  PresetsStorageService._();

  File? _presetsFile;
  List<CustomPreset> _customPresets = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final appData =
          Platform.environment['APPDATA'] ??
          Platform.environment['HOME'] ??
          (await getApplicationDocumentsDirectory()).path;

      final configDir = Directory(
        '$appData${Platform.pathSeparator}MBNDownloader',
      );
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      _presetsFile = File(
        '${configDir.path}${Platform.pathSeparator}custom_presets.json',
      );
      AppLogger.info('Presets file: ${_presetsFile!.path}');

      // Load custom presets
      await loadPresets();
      _initialized = true;
    } catch (e) {
      AppLogger.error('Failed to initialize presets storage', e);
      rethrow;
    }
  }

  Future<void> loadPresets() async {
    try {
      if (_presetsFile == null) {
        await initialize();
      }

      if (await _presetsFile!.exists()) {
        final contents = await _presetsFile!.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _customPresets = jsonList
            .map((json) => CustomPreset.fromJson(json as Map<String, dynamic>))
            .toList();
        AppLogger.info('Loaded ${_customPresets.length} custom presets');
      } else {
        _customPresets = [];
        AppLogger.info('No custom presets file found');
      }
    } catch (e) {
      AppLogger.error('Failed to load custom presets', e);
      _customPresets = [];
    }
  }

  Future<void> savePresets() async {
    try {
      if (_presetsFile == null) {
        await initialize();
      }

      final jsonList = _customPresets.map((preset) => preset.toJson()).toList();
      final contents = jsonEncode(jsonList);
      await _presetsFile!.writeAsString(contents);
      AppLogger.info('Saved ${_customPresets.length} custom presets');
    } catch (e) {
      AppLogger.error('Failed to save custom presets', e);
      rethrow;
    }
  }

  List<CustomPreset> getAllPresets() {
    // Combine built-in and custom presets
    return [...CustomPreset.builtInPresets(), ..._customPresets];
  }

  List<CustomPreset> getCustomPresets() {
    return List.unmodifiable(_customPresets);
  }

  Future<void> addPreset(CustomPreset preset) async {
    _customPresets.add(preset);
    await savePresets();
    AppLogger.info('Added custom preset: ${preset.name}');
  }

  /// Merge imported presets by stable id and write the file once.
  Future<int> mergePresets(Iterable<CustomPreset> presets) async {
    var changed = 0;
    for (final imported in presets) {
      if (imported.isBuiltIn) continue;
      final index = _customPresets.indexWhere((item) => item.id == imported.id);
      if (index >= 0) {
        _customPresets[index] = imported;
      } else {
        _customPresets.add(imported);
      }
      changed++;
    }
    if (changed > 0) await savePresets();
    AppLogger.info('Merged $changed custom presets');
    return changed;
  }

  Future<void> updatePreset(CustomPreset preset) async {
    final index = _customPresets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      _customPresets[index] = preset;
      await savePresets();
      AppLogger.info('Updated custom preset: ${preset.name}');
    }
  }

  Future<void> deletePreset(String id) async {
    _customPresets.removeWhere((p) => p.id == id);
    await savePresets();
    AppLogger.info('Deleted custom preset: $id');
  }

  CustomPreset? getPresetById(String id) {
    // Check built-in presets first
    try {
      return CustomPreset.builtInPresets().firstWhere((p) => p.id == id);
    } catch (e) {
      // Not found in built-in, check custom
      try {
        return _customPresets.firstWhere((p) => p.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  bool presetNameExists(String name) {
    return getAllPresets().any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
  }

  /// Backup selected presets to a file
  Future<String?> backupPresets(
    List<String> presetIds,
    String destinationPath,
  ) async {
    try {
      final backupFile = File(destinationPath);
      final contents = createBackupJson(presetIds);
      if (contents == null) return null;
      await backupFile.writeAsString(contents);

      AppLogger.info(
        'Backed up ${presetIds.length} presets to: $destinationPath',
      );
      return destinationPath;
    } catch (e) {
      AppLogger.error('Failed to backup presets', e);
      rethrow;
    }
  }

  String? createBackupJson(List<String> presetIds) {
    final presetsToBackup = _customPresets
        .where((preset) => presetIds.contains(preset.id))
        .toList();
    if (presetsToBackup.isEmpty) {
      AppLogger.warning('No presets selected for backup');
      return null;
    }
    return jsonEncode({
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'presets': presetsToBackup.map((preset) => preset.toJson()).toList(),
    });
  }

  /// Backup all custom presets
  Future<String?> backupAllPresets(String destinationPath) async {
    return backupPresets(
      _customPresets.map((p) => p.id).toList(),
      destinationPath,
    );
  }

  /// Restore presets from a backup file
  Future<int> restorePresets(
    String sourcePath, {
    bool replaceExisting = false,
  }) async {
    try {
      final backupFile = File(sourcePath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      final contents = await backupFile.readAsString();
      final backupData = jsonDecode(contents) as Map<String, dynamic>;

      final List<dynamic> presetsList = backupData['presets'] as List<dynamic>;
      final restoredPresets = presetsList
          .map((json) => CustomPreset.fromJson(json as Map<String, dynamic>))
          .toList();

      int restoredCount = 0;
      for (final preset in restoredPresets) {
        final exists = _customPresets.any((p) => p.id == preset.id);

        if (exists && !replaceExisting) {
          // Skip if exists and not replacing
          continue;
        } else if (exists && replaceExisting) {
          // Replace existing
          final index = _customPresets.indexWhere((p) => p.id == preset.id);
          _customPresets[index] = preset;
          restoredCount++;
        } else {
          // Add new
          _customPresets.add(preset);
          restoredCount++;
        }
      }

      await savePresets();
      AppLogger.info('Restored $restoredCount presets from: $sourcePath');
      return restoredCount;
    } catch (e) {
      AppLogger.error('Failed to restore presets', e);
      rethrow;
    }
  }
}
