import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../logger/app_logger.dart';

class AndroidDownloadStorageStatus {
  const AndroidDownloadStorageStatus({
    required this.ready,
    required this.workingPath,
    required this.publicPath,
    required this.message,
  });

  final bool ready;
  final String workingPath;
  final String publicPath;
  final String message;
}

/// Service to manage download paths and temporary directories
class DownloadPathService {
  static const _androidChannel = MethodChannel('com.mbn.dl/ytdlp');
  static DownloadPathService? _instance;
  static DownloadPathService get instance {
    _instance ??= DownloadPathService._();
    return _instance!;
  }

  DownloadPathService._();

  /// Get the default download directory based on platform
  Future<String> getDefaultDownloadPath() async {
    try {
      if (Platform.isWindows) {
        final downloadsDir = await getDownloadsDirectory();
        final root =
            downloadsDir?.path ??
            (await getApplicationDocumentsDirectory()).path;
        return '$root${Platform.pathSeparator}MBNDL';
      } else if (Platform.isAndroid) {
        final path = await _androidChannel.invokeMethod<String>(
          'getDownloadPath',
        );
        if (path != null && path.trim().isNotEmpty) return path;
        final support = await getApplicationSupportDirectory();
        final fallback = Directory(
          '${support.path}${Platform.pathSeparator}downloads'
          '${Platform.pathSeparator}MBNDL',
        );
        await fallback.create(recursive: true);
        return fallback.path;
      } else if (Platform.isMacOS || Platform.isLinux) {
        final downloadsDir = await getDownloadsDirectory();
        return downloadsDir == null
            ? ''
            : '${downloadsDir.path}${Platform.pathSeparator}MBNDL';
      }
      return '';
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get default download path', e, stackTrace);
      if (Platform.isAndroid) {
        try {
          final support = await getApplicationSupportDirectory();
          final fallback = Directory(
            '${support.path}${Platform.pathSeparator}downloads'
            '${Platform.pathSeparator}MBNDL',
          );
          await fallback.create(recursive: true);
          return fallback.path;
        } catch (_) {
          // The caller will surface the failed storage verification.
        }
      }
      return '';
    }
  }

  Future<AndroidDownloadStorageStatus> verifyAndroidDownloadStorage() async {
    if (!Platform.isAndroid) {
      final path = await getDefaultDownloadPath();
      return AndroidDownloadStorageStatus(
        ready: path.isNotEmpty,
        workingPath: path,
        publicPath: path,
        message: path.isEmpty ? 'Download folder is unavailable' : 'Ready',
      );
    }
    try {
      final raw = await _androidChannel.invokeMethod<Map<dynamic, dynamic>>(
        'verifyDownloadStorage',
      );
      final value = raw ?? const <dynamic, dynamic>{};
      return AndroidDownloadStorageStatus(
        ready: value['ready'] == true,
        workingPath: value['workingPath']?.toString() ?? '',
        publicPath: value['publicPath']?.toString() ?? 'Download/MBNDL',
        message: value['message']?.toString() ?? 'Storage check failed',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to verify Android download storage',
        error,
        stackTrace,
      );
      final fallback = await getDefaultDownloadPath();
      return AndroidDownloadStorageStatus(
        ready: false,
        workingPath: fallback,
        publicPath: 'Download/MBNDL',
        message: 'Android could not verify the public download folder.',
      );
    }
  }

  Future<bool> openDownloadLocation(String path) async {
    try {
      if (Platform.isAndroid) {
        return await _androidChannel.invokeMethod<bool>('openDownloads') ??
            false;
      }
      if (Platform.isWindows) {
        return (await Process.run('explorer', [path])).exitCode == 0;
      }
      if (Platform.isMacOS) {
        return (await Process.run('open', [path])).exitCode == 0;
      }
      if (Platform.isLinux) {
        return (await Process.run('xdg-open', [path])).exitCode == 0;
      }
      return false;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to open download location', error, stackTrace);
      return false;
    }
  }

