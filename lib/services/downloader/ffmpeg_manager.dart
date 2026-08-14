import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../logger/app_logger.dart';
import 'remote_zip_archive.dart';

/// Owns the app-private FFmpeg toolchain used by yt-dlp.
///
/// Windows builds bootstrap offline from a minimal bundled archive. Updates
/// use byte-range requests to transfer only ffmpeg.exe and ffprobe.exe from
/// the Essentials ZIP; ffplay, documentation and presets are not downloaded.
class FFmpegManager {
  FFmpegManager._();

  static final FFmpegManager instance = FFmpegManager._();

  static const String _windowsArchiveUrl =
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
  static const String _windowsVersionUrl =
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.ver';
  static const String _bundledArchiveName = 'ffmpeg-windows-x64.zip';
  static const String _githubApiUrl =
      'https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest';
  static const Map<String, String> _headers = {'User-Agent': 'MBN-Downloader'};

  String? _currentVersion;
  String? _latestVersion;
  DateTime? _lastUpdateCheck;
  Future<bool>? _bootstrapOperation;

  Future<Directory> getFFmpegDirectory() async {
    final appData =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final directory = Directory(
      '$appData${Platform.pathSeparator}MBNDownloader'
      '${Platform.pathSeparator}ffmpeg',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> getFFmpegFile() async {
    final directory = await getFFmpegDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '${Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg'}',
    );
  }

