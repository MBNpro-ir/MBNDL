import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log_entry.dart';
import 'log_level.dart';
import 'log_sanitizer.dart';

export 'log_level.dart';

class AppLogger {
  AppLogger._();

  static const int _maxLogBytes = 2 * 1024 * 1024;
  static File? _logFile;
  static LogLevel _currentLevel = kDebugMode
      ? LogLevel.trace
      : LogLevel.warning;

  static Future<void> initialize() async {
    try {
      final logPath = await _resolveLogPath();
      final logDir = Directory(logPath);
      await logDir.create(recursive: true);
      _logFile = File('$logPath${Platform.pathSeparator}app_log.txt');
      await _rotateIfNeeded();
      _append(
        AppLogEntry(
          timestamp: DateTime.now(),
          message: 'Application started',
          session: true,
        ),
      );
    } catch (error) {
      debugPrint('Failed to initialize logger: $error');
    }
  }

  static Future<String> _resolveLogPath() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw StateError('APPDATA environment variable not found');
      }
      return '$appData${Platform.pathSeparator}MBNDownloader'
          '${Platform.pathSeparator}logs';
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}${Platform.pathSeparator}MBNDownloader'
          '${Platform.pathSeparator}logs';
    }
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}logs';
  }

  static Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    if (await file.length() < _maxLogBytes) return;
    final previous = File('${file.path}.1');
    if (await previous.exists()) await previous.delete();
    await file.rename(previous.path);
    _logFile = File(file.path);
  }

  static void setLogLevel(LogLevel level) => _currentLevel = level;

  static LogLevel get currentLevel => _currentLevel;

  @visibleForTesting
  static bool shouldLog(LogLevel level, {LogLevel? threshold}) {
    return level.index >= (threshold ?? _currentLevel).index;
  }

  static void trace(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.trace, message, error, stackTrace);

  static void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.debug, message, error, stackTrace);

  static void info(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.info, message, error, stackTrace);

  static void warning(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => _write(LogLevel.warning, message, error, stackTrace);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.error, message, error, stackTrace);

  static void fatal(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(LogLevel.fatal, message, error, stackTrace);

  /// Records a line emitted by yt-dlp/FFmpeg at the level declared by that
  /// tool instead of assuming every stderr line is a warning.
  static void toolOutput(
    String tool,
    String line, {
    LogLevel fallback = LogLevel.debug,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _write(
      levelForToolOutput(trimmed, fallback: fallback),
      '$tool: $trimmed',
      null,
      null,
    );
  }

  @visibleForTesting
  static LogLevel levelForToolOutput(
    String line, {
    LogLevel fallback = LogLevel.debug,
  }) {
    final bracketed = RegExp(
      r'^\[(trace|debug|info|warning|warn|error|fatal)\]',
      caseSensitive: false,
    ).firstMatch(line.trimLeft());
    final prefixed =
        bracketed ??
        RegExp(
          r'^(?:\[[^\]]+\]\s*)*(trace|debug|info|warning|warn|error|fatal)\b',
          caseSensitive: false,
        ).firstMatch(line.trimLeft());
    final name = prefixed?.group(1)?.toLowerCase();
    return switch (name) {
      'trace' => LogLevel.trace,
      'debug' => LogLevel.debug,
      'info' => LogLevel.info,
      'warning' || 'warn' => LogLevel.warning,
      'error' => LogLevel.error,
      'fatal' => LogLevel.fatal,
      _ => fallback,
    };
  }

  static void _write(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (!shouldLog(level)) return;
    _append(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: LogSanitizer.text(message.trim()),
        error: error == null
            ? null
            : LogSanitizer.text(error.toString().trim()),
        stackTrace: stackTrace == null
            ? null
            : LogSanitizer.text(stackTrace.toString().trim()),
      ),
    );
  }

  static void _append(AppLogEntry entry) {
    final file = _logFile;
    if (file == null) return;
    try {
      file.writeAsStringSync('${entry.toLine()}\n', mode: FileMode.append);
    } catch (error) {
      debugPrint('Failed to write to log file: $error');
    }
  }

  static Future<String?> getLogFilePath() async => _logFile?.path;

  static Future<String> getLogContent() async {
    final file = _logFile;
    if (file != null && await file.exists()) return file.readAsString();
    return '';
  }

  static Future<List<AppLogEntry>> getLogEntries() async =>
      AppLogEntry.parseContent(await getLogContent());

  static Future<void> clear() async {
    final file = _logFile;
    if (file == null) return;
    await file.writeAsString('');
    _append(
      AppLogEntry(
        timestamp: DateTime.now(),
        message: 'Logs cleared',
        session: true,
      ),
    );
  }
}
