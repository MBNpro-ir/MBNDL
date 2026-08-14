import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/cookie_item.dart';
import '../../shared/utils/media_url_classifier.dart';
import '../logger/app_logger.dart';

class CookieStorageService {
  static final CookieStorageService instance = CookieStorageService._();
  CookieStorageService._();

  late Directory _cookiesDir;
  late File _cookiesIndexFile;
  late Directory _materializedDir;
  static const _secureStorage = FlutterSecureStorage();
  static const _secretPrefix = 'youtube_cookie_';
  static const int maxAccounts = 3;
  List<CookieItem> _cookies = [];
  String? _selectedCookieId;

  Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _cookiesDir = Directory('${appDir.path}${Platform.pathSeparator}cookies');

      if (!await _cookiesDir.exists()) {
        await _cookiesDir.create(recursive: true);
        AppLogger.info('Created cookies directory: ${_cookiesDir.path}');
      }

      _cookiesIndexFile = File(
        '${_cookiesDir.path}${Platform.pathSeparator}cookies_index.json',
      );
      final temp = await getTemporaryDirectory();
      _materializedDir = Directory(
        '${temp.path}${Platform.pathSeparator}mbndl_youtube_auth',
      );
      if (await _materializedDir.exists()) {
        await _materializedDir.delete(recursive: true);
      }
      await _materializedDir.create(recursive: true);
      await _loadCookies();

