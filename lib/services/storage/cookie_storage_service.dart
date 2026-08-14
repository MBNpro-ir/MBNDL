import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/cookie_item.dart';
import '../logger/app_logger.dart';

class CookieStorageService {
  static final CookieStorageService instance = CookieStorageService._();
  CookieStorageService._();

  late Directory _cookiesDir;
  late File _cookiesIndexFile;
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

        _cookies = (data['cookies'] as List<dynamic>)
            .map((json) => CookieItem.fromJson(json as Map<String, dynamic>))
            .toList();
        _selectedCookieId = data['selectedCookieId'] as String?;

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
    _cookies.add(cookie);
    await _saveCookies();
    AppLogger.info('Added cookie: ${cookie.name}');
  }

  Future<void> updateCookie(CookieItem cookie) async {
    final index = _cookies.indexWhere((c) => c.id == cookie.id);
    if (index != -1) {
      _cookies[index] = cookie;
      await _saveCookies();
      AppLogger.info('Updated cookie: ${cookie.name}');
    }
  }

  Future<void> deleteCookie(String id) async {
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

  // Get the actual cookie file path for yt-dlp
  String? getSelectedCookieFilePath() {
    final selected = getSelectedCookie();
    if (selected == null) return null;

    // Save cookie content to a temp file
    final cookieFile = File(
      '${_cookiesDir.path}${Platform.pathSeparator}${selected.id}.txt',
    );
    cookieFile.writeAsStringSync(selected.content);

    return cookieFile.path;
  }
}
