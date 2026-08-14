import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../logger/app_logger.dart';

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
        return path ?? '';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final downloadsDir = await getDownloadsDirectory();
        return downloadsDir == null
            ? ''
            : '${downloadsDir.path}${Platform.pathSeparator}MBNDL';
      }
      return '';
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get default download path', e, stackTrace);
      return '';
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