      AppLogger.info('Cookie storage service initialized');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize cookie storage', e, stackTrace);
    }
  }

  Future<void> _loadCookies() async {
    try {
      if (await _cookiesIndexFile.exists()) {
        final content = await _cookiesIndexFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        final metadata = (data['cookies'] as List<dynamic>? ?? const []);
        var migratedLegacySecrets = false;
        final loaded = <CookieItem>[];
        for (final value in metadata) {
          final json = Map<String, dynamic>.from(value as Map);
          final id = json['id']?.toString();
          if (id == null || !_isSafeId(id)) continue;
          var content = await _secureStorage.read(key: '$_secretPrefix$id');
          final legacyContent = json['content']?.toString();
          if ((content == null || content.isEmpty) &&
              legacyContent != null &&
              legacyContent.isNotEmpty) {
            content = legacyContent;
            await _secureStorage.write(
              key: '$_secretPrefix$id',
              value: legacyContent,
            );
            migratedLegacySecrets = true;
          }
          if (content == null || content.isEmpty) continue;
          loaded.add(CookieItem.fromJson(json, content: content));
        }
        _cookies = loaded.take(maxAccounts).toList(growable: true);
        _selectedCookieId = data['selectedCookieId'] as String?;
        if (!_cookies.any((cookie) => cookie.id == _selectedCookieId)) {
          _selectedCookieId = null;
        }

        if (migratedLegacySecrets || metadata.length != _cookies.length) {
          await _saveCookies();
        }

        AppLogger.info('Loaded ${_cookies.length} cookies');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load cookies', e, stackTrace);
      _cookies = [];
      _selectedCookieId = null;
    }
  }

  Future<void> _saveCookies() async {
    try {
      final data = {
        'cookies': _cookies.map((c) => c.toJson()).toList(),
        'selectedCookieId': _selectedCookieId,
      };

      await _cookiesIndexFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );

      AppLogger.info('Saved ${_cookies.length} cookies');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save cookies', e, stackTrace);
    }
  }

  List<CookieItem> getCookies() => List.unmodifiable(_cookies);

  String? getSelectedCookieId() => _selectedCookieId;

  CookieItem? getSelectedCookie() {
    if (_selectedCookieId == null) return null;
    try {
      return _cookies.firstWhere((c) => c.id == _selectedCookieId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCookie(CookieItem cookie) async {
    if (_cookies.length >= maxAccounts) {
      throw StateError('You can save up to $maxAccounts YouTube accounts.');
    }
    if (!_isSafeId(cookie.id)) {
      throw ArgumentError.value(cookie.id, 'id', 'Invalid account ID');
    }
    await _secureStorage.write(
      key: '$_secretPrefix${cookie.id}',
      value: cookie.content,
    );
    _cookies.add(cookie);
    _selectedCookieId = cookie.id;
    await _saveCookies();
    AppLogger.info('Added cookie: ${cookie.name}');
  }

  Future<void> updateCookie(CookieItem cookie) async {
    final index = _cookies.indexWhere((c) => c.id == cookie.id);
    if (index != -1) {
      await _secureStorage.write(
        key: '$_secretPrefix${cookie.id}',
        value: cookie.content,
      );
      _cookies[index] = cookie;
      await _saveCookies();
      AppLogger.info('Updated cookie: ${cookie.name}');
    }
  }

  Future<void> deleteCookie(String id) async {
    await _secureStorage.delete(key: '$_secretPrefix$id');
    _cookies.removeWhere((c) => c.id == id);
    if (_selectedCookieId == id) {
      _selectedCookieId = null;
    }
    await _saveCookies();
    AppLogger.info('Deleted cookie: $id');
  }

  Future<void> selectCookie(String? id) async {
    _selectedCookieId = id;
    await _saveCookies();
    AppLogger.info('Selected cookie: $id');
  }

  Future<void> clearSelection() async {
    _selectedCookieId = null;
    await _saveCookies();
    AppLogger.info('Cleared cookie selection');
  }

  Future<void> clearAll() async {
    final storedSecrets = await _secureStorage.readAll();
    for (final key in storedSecrets.keys.where(
      (key) => key.startsWith(_secretPrefix),
    )) {
      await _secureStorage.delete(key: key);
    }
    _cookies.clear();
    _selectedCookieId = null;
    if (await _materializedDir.exists()) {
      await _materializedDir.delete(recursive: true);
      await _materializedDir.create(recursive: true);
    }
    await _saveCookies();
    AppLogger.info('Cleared all securely stored YouTube accounts');
  }

  bool get hasSelectedAccount => getSelectedCookie() != null;

  /// Materializes the selected secret just-in-time for yt-dlp. Browser cookies
  /// are never applied to non-YouTube URLs.
  Future<String?> materializeSelectedCookieForUrl(String url) async {
    if (!MediaUrlClassifier.isYouTubeUrl(url)) return null;
    final selected = getSelectedCookie();
    if (selected == null) return null;

    if (!await _materializedDir.exists()) {
      await _materializedDir.create(recursive: true);
    }
    final cookieFile = File(
      '${_materializedDir.path}${Platform.pathSeparator}${selected.id}.cookies.txt',
    );
    await cookieFile.writeAsString(selected.content, flush: true);

    return cookieFile.path;
  }

  Future<void> releaseMaterializedCookie(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not remove the temporary YouTube cookie file',
        error,
        stackTrace,
      );
    }
  }

  static String? validateYouTubeCookieFile(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trimLeft();
    if (normalized.isEmpty) return 'The selected file is empty.';
    final firstLine = normalized.split('\n').first.trim();
    if (firstLine != '# Netscape HTTP Cookie File' &&
        firstLine != '# HTTP Cookie File') {
      return 'The first line must identify a Netscape HTTP Cookie File.';
    }

    final cookieLines = normalized
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          return trimmed.isNotEmpty &&
              (!trimmed.startsWith('#') || trimmed.startsWith('#HttpOnly_'));
        })
        .toList(growable: false);
    final validRows = cookieLines.where((line) => line.split('\t').length >= 7);
    if (validRows.isEmpty) {
      return 'No valid tab-separated cookie rows were found.';
    }
    final hasYouTubeDomain = validRows.any((line) {
      final domain = line.split('\t').first.toLowerCase().replaceFirst('.', '');
      return domain == 'youtube.com' ||
          domain.endsWith('.youtube.com') ||
          domain == 'google.com' ||
          domain.endsWith('.google.com');
    });
    if (!hasYouTubeDomain) {
      return 'This file does not contain YouTube or Google cookies.';
    }
    return null;
  }

  static bool _isSafeId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id);
}
