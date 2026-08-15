import 'dart:convert';

import 'log_level.dart';

/// One structured application log event.
///
/// Events are stored as newline-delimited JSON so an exception and its stack
/// trace always stay attached to the level selected by the user. Older MBNDL
/// text logs are still understood by [parseContent].
class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.message,
    this.level,
    this.error,
    this.stackTrace,
    this.session = false,
  });

  final DateTime timestamp;
  final LogLevel? level;
  final String message;
  final String? error;
  final String? stackTrace;
  final bool session;

  String get searchableText => [
    message,
    if (error?.isNotEmpty == true) error!,
    if (stackTrace?.isNotEmpty == true) stackTrace!,
  ].join('\n');

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level?.name ?? 'session',
    'message': message,
    if (error?.isNotEmpty == true) 'error': error,
    if (stackTrace?.isNotEmpty == true) 'stackTrace': stackTrace,
  };

  String toLine() => jsonEncode(toJson());

  static AppLogEntry? fromLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    try {
      final raw = jsonDecode(trimmed);
      if (raw is Map) {
        final json = Map<String, dynamic>.from(raw);
        final levelName = json['level']?.toString().toLowerCase();
        return AppLogEntry(
          timestamp:
              DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          level: LogLevel.values.cast<LogLevel?>().firstWhere(
            (value) => value?.name == levelName,
            orElse: () => null,
          ),
          message: json['message']?.toString() ?? '',
          error: json['error']?.toString(),
          stackTrace: json['stackTrace']?.toString(),
          session: levelName == 'session',
        );
      }
    } catch (_) {
      // Fall through to the legacy text parser.
    }

    final legacy = RegExp(
      r'^\[([^\]]+)\]\s+\[(TRACE|DEBUG|INFO|WARNING|ERROR|FATAL)\]\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (legacy != null) {
      final levelName = legacy.group(2)!.toLowerCase();
      return AppLogEntry(
        timestamp:
            DateTime.tryParse(legacy.group(1)!) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        level: LogLevel.values.firstWhere((value) => value.name == levelName),
        message: legacy.group(3) ?? '',
      );
    }

    final legacySession = RegExp(
      r'^\[([^\]]+)\]\s+===\s*App Started.*===\s*$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (legacySession != null) {
      return AppLogEntry(
        timestamp:
            DateTime.tryParse(legacySession.group(1)!) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        message: 'Application started',
        session: true,
      );
    }

    return null;
  }

  static List<AppLogEntry> parseContent(String content) {
    final entries = <AppLogEntry>[];
    for (final line in const LineSplitter().convert(content)) {
      final parsed = fromLine(line);
      if (parsed != null) {
        entries.add(parsed);
        continue;
      }

      // Legacy files wrote errors and stack frames on unlabelled continuation
      // lines. Attach those lines to the preceding event so level filtering is
      // correct instead of showing them as unrelated grey records.
      if (line.trim().isNotEmpty && entries.isNotEmpty) {
        final previous = entries.removeLast();
        entries.add(
          AppLogEntry(
            timestamp: previous.timestamp,
            level: previous.level,
            message: previous.message,
            error: previous.error,
            stackTrace: [
              if (previous.stackTrace?.isNotEmpty == true) previous.stackTrace!,
              line,
            ].join('\n'),
            session: previous.session,
          ),
        );
      }
    }
    return entries;
  }
}
