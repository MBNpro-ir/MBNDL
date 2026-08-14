import 'dart:io';

class Validators {
  /// Validate URL format
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-._~:\/?#\[\]@!$&\()*+,;=]*)?$',
      caseSensitive: false,
    );

    if (!urlPattern.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validate proxy URL format
  static String? validateProxy(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final proxyPattern = RegExp(
      r'^(https?|socks[45]?):\/\/([\w\-]+\.)*[\w\-]+(:\d{1,5})?$',
      caseSensitive: false,
    );

    if (!proxyPattern.hasMatch(value)) {
      return 'Format: protocol://host:port (e.g., socks5://127.0.0.1:1080)';
    }

    return null;
  }

  /// Validate rate limit format (e.g., 1M, 500K)
  static String? validateRateLimit(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final rateLimitPattern = RegExp(
      r'^\d+(\.\d+)?[KMG]?$',
      caseSensitive: false,
    );

    if (!rateLimitPattern.hasMatch(value)) {
      return 'Format: number with K/M/G suffix (e.g., 1M, 500K)';
    }

    return null;
  }

  /// Validate buffer size format
  static String? validateBufferSize(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final bufferSizePattern = RegExp(r'^\d+[KMG]?$', caseSensitive: false);

    if (!bufferSizePattern.hasMatch(value)) {
      return 'Format: number with K/M/G suffix (e.g., 1024, 16K)';
    }

    return null;
  }

  /// Validate file size format
  static String? validateFileSize(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final fileSizePattern = RegExp(
      r'^\d+(\.\d+)?[KMG]?$',
      caseSensitive: false,
    );

    if (!fileSizePattern.hasMatch(value)) {
      return 'Format: number with K/M/G suffix (e.g., 100M, 1.5G)';
    }

    return null;
  }

  /// Validate playlist items format (e.g., 1-10, 1,3,5)
  static String? validatePlaylistItems(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final playlistPattern = RegExp(r'^(\d+(-\d+)?)(,\d+(-\d+)?)*$');

    if (!playlistPattern.hasMatch(value)) {
      return 'Format: 1-10 or 1,3,5 or 1-5,7,9-12';
    }

    return null;
  }

  /// Validate yt-dlp subtitle language expressions (e.g. en.*,fa,-live_chat).
  static String? validateLanguageCodes(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final langPattern = RegExp(
      r'^-?(all|[a-z0-9_@.*-]+)$',
      caseSensitive: false,
    );
    final languages = value.split(',').map((item) => item.trim()).toList();

    if (languages.any((item) => item.isEmpty || !langPattern.hasMatch(item))) {
      return 'Use yt-dlp language expressions, e.g. en.*,fa,-live_chat';
    }

    return null;
  }

  /// Validate date format (YYYYMMDD)
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final datePattern = RegExp(r'^\d{8}$');

    if (!datePattern.hasMatch(value)) {
      return 'Format: YYYYMMDD (e.g., 20231225)';
    }

    // Validate actual date
    try {
      final year = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day = int.parse(value.substring(6, 8));

      if (month < 1 || month > 12) {
        return 'Invalid month';
      }

      if (day < 1 || day > 31) {
        return 'Invalid day';
      }

      // Basic validation
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return 'Invalid date';
      }
    } catch (e) {
      return 'Invalid date';
    }

    return null;
  }

  /// Validate sleep interval format (seconds or range)
  static String? validateSleepInterval(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final intervalPattern = RegExp(r'^\d+(\.\d+)?(-\d+(\.\d+)?)?$');

    if (!intervalPattern.hasMatch(value)) {
      return 'Format: number or range (e.g., 5 or 3-10)';
    }

    return null;
  }

  /// Validate positive integer
  static String? validatePositiveInteger(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    if (number < 0) {
      return fieldName != null
          ? '$fieldName must be positive'
          : 'Value must be positive';
    }

    return null;
  }

  /// Validate number in range
  static String? validateNumberInRange(
    String? value, {
    required int min,
    required int max,
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    if (number < min || number > max) {
      return fieldName != null
          ? '$fieldName must be between $min and $max'
          : 'Value must be between $min and $max';
    }

    return null;
  }

  /// Validate output template
  static String? validateOutputTemplate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Output template cannot be empty';
    }

    // Check if template contains at least one placeholder
    if (!value.contains('%(') || !value.contains(')s')) {
      return 'Template should contain placeholders like %(title)s or %(ext)s';
    }

    return null;
  }

  /// Validate file path
  static String? validateFilePath(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"|?*]');
    if (Platform.isWindows && invalidChars.hasMatch(value)) {
      return 'Path contains invalid characters';
    }

    return null;
  }

  /// Validate user agent string
  static String? validateUserAgent(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    if (value.length < 10) {
      return 'User agent string too short';
    }

    return null;
  }

  /// Validate cookies file path
  static String? validateCookiesFile(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final file = File(value);
    if (!file.existsSync()) {
      return 'Cookies file does not exist';
    }

    if (!value.endsWith('.txt')) {
      return 'Cookies file must be a .txt file';
    }

    return null;
  }

  /// Validate sponsor block categories
  static String? validateSponsorBlockCategories(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final validCategories = [
      'sponsor',
      'intro',
      'outro',
      'selfpromo',
      'preview',
      'filler',
      'interaction',
      'music_offtopic',
      'poi_highlight',
    ];

    final categories = value.split(',').map((e) => e.trim()).toList();

    for (final category in categories) {
      if (!validCategories.contains(category)) {
        return 'Invalid category: $category';
      }
    }

    return null;
  }

  /// Validate IP address
  static String? validateIpAddress(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty
    }

    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

    if (!ipv4Pattern.hasMatch(value)) {
      return 'Please enter a valid IP address';
    }

    // Validate each octet
    final octets = value.split('.');
    for (final octet in octets) {
      final num = int.parse(octet);
      if (num < 0 || num > 255) {
        return 'IP address octets must be 0-255';
      }
    }

    return null;
  }
}
