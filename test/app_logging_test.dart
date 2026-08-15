import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/logger/app_log_entry.dart';
import 'package:mbn_downloader/services/logger/app_logger.dart';
import 'package:mbn_downloader/services/logger/log_sanitizer.dart';

void main() {
  test('selected threshold records that level and more severe events', () {
    expect(
      AppLogger.shouldLog(LogLevel.debug, threshold: LogLevel.warning),
      isFalse,
    );
    expect(
      AppLogger.shouldLog(LogLevel.warning, threshold: LogLevel.warning),
      isTrue,
    );
    expect(
      AppLogger.shouldLog(LogLevel.fatal, threshold: LogLevel.warning),
      isTrue,
    );
  });

  test('structured error remains one filterable event', () {
    final original = AppLogEntry(
      timestamp: DateTime.utc(2026, 8, 15),
      level: LogLevel.error,
      message: 'Download failed',
      error: 'HTTP 403\nForbidden',
      stackTrace: '#0 DownloadService.start\n#1 Queue.pump',
    );

    final parsed = AppLogEntry.parseContent('${original.toLine()}\n');

    expect(parsed, hasLength(1));
    expect(parsed.single.level, LogLevel.error);
    expect(parsed.single.error, contains('Forbidden'));
    expect(parsed.single.stackTrace, contains('Queue.pump'));
  });

  test('tool output uses the severity declared by yt-dlp', () {
    expect(
      AppLogger.levelForToolOutput('ERROR: HTTP Error 403: Forbidden'),
      LogLevel.error,
    );
    expect(
      AppLogger.levelForToolOutput(
        'WARNING: [youtube] signature extraction failed',
      ),
      LogLevel.warning,
    );
    expect(
      AppLogger.levelForToolOutput('[debug] Command-line config'),
      LogLevel.debug,
    );
    expect(
      AppLogger.levelForToolOutput(
        '[youtube] ERROR: Sign in to confirm you are not a bot',
      ),
      LogLevel.error,
    );
  });

  test('legacy continuation lines attach to the preceding level', () {
    const legacy =
        '[2026-08-15T00:00:00.000] [ERROR] Download failed\n'
        'Error: HTTP 403\n'
        '#0 DownloadService.start\n'
        '[2026-08-15T00:00:01.000] [INFO] Queue continued\n';

    final parsed = AppLogEntry.parseContent(legacy);

    expect(parsed, hasLength(2));
    expect(parsed.first.level, LogLevel.error);
    expect(parsed.first.stackTrace, contains('HTTP 403'));
    expect(parsed.first.stackTrace, contains('DownloadService.start'));
    expect(parsed.last.level, LogLevel.info);
  });

  test('download arguments never expose cookies or proxy credentials', () {
    final safe = LogSanitizer.commandArgs(const [
      '--cookies',
      r'C:\secret\youtube.txt',
      '--proxy',
      'http://name:password@localhost:8080',
      '--format',
      'best',
    ]);

    expect(safe, isNot(contains('youtube.txt')));
    expect(safe, isNot(contains('password')));
    expect(safe, contains('--format best'));
  });

  test('free-form log text redacts headers and credentialed proxies', () {
    final safe = LogSanitizer.text(
      'Proxy http://name:secret@localhost:8080\n'
      'Authorization: Bearer private-token\n'
      '--cookies C:/private/youtube.txt',
    );

    expect(safe, isNot(contains('secret')));
    expect(safe, isNot(contains('private-token')));
    expect(safe, isNot(contains('youtube.txt')));
  });
}
