import 'package:shared_preferences/shared_preferences.dart';
import '../logger/app_logger.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    AppLogger.info('Storage service initialized');
  }

  // Generic methods
  Future<bool> setBool(String key, bool value) async {
    try {
      final result = await _prefs!.setBool(key, value);
      AppLogger.trace('Saved bool: $key = $value');
      return result;
    } catch (e) {
      AppLogger.error('Failed to save bool: $key', e);
      return false;
    }
  }

  bool? getBool(String key, {bool? defaultValue}) {
    try {
      return _prefs!.getBool(key) ?? defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get bool: $key', e);
      return defaultValue;
    }
  }

  Future<bool> setInt(String key, int value) async {
    try {
      final result = await _prefs!.setInt(key, value);
      AppLogger.trace('Saved int: $key = $value');
      return result;
    } catch (e) {
      AppLogger.error('Failed to save int: $key', e);
      return false;
    }
  }

  int? getInt(String key, {int? defaultValue}) {
    try {
      return _prefs!.getInt(key) ?? defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get int: $key', e);
      return defaultValue;
    }
  }

  Future<bool> setDouble(String key, double value) async {
    try {
      final result = await _prefs!.setDouble(key, value);
      AppLogger.trace('Saved double: $key = $value');
      return result;
    } catch (e) {
      AppLogger.error('Failed to save double: $key', e);
      return false;
    }
  }

  double? getDouble(String key, {double? defaultValue}) {
    try {
      return _prefs!.getDouble(key) ?? defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get double: $key', e);
      return defaultValue;
    }
  }

  Future<bool> setString(String key, String value) async {
    try {
      final result = await _prefs!.setString(key, value);
      AppLogger.trace('Saved string: $key = $value');
      return result;
    } catch (e) {
      AppLogger.error('Failed to save string: $key', e);
      return false;
    }
  }

  String? getString(String key, {String? defaultValue}) {
    try {
      return _prefs!.getString(key) ?? defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get string: $key', e);
      return defaultValue;
    }
  }

  Future<bool> setStringList(String key, List<String> value) async {
    try {
      final result = await _prefs!.setStringList(key, value);
      AppLogger.trace('Saved string list: $key = $value');
      return result;
    } catch (e) {
      AppLogger.error('Failed to save string list: $key', e);
      return false;
    }
  }

  List<String>? getStringList(String key, {List<String>? defaultValue}) {
    try {
      return _prefs!.getStringList(key) ?? defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get string list: $key', e);
      return defaultValue;
    }
  }

  Future<bool> remove(String key) async {
    try {
      final result = await _prefs!.remove(key);
      AppLogger.trace('Removed key: $key');
      return result;
    } catch (e) {
      AppLogger.error('Failed to remove key: $key', e);
      return false;
    }
  }

  Future<bool> clear() async {
    try {
      final result = await _prefs!.clear();
      AppLogger.warning('Cleared all storage');
      return result;
    } catch (e) {
      AppLogger.error('Failed to clear storage', e);
      return false;
    }
  }

  bool containsKey(String key) {
    return _prefs!.containsKey(key);
  }

  Set<String> getKeys() {
    return _prefs!.getKeys();
  }
}