  Future<int> deletePublishedAndroidFiles(List<String> uris) async {
    if (!Platform.isAndroid || uris.isEmpty) return 0;
    try {
      return await _androidChannel.invokeMethod<int>('deletePublishedFiles', {
            'uris': uris,
          }) ??
          0;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete published Android files',
        error,
        stackTrace,
      );
      return 0;
    }
  }

  /// Finds files created by MBNDL's managed output template. History remains
  /// useful metadata, but the filesystem is the source of truth for the green
  /// "downloaded before" state in the format picker.
  Future<Map<String, int>> findExistingFormatSelectors({
    required String mediaId,
    String? downloadPath,
  }) async {
    if (mediaId.trim().isEmpty) return const {};
    try {
      final publishedCounts = Platform.isAndroid
          ? Map<String, int>.from(
              await _androidChannel.invokeMethod<Map<dynamic, dynamic>>(
                    'findExistingFormatSelectors',
                    {'mediaId': mediaId.trim()},
                  ) ??
                  const <dynamic, dynamic>{},
            )
          : const <String, int>{};
      final rootPath = downloadPath?.trim().isNotEmpty == true
          ? downloadPath!.trim()
          : await getDefaultDownloadPath();
      if (rootPath.isEmpty) return publishedCounts;
      final root = Directory(rootPath);
      if (!await root.exists()) return publishedCounts;
      final marker = RegExp(
        '\\[${RegExp.escape(mediaId)}\\] \\[([^\\]]+)\\]',
        caseSensitive: false,
      );
      final workingCounts = <String, int>{};
      for (final category in const ['Video', 'Audio']) {
        final directory = Directory(
          '$rootPath${Platform.pathSeparator}$category',
        );
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(recursive: false)) {
          if (entity is! File || entity.path.endsWith('.part')) continue;
          final separator = entity.path.lastIndexOf(Platform.pathSeparator);
          final fileName = separator < 0
              ? entity.path
              : entity.path.substring(separator + 1);
          final match = marker.firstMatch(fileName);
          final selector = match?.group(1);
          if (selector == null || selector.isEmpty) continue;
          workingCounts.update(
            selector,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
      // Android keeps a private resumable copy and a public MediaStore copy of
      // the same artifact. Taking the greater count avoids counting those two
      // representations as separate downloads.
      final counts = <String, int>{...publishedCounts};
      for (final entry in workingCounts.entries) {
        counts.update(
          entry.key,
          (published) => published > entry.value ? published : entry.value,
          ifAbsent: () => entry.value,
        );
      }
      return counts;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not inspect existing download formats',
        error,
        stackTrace,
      );
      return const {};
    }
  }

  /// Get the temporary directory for partial/fragment files
  /// This is where yt-dlp will store temporary files during download
  /// Returns a Temp subfolder inside the download directory
  Future<String> getTempDownloadPath(String downloadPath) async {
    try {
      final tempDownloadDir = Directory(
        '$downloadPath${Platform.pathSeparator}Temp',
      );

      // Create temp directory if it doesn't exist
      if (!await tempDownloadDir.exists()) {
        await tempDownloadDir.create(recursive: true);
        AppLogger.debug(
          'Created temp download directory: ${tempDownloadDir.path}',
        );
      }

      return tempDownloadDir.path;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get temp download path', e, stackTrace);
      return '';
    }
  }

  /// Ensure download directory exists
  Future<bool> ensureDownloadDirectoryExists(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        AppLogger.info('Created download directory: $path');
      }
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to create download directory: $path',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Clean old temporary files (optional - call periodically)
  Future<void> cleanOldTempFiles({
    int daysOld = 7,
    String? downloadPath,
  }) async {
    try {
      // Get download path if not provided
      final basePath = downloadPath ?? await getDefaultDownloadPath();
      final tempPath = await getTempDownloadPath(basePath);
      final tempDir = Directory(tempPath);

      if (!await tempDir.exists()) {
        return;
      }

      final now = DateTime.now();
      final entities = await tempDir.list().toList();

      int deletedCount = 0;
      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age.inDays >= daysOld) {
            await entity.delete(recursive: true);
            deletedCount++;
          }
        } catch (e) {
          // Continue on error
          continue;
        }
      }

      if (deletedCount > 0) {
        AppLogger.info('Cleaned $deletedCount old temporary files');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clean temp files', e, stackTrace);
    }
  }

  /// Get yt-dlp paths argument
  /// Returns a map with 'home' (final destination) and 'temp' (for fragments)
  Future<Map<String, String>> getYtDlpPaths(String downloadPath) async {
    final tempPath = await getTempDownloadPath(downloadPath);

    return {'home': downloadPath, 'temp': tempPath};
  }

  /// Build yt-dlp command arguments for paths
  /// Example: ['--paths', 'home:C:\\Downloads', '--paths', 'temp:C:\\Temp']
  Future<List<String>> buildYtDlpPathArgs(String downloadPath) async {
    final paths = await getYtDlpPaths(downloadPath);

    final args = <String>[];

    // Set home path (final destination)
    if (paths['home']?.isNotEmpty == true) {
      args.addAll(['--paths', 'home:${paths['home']}']);
    }

    // Set temp path (for fragments and partial files)
    if (paths['temp']?.isNotEmpty == true) {
      args.addAll(['--paths', 'temp:${paths['temp']}']);
    }

    AppLogger.debug('yt-dlp path args: $args');
    return args;
  }
}