  Future<File> getFFprobeFile() async {
    final directory = await getFFmpegDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '${Platform.isWindows ? 'ffprobe.exe' : 'ffprobe'}',
    );
  }

  Future<String?> getCurrentVersion({bool forceCheck = false}) async {
    if (!forceCheck && _currentVersion != null) return _currentVersion;

    try {
      final ffmpeg = await getFFmpegFile();
      final ffprobe = await getFFprobeFile();
      if (!await ffmpeg.exists() || !await ffprobe.exists()) return null;

      final versions = await Future.wait([
        _readToolVersion(ffmpeg, 'ffmpeg'),
        _readToolVersion(ffprobe, 'ffprobe'),
      ]);
      if (versions.any((version) => version == null)) return null;

      _currentVersion = versions.first;
      AppLogger.info('Current FFmpeg version: $_currentVersion');
      return _currentVersion;
    } catch (error) {
      AppLogger.warning('Failed to get FFmpeg version: $error');
      return null;
    }
  }

  Future<String?> _readToolVersion(File executable, String toolName) async {
    final result = await Process.run(executable.path, const [
      '-version',
    ]).timeout(const Duration(seconds: 12));
    if (result.exitCode != 0) return null;

    final output = '${result.stdout}\n${result.stderr}';
    final match = RegExp(
      '$toolName version ([^\\s]+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (match == null) return null;
    return _normalizeVersion(match.group(1)!);
  }

  static String _normalizeVersion(String raw) {
    final value = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return RegExp(r'\d+\.\d+(?:\.\d+)?').firstMatch(value)?.group(0) ?? value;
  }

  Future<String?> getLatestVersion({bool forceCheck = false}) async {
    if (!forceCheck &&
        _latestVersion != null &&
        _lastUpdateCheck != null &&
        DateTime.now().difference(_lastUpdateCheck!) <
            const Duration(hours: 1)) {
      return _latestVersion;
    }

    try {
      if (Platform.isWindows) {
        final response = await http
            .get(Uri.parse(_windowsVersionUrl), headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Version endpoint returned ${response.statusCode}',
          );
        }
        _latestVersion = _normalizeVersion(
          utf8.decode(response.bodyBytes).trim(),
        );
      } else {
        final response = await http
            .get(Uri.parse(_githubApiUrl), headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('GitHub returned ${response.statusCode}');
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _latestVersion = data['tag_name']?.toString().trim();
      }

      _lastUpdateCheck = DateTime.now();
      AppLogger.info('Latest FFmpeg version: $_latestVersion');
      return _latestVersion;
    } catch (error) {
      AppLogger.warning('Failed to check FFmpeg version: $error');
      return null;
    }
  }

  Future<bool> isUpdateAvailable() async {
    final versions = await Future.wait([
      getCurrentVersion(),
      getLatestVersion(),
    ]);
    return versions[0] != null &&
        versions[1] != null &&
        versions[0] != versions[1];
  }

  /// Makes a clean Windows install ready without any network request.
  Future<bool> ensureBundledBootstrapReady({
    void Function(String status)? onStatus,
  }) async {
    if (!Platform.isWindows) {
      return await getCurrentVersion(forceCheck: true) != null;
    }

    final running = _bootstrapOperation;
    if (running != null) return running;
    final operation = _ensureBundledBootstrapReady(onStatus: onStatus);
    _bootstrapOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_bootstrapOperation, operation)) {
        _bootstrapOperation = null;
      }
    }
  }

  Future<bool> _ensureBundledBootstrapReady({
    void Function(String status)? onStatus,
  }) async {
    if (await getCurrentVersion(forceCheck: true) != null) return true;

    Directory? staging;
    try {
      onStatus?.call('Preparing bundled FFmpeg tools...');
      final ffmpegDirectory = await getFFmpegDirectory();
      staging = Directory(
        '${ffmpegDirectory.path}${Platform.pathSeparator}'
        '.bootstrap-${DateTime.now().microsecondsSinceEpoch}',
      );
      await staging.create(recursive: true);

      final archive = File(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}data${Platform.pathSeparator}tools'
        '${Platform.pathSeparator}$_bundledArchiveName',
      );
      if (!await archive.exists()) {
        throw FileSystemException(
          'The bundled FFmpeg archive is missing',
          archive.path,
        );
      }

      final result = await Process.run('powershell.exe', [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Expand-Archive -LiteralPath ${_powerShellQuote(archive.path)} '
            '-DestinationPath ${_powerShellQuote(staging.path)} -Force',
      ]).timeout(const Duration(minutes: 3));
      if (result.exitCode != 0) {
        throw ProcessException(
          'powershell.exe',
          const ['Expand-Archive'],
          result.stderr.toString(),
          result.exitCode,
        );
      }

      final stagedFFmpeg = File(
        '${staging.path}${Platform.pathSeparator}ffmpeg.exe',
      );
      final stagedFFprobe = File(
        '${staging.path}${Platform.pathSeparator}ffprobe.exe',
      );
      await _validateStagedTools(stagedFFmpeg, stagedFFprobe);
      await _installStagedTools(stagedFFmpeg, stagedFFprobe);
      await _copyBundledNotices(staging, ffmpegDirectory);

      _currentVersion = null;
      final version = await getCurrentVersion(forceCheck: true);
      if (version == null) {
        throw StateError('Bundled FFmpeg tools did not start correctly');
      }
      onStatus?.call('FFmpeg $version is ready');
      AppLogger.info('Installed bundled FFmpeg $version without a download');
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to install bundled FFmpeg tools',
        error,
        stackTrace,
      );
      return false;
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<bool> downloadAndInstall({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (Platform.isWindows) {
      return _downloadSelectedWindowsTools(
        onProgress: onProgress,
        onStatus: onStatus,
      );
    }
    return _downloadUnixTools(onProgress: onProgress, onStatus: onStatus);
  }

  Future<bool> _downloadSelectedWindowsTools({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final client = http.Client();
    Directory? staging;
    try {
      onProgress?.call(0);
      onStatus?.call('Checking the latest FFmpeg release...');
      final expectedVersion = await getLatestVersion(forceCheck: true);

      final remote = RemoteZipArchive(
        uri: Uri.parse(_windowsArchiveUrl),
        client: client,
        headers: _headers,
      );
      await remote.readEntries();
      final entries = [
        await remote.findUniqueFile('ffmpeg.exe'),
        await remote.findUniqueFile('ffprobe.exe'),
      ];
      final totalCompressedBytes = entries.fold<int>(
        0,
        (total, entry) => total + entry.compressedSize,
      );
      final transferMiB = totalCompressedBytes / (1024 * 1024);

      final directory = await getFFmpegDirectory();
      staging = Directory(
        '${directory.path}${Platform.pathSeparator}'
        '.update-${DateTime.now().microsecondsSinceEpoch}',
      );
      await staging.create(recursive: true);

      var completedBytes = 0;
      for (final entry in entries) {
        final basename = entry.name.replaceAll('\\', '/').split('/').last;
        onStatus?.call(
          'Downloading $basename '
          '(${transferMiB.toStringAsFixed(1)} MiB total)...',
        );
        await remote.extractEntry(
          entry,
          File('${staging.path}${Platform.pathSeparator}$basename'),
          onProgress: (received, _) {
            final fraction = totalCompressedBytes == 0
                ? 1.0
                : (completedBytes + received) / totalCompressedBytes;
            onProgress?.call(5 + fraction * 85);
          },
        );
        completedBytes += entry.compressedSize;
      }

      onProgress?.call(92);
      onStatus?.call('Verifying FFmpeg and FFprobe...');
      final stagedFFmpeg = File(
        '${staging.path}${Platform.pathSeparator}ffmpeg.exe',
      );
      final stagedFFprobe = File(
        '${staging.path}${Platform.pathSeparator}ffprobe.exe',
      );
      final stagedVersion = await _validateStagedTools(
        stagedFFmpeg,
        stagedFFprobe,
      );
      if (expectedVersion != null && stagedVersion != expectedVersion) {
        throw StateError(
          'Downloaded FFmpeg is $stagedVersion; expected $expectedVersion',
        );
      }

      onStatus?.call('Installing FFmpeg tools...');
      await _installStagedTools(stagedFFmpeg, stagedFFprobe);
      await File(
        '${directory.path}${Platform.pathSeparator}SOURCE.txt',
      ).writeAsString(
        'FFmpeg $stagedVersion\n'
        'Source archive: $_windowsArchiveUrl\n'
        'Installed files: ffmpeg.exe, ffprobe.exe\n'
        'The updater transferred only the selected ZIP entries.\n',
        flush: true,
      );

      _currentVersion = null;
      _latestVersion = stagedVersion;
      _lastUpdateCheck = DateTime.now();
      final installedVersion = await getCurrentVersion(forceCheck: true);
      if (installedVersion == null) {
        throw StateError('Installed FFmpeg tools did not start correctly');
      }

      onProgress?.call(100);
      onStatus?.call('FFmpeg $installedVersion is ready');
      AppLogger.info(
        'Installed FFmpeg $installedVersion after transferring only '
        'ffmpeg.exe and ffprobe.exe',
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update FFmpeg', error, stackTrace);
      onStatus?.call('FFmpeg update failed');
      return false;
    } finally {
      client.close();
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<String> _validateStagedTools(File ffmpeg, File ffprobe) async {
    if (!await ffmpeg.exists() || !await ffprobe.exists()) {
      throw const FileSystemException(
        'The archive does not contain both required FFmpeg tools',
      );
    }
    final versions = await Future.wait([
      _readToolVersion(ffmpeg, 'ffmpeg'),
      _readToolVersion(ffprobe, 'ffprobe'),
    ]);
    if (versions[0] == null || versions[1] == null) {
      throw StateError('FFmpeg or FFprobe failed its executable check');
    }
    if (versions[0] != versions[1]) {
      throw StateError('FFmpeg and FFprobe versions do not match');
    }
    return versions[0]!;
  }

  Future<void> _installStagedTools(File ffmpeg, File ffprobe) async {
    final targets = <File, File>{
      ffmpeg: await getFFmpegFile(),
      ffprobe: await getFFprobeFile(),
    };
    final backups = <File, File>{};
    final installedTargets = <File>[];

    try {
      for (final target in targets.values) {
        final backup = File('${target.path}.backup');
        if (await backup.exists()) await backup.delete();
        if (await target.exists()) {
          await target.rename(backup.path);
          backups[target] = backup;
        }
      }

      for (final pair in targets.entries) {
        await pair.key.rename(pair.value.path);
        installedTargets.add(pair.value);
      }

      final installedVersion = await _validateStagedTools(
        await getFFmpegFile(),
        await getFFprobeFile(),
      );
      AppLogger.debug('Validated installed FFmpeg $installedVersion');
    } catch (_) {
      for (final target in installedTargets) {
        if (await target.exists()) await target.delete();
      }
      for (final pair in backups.entries) {
        if (await pair.value.exists()) {
          await pair.value.rename(pair.key.path);
        }
      }
      rethrow;
    }

    // Backup cleanup is intentionally outside the rollback transaction. A
    // transient cleanup failure must not remove newly validated executables.
    for (final backup in backups.values) {
      try {
        if (await backup.exists()) await backup.delete();
      } catch (error) {
        AppLogger.warning('Could not remove FFmpeg backup: $error');
      }
    }
  }

  Future<void> _copyBundledNotices(Directory staging, Directory target) async {
    for (final name in const ['LICENSE.txt', 'README.txt', 'SOURCE.txt']) {
      final source = File('${staging.path}${Platform.pathSeparator}$name');
      if (await source.exists()) {
        await source.copy('${target.path}${Platform.pathSeparator}$name');
      }
    }
  }

  Future<bool> _downloadUnixTools({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (!Platform.isLinux) return false;
    const url =
        'https://johnvansickle.com/ffmpeg/releases/'
        'ffmpeg-release-amd64-static.tar.xz';
    final client = http.Client();
    File? archive;
    try {
      onStatus?.call('Downloading FFmpeg...');
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download returned ${response.statusCode}');
      }

      final directory = await getFFmpegDirectory();
      archive = File(
        '${directory.path}${Platform.pathSeparator}ffmpeg-update.tar.xz',
      );
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = archive.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received * 80 / total);
      }
      await sink.close();

      onStatus?.call('Extracting FFmpeg...');
      final result = await Process.run('tar', [
        '-xJf',
        archive.path,
        '-C',
        directory.path,
        '--strip-components=1',
        '--wildcards',
        '*/ffmpeg',
        '*/ffprobe',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException('tar', const [], result.stderr.toString());
      }
      await Process.run('chmod', [
        '+x',
        (await getFFmpegFile()).path,
        (await getFFprobeFile()).path,
      ]);

      _currentVersion = null;
      onProgress?.call(100);
      return await getCurrentVersion(forceCheck: true) != null;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to install FFmpeg', error, stackTrace);
      return false;
    } finally {
      client.close();
      if (archive != null && await archive.exists()) await archive.delete();
    }
  }

  Future<bool> ensureFFmpegReady({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final current = await getCurrentVersion(forceCheck: true);
    if (current != null) {
      onProgress?.call(100);
      onStatus?.call('FFmpeg $current is ready');
      return true;
    }

    if (Platform.isWindows &&
        await ensureBundledBootstrapReady(onStatus: onStatus)) {
      onProgress?.call(100);
      return true;
    }

    return downloadAndInstall(onProgress: onProgress, onStatus: onStatus);
  }

  Future<String?> getFFmpegPath() async {
    final ffmpeg = await getFFmpegFile();
    final ffprobe = await getFFprobeFile();
    return await ffmpeg.exists() && await ffprobe.exists() ? ffmpeg.path : null;
  }

  Future<bool> uninstall() async {
    try {
      final directory = await getFFmpegDirectory();
      if (await directory.exists()) await directory.delete(recursive: true);
      _currentVersion = null;
      _latestVersion = null;
      _lastUpdateCheck = null;
      AppLogger.info('FFmpeg uninstalled');
      return true;
    } catch (error) {
      AppLogger.error('Failed to uninstall FFmpeg', error);
      return false;
    }
  }

  static String _powerShellQuote(String value) =>
      "'${value.replaceAll("'", "''")}'";
}
