import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { trace, debug, info, warning, error, fatal }

class AppLogger {
  static AppLogger? _instance;
  static Logger? _logger;
  static File? _logFile;
  static LogLevel _currentLevel = kDebugMode
      ? LogLevel.trace
      : LogLevel.warning;

  AppLogger._();

  static AppLogger get instance {
    _instance ??= AppLogger._();
    return _instance!;
  }

  static Future<void> initialize() async {
    try {
      // Use AppData on Windows
      String logPath;
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) {
          throw Exception('APPDATA environment variable not found');
        }
        logPath =
            '$appData${Platform.pathSeparator}MBNDownloader${Platform.pathSeparator}logs';
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, use app-specific documents directory
        final directory = await getApplicationDocumentsDirectory();
        logPath =
            '${directory.path}${Platform.pathSeparator}MBNDownloader${Platform.pathSeparator}logs';
      } else {
        // macOS, Linux
        final directory = await getApplicationDocumentsDirectory();
        logPath = '${directory.path}${Platform.pathSeparator}logs';
      }

      final logDir = Directory(logPath);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      _logFile = File('$logPath${Platform.pathSeparator}app_log.txt');

      // Clear log file on app start
      await _logFile!.writeAsString('');

      _logger = Logger(
        filter: ProductionFilter(),
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: _FileOutput(_logFile!),
      );

      _writeToFile('=== App Started at ${DateTime.now()} ===\n');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  static void setLogLevel(LogLevel level) {
    _currentLevel = level;
  }

  static LogLevel get currentLevel => _currentLevel;

  static bool _shouldLog(LogLevel level) {
    return level.index >= _currentLevel.index;
  }

  static void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.trace)) {
      _logger?.t(message, error: error, stackTrace: stackTrace);
      _writeToFile(
        '[TRACE] $message ${error != null ? '\nError: $error' : ''}',
      );
    }
  }

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.debug)) {
      _logger?.d(message, error: error, stackTrace: stackTrace);
      _writeToFile(
        '[DEBUG] $message ${error != null ? '\nError: $error' : ''}',
      );
    }
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.info)) {
      _logger?.i(message, error: error, stackTrace: stackTrace);
      _writeToFile('[INFO] $message ${error != null ? '\nError: $error' : ''}');
    }
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.warning)) {
      _logger?.w(message, error: error, stackTrace: stackTrace);
      _writeToFile(
        '[WARNING] $message ${error != null ? '\nError: $error' : ''}',
      );
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.error)) {
      _logger?.e(message, error: error, stackTrace: stackTrace);
      _writeToFile(
        '[ERROR] $message ${error != null ? '\nError: $error' : ''}\n${stackTrace ?? ''}',
      );
    }
  }

  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LogLevel.fatal)) {
      _logger?.f(message, error: error, stackTrace: stackTrace);
      _writeToFile(
        '[FATAL] $message ${error != null ? '\nError: $error' : ''}\n${stackTrace ?? ''}',
      );
    }
  }

  static void _writeToFile(String message) {
    if (_logFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        _logFile!.writeAsStringSync(
          '[$timestamp] $message\n',
          mode: FileMode.append,
        );
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }
  }

  static Future<String?> getLogFilePath() async {
    return _logFile?.path;
  }

  static Future<String> getLogContent() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return '';
  }
}

class _FileOutput extends LogOutput {
  final File file;

  _FileOutput(this.file);

  @override
  void output(OutputEvent event) {
    // Already handled by _writeToFile method
  }
}
