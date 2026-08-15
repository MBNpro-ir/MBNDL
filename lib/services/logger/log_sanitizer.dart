class LogSanitizer {
  const LogSanitizer._();

  static const _secretValueFlags = {
    '--cookies',
    '--cookies-from-browser',
    '--username',
    '--password',
    '--video-password',
    '--client-certificate-key',
    '--client-certificate-password',
  };

  static String commandArgs(Iterable<String> arguments) {
    final safe = <String>[];
    var hideNext = false;
    var proxyNext = false;
    for (final argument in arguments) {
      if (hideNext) {
        safe.add('<redacted>');
        hideNext = false;
        continue;
      }
      if (proxyNext) {
        safe.add(_redactProxy(argument));
        proxyNext = false;
        continue;
      }
      if (_secretValueFlags.contains(argument)) {
        safe.add(argument);
        hideNext = true;
        continue;
      }
      if (argument == '--proxy') {
        safe.add(argument);
        proxyNext = true;
        continue;
      }
      if (argument.startsWith('--proxy=')) {
        safe.add('--proxy=${_redactProxy(argument.substring(8))}');
        continue;
      }
      if (argument.startsWith('--add-header=') &&
          RegExp(
            r'(authorization|cookie)\s*:',
            caseSensitive: false,
          ).hasMatch(argument)) {
        safe.add('--add-header=<redacted>');
        continue;
      }
      safe.add(argument);
    }
    return safe.join(' ');
  }

  /// Removes common authentication material from arbitrary tool output and
  /// exception text before it reaches disk or the in-app viewer.
  static String text(String value) {
    var safe = value;
    safe = safe.replaceAllMapped(
      RegExp(
        r'\b(https?|socks5h?|socks4a?)://[^\s/@:]+:[^\s/@]+@',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}://***@',
    );
    safe = safe.replaceAllMapped(
      RegExp(
        r'\b(authorization|cookie|set-cookie)\s*:\s*[^\r\n]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}: <redacted>',
    );
    safe = safe.replaceAll(
      RegExp(
        r'(--cookies(?:-from-browser)?\s+)(?:"[^"]+"|\S+)',
        caseSensitive: false,
      ),
      r'$1<redacted>',
    );
    return safe;
  }

  static String _redactProxy(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.userInfo.isEmpty) return value;
    return uri.replace(userInfo: '***').toString();
  }
}
