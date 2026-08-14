import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../logger/app_logger.dart';

/// Installs and updates the official yt-dlp executable on desktop platforms.
///
/// Android uses youtubedl-android instead, which owns its embedded payload and
/// update lifecycle. The nightly channel is the default because that is the
/// channel recommended to regular users by the yt-dlp project.
class YtDlpManager {
  YtDlpManager._();

  static final YtDlpManager instance = YtDlpManager._();

  static const _channelApiUrls = <String, String>{
    'stable': 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
    'nightly':
        'https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest',
    'master':
        'https://api.github.com/repos/yt-dlp/yt-dlp-master-builds/releases/latest',
  };

  static const _headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'MBN-Downloader',
  };

  final Map<String, _ReleaseInfo> _releaseCache = {};
  final Map<String, DateTime> _releaseCheckedAt = {};
  String? _currentVersion;
  Future<bool>? _bootstrapOperation;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  String _normalizeChannel(String channel) =>
      _channelApiUrls.containsKey(channel) ? channel : 'nightly';

  String get _assetName => Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';

  /// Returns the private, per-user executable path used by the application.
  Future<File> getYtDlpFile() async {
    if (!_isDesktop) {
      throw UnsupportedError(
        'A standalone yt-dlp executable is only used on desktop platforms.',
      );
    }

    final String root;
    if (Platform.isWindows) {
      root =
          Platform.environment['APPDATA'] ??
          (throw StateError('APPDATA is not available'));
    } else {
      root =
          Platform.environment['HOME'] ??
          (throw StateError('HOME is not available'));
    }

    final directory = Directory('$root${Platform.pathSeparator}MBNDownloader');
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_assetName');
  }

  Future<String?> getCurrentVersion({bool forceCheck = false}) async {
    if (!_isDesktop) return null;
    if (!forceCheck && _currentVersion != null) return _currentVersion;

    try {
      final executable = await getYtDlpFile();
      if (!await executable.exists()) return null;

      final result = await Process.run(executable.path, const [
        '--version',
      ]).timeout(const Duration(seconds: 10));
      if (result.exitCode == 0) {
        _currentVersion = result.stdout.toString().trim();
        return _currentVersion;
      }
    } catch (error) {
      AppLogger.warning('Could not read the installed yt-dlp version: $error');
    }
    return null;
  }

  Future<_ReleaseInfo?> _getRelease(
    String requestedChannel, {
    bool forceCheck = false,
  }) async {
    final channel = _normalizeChannel(requestedChannel);
    final checkedAt = _releaseCheckedAt[channel];
    if (!forceCheck &&
        _releaseCache[channel] != null &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(hours: 1)) {
      return _releaseCache[channel];
    }

    try {
      final response = await http
          .get(Uri.parse(_channelApiUrls[channel]!), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub returned HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = (data['assets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();
      final asset = assets.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['name'] == _assetName,
        orElse: () => null,
      );
      if (asset == null) {
        throw StateError('Release does not contain $_assetName');
      }

      final release = _ReleaseInfo(
        version: data['tag_name']?.toString().trim() ?? '',
        downloadUrl: asset['browser_download_url']?.toString() ?? '',
        sha256: _parseSha256(asset['digest']?.toString()),
      );
      if (release.version.isEmpty || release.downloadUrl.isEmpty) {
        throw const FormatException('Incomplete GitHub release metadata');
      }

      _releaseCache[channel] = release;
      _releaseCheckedAt[channel] = DateTime.now();
      return release;
    } catch (error) {
      AppLogger.warning('Could not query the $channel yt-dlp channel: $error');
      return null;
    }
  }

  static String? _parseSha256(String? digest) {
    if (digest == null || !digest.startsWith('sha256:')) return null;
    final value = digest.substring('sha256:'.length).toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(value) ? value : null;
  }

  Future<String?> getLatestVersion({
    bool forceCheck = false,
    String channel = 'nightly',
  }) async {
    return (await _getRelease(channel, forceCheck: forceCheck))?.version;
  }

  Future<bool> isUpdateAvailable({String channel = 'nightly'}) async {
    final versions = await Future.wait([
      getCurrentVersion(),
      getLatestVersion(channel: channel),
    ]);
    final current = versions[0];
    final latest = versions[1];
    return current != null && latest != null && current != latest;
  }

  Future<bool> downloadAndInstall({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
    String channel = 'nightly',
  }) async {
    if (!_isDesktop) return false;

    final normalizedChannel = _normalizeChannel(channel);
    File? temporaryFile;
    http.Client? client;
    try {
      onStatus?.call('Checking the $normalizedChannel channel...');
      final release = await _getRelease(normalizedChannel, forceCheck: true);
      if (release == null) {
        throw StateError('Release information is unavailable');
      }

      onStatus?.call('Downloading yt-dlp ${release.version}...');
      final executable = await getYtDlpFile();
      temporaryFile = File('${executable.path}.download');
      if (await temporaryFile.exists()) await temporaryFile.delete();

      client = http.Client();
      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      request.headers.addAll(_headers);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download returned HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = temporaryFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received * 100 / total);
        }
      } finally {
        await sink.close();
      }

      if (release.sha256 != null) {
        onStatus?.call('Verifying SHA-256...');
        final actual = (await sha256.bind(temporaryFile.openRead()).first)
            .toString()
            .toLowerCase();
        if (actual != release.sha256) {
          throw const FormatException('yt-dlp SHA-256 verification failed');
        }
      }

      await _replaceExecutable(temporaryFile, executable);
      temporaryFile = null;
      _currentVersion = null;

      final installedVersion = await getCurrentVersion(forceCheck: true);
      if (installedVersion == null) {
        throw StateError('The downloaded executable did not start correctly');
      }

      onProgress?.call(100);
      onStatus?.call('yt-dlp $installedVersion is ready');
      AppLogger.info(
        'Installed yt-dlp $installedVersion from $normalizedChannel',
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Could not install yt-dlp', error, stackTrace);
      onStatus?.call('yt-dlp update failed');
      return false;
    } finally {
      client?.close();
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> _replaceExecutable(File source, File destination) async {
    final backup = File('${destination.path}.backup');
    if (await backup.exists()) await backup.delete();

    if (await destination.exists()) {
      await destination.rename(backup.path);
    }

    try {
      await source.rename(destination.path);
      if (!Platform.isWindows) {
        final chmod = await Process.run('chmod', ['+x', destination.path]);
        if (chmod.exitCode != 0) {
          throw FileSystemException('Could not mark yt-dlp executable');
        }
      }
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      if (await backup.exists()) await backup.rename(destination.path);
      rethrow;
    }
  }

  Future<bool> _installBundledBootstrap({
    void Function(String status)? onStatus,
  }) async {
    if (!Platform.isWindows) return false;
    try {
      onStatus?.call('Using the bundled offline yt-dlp...');
      final destination = await getYtDlpFile();
      final source = File('${destination.path}.bootstrap');
      final bundled = File(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}data${Platform.pathSeparator}tools'
        '${Platform.pathSeparator}yt-dlp.exe',
      );
      if (!await bundled.exists()) {
        throw FileSystemException(
          'The bundled yt-dlp executable is missing',
          bundled.path,
        );
      }
      await bundled.copy(source.path);
      await _replaceExecutable(source, destination);
      _currentVersion = null;
      return await getCurrentVersion(forceCheck: true) != null;
    } catch (error) {
      AppLogger.error('Could not install bundled yt-dlp', error);
      return false;
    }
  }

  /// Makes a clean Windows install ready from the packaged executable only.
  ///
  /// This method deliberately performs no update check and no network request.
  Future<bool> ensureBundledBootstrapReady({
    void Function(String status)? onStatus,
  }) async {
    if (!Platform.isWindows) {
      return await getCurrentVersion(forceCheck: true) != null;
    }

    if (await getCurrentVersion(forceCheck: true) != null) return true;
    final running = _bootstrapOperation;
    if (running != null) return running;

    final operation = _installBundledBootstrap(onStatus: onStatus);
    _bootstrapOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_bootstrapOperation, operation)) {
        _bootstrapOperation = null;
      }
    }
  }

  Future<bool> ensureYtDlpReady({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
    String channel = 'nightly',
  }) async {
    if (!_isDesktop) return false;

    var current = await getCurrentVersion(forceCheck: true);
    if (current == null && Platform.isWindows) {
      final bootstrapped = await ensureBundledBootstrapReady(
        onStatus: onStatus,
      );
      if (bootstrapped) {
        current = await getCurrentVersion(forceCheck: true);
      }
    }

    if (current == null) {
      return downloadAndInstall(
        onProgress: onProgress,
        onStatus: onStatus,
        channel: channel,
      );
    }

    final latest = await getLatestVersion(channel: channel);
    if (latest != null && latest != current) {
      return downloadAndInstall(
        onProgress: onProgress,
        onStatus: onStatus,
        channel: channel,
      );
    }

    onProgress?.call(100);
    onStatus?.call('yt-dlp $current is ready');
    return true;
  }

  Future<String?> getYtDlpPath() async {
    if (!_isDesktop) return null;
    final executable = await getYtDlpFile();
    return await executable.exists() ? executable.path : null;
  }

  Future<bool> uninstall() async {
    if (!_isDesktop) return false;
    try {
      final executable = await getYtDlpFile();
      if (!await executable.exists()) return true;
      await executable.delete();
      _currentVersion = null;
      return true;
    } catch (error) {
      AppLogger.error('Could not uninstall yt-dlp', error);
      return false;
    }
  }
}

class _ReleaseInfo {
  const _ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
  });

  final String version;
  final String downloadUrl;
  final String? sha256;
}
