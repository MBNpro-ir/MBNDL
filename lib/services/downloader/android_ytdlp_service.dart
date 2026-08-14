import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../shared/models/download_item.dart';
import '../../shared/models/video_format.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
import '../logger/app_logger.dart';
import '../database/database_service.dart';
import '../storage/cookie_storage_service.dart';
import 'download_error_mapper.dart';

/// Android implementation using yt-dlp through MethodChannel
class AndroidYtDlpService {
  static const MethodChannel _channel = MethodChannel('com.mbn.dl/ytdlp');
  static const EventChannel _eventChannel = EventChannel(
    'com.mbn.dl/ytdlp_events',
  );

  static AndroidYtDlpService? _instance;
  static AndroidYtDlpService get instance {
    _instance ??= AndroidYtDlpService._();
    return _instance!;
  }

  AndroidYtDlpService._();

  bool _initialized = false;
  String? _cachedExtractionKey;
  List<VideoFormat>? _cachedFormats;
  final Set<int> _cancelledDownloads = {};

  /// Initialize yt-dlp on Android
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final result = await _channel.invokeMethod('initialize');
      _initialized = result == true;
      if (_initialized) {
        AppLogger.info('Android yt-dlp initialized successfully');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize Android yt-dlp', e);
      rethrow;
    }
  }

  /// Check if yt-dlp is initialized
  Future<bool> isInitialized() async {
    try {
      final result = await _channel.invokeMethod('isInitialized');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Update yt-dlp binary
  Future<bool> updateYtDlp() async {
    return updateYtDlpFromChannel('nightly');
  }

  /// Update the embedded yt-dlp payload from an official channel.
  Future<bool> updateYtDlpFromChannel(String channel) async {
    try {
      final result = await _channel.invokeMethod('updateYtDlp', {
        'channel': channel,
      });
      return result == true;
    } catch (e) {
      AppLogger.error('Failed to update yt-dlp', e);
      return false;
    }
  }

  Future<String?> getVersion() async {
    try {
      return await _channel.invokeMethod<String>('getVersion');
    } catch (e) {
      AppLogger.warning('Failed to read Android yt-dlp version: $e');
      return null;
    }
  }

  /// Extract video information
  Future<Map<String, dynamic>> extractVideoInfo(
    String url, {
    YtDlpSettings? settings,
  }) async {
    AppLogger.info('Extracting video info for: $url');

    try {
      final options = await _extractionOptions(url, settings);
      try {
        final result = await _channel.invokeMethod('getInfo', {
          'url': url,
          'options': options,
        });
        final info = Map<String, dynamic>.from(result as Map);
        final rawFormats = info.remove('formats') as List<dynamic>?;
        if (rawFormats != null) {
          _cachedExtractionKey = _extractionKey(url, options);
          _cachedFormats = rawFormats
              .map(
                (format) => VideoFormat.fromJson(
                  Map<String, dynamic>.from(format as Map),
                ),
              )
              .toList(growable: false);
        }
        return info;
      } finally {
        await _releaseCookieFromOptions(options);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error extracting video info', e, stackTrace);
      rethrow;
    }
  }

  /// Get available formats for a video URL
  Future<List<VideoFormat>> getAvailableFormats(
    String url, {
    YtDlpSettings? settings,
  }) async {
    AppLogger.info('Fetching available formats for: $url');

    try {
      final options = await _extractionOptions(url, settings);
      try {
        final cacheKey = _extractionKey(url, options);
        if (_cachedExtractionKey == cacheKey && _cachedFormats != null) {
          return List<VideoFormat>.of(_cachedFormats!);
        }
        final result = await _channel.invokeMethod('getFormats', {
          'url': url,
          'options': options,
        });
        final formatsList = result as List;

        final formats = formatsList
            .map(
              (f) => VideoFormat.fromJson(Map<String, dynamic>.from(f as Map)),
            )
            .toList();

        AppLogger.info('Found ${formats.length} formats');
        return formats;
      } finally {
        await _releaseCookieFromOptions(options);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching formats', e, stackTrace);
      rethrow;
    }
  }

  String _extractionKey(String url, List<String> options) =>
      '$url\u0000${options.join('\u0000')}';

  Future<List<String>> _extractionOptions(
    String url,
    YtDlpSettings? settings,
  ) async {
    final options = <String>[...?settings?.toExtractionArgs()];
    final cookiePath = await CookieStorageService.instance
        .materializeSelectedCookieForUrl(url);
    if (cookiePath != null && cookiePath.isNotEmpty) {
      options.addAll(['--cookies', cookiePath]);
    }
    return options;
  }

  Future<void> _releaseCookieFromOptions(List<String> options) async {
    final index = options.lastIndexOf('--cookies');
    if (index < 0 || index + 1 >= options.length) return;
    await CookieStorageService.instance.releaseMaterializedCookie(
      options[index + 1],
    );
  }

  /// Start download
  Future<void> startDownload({
    required DownloadItem item,
    required YtDlpSettings settings,
    required Function(DownloadItem) onUpdate,
  }) async {
    if (item.id == null) {
      throw Exception('Download item must have an ID');
    }

    // Determine output directory for Android
    String outputDir;
    if (settings.downloadPath.isNotEmpty) {
      outputDir = settings.downloadPath;
    } else {
      // Use the app-owned workspace; completed files are published through
      // MediaStore by the native layer.
      outputDir = await _getDefaultAndroidDownloadPath();
    }

    // Ensure base directory exists
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      AppLogger.info('Created download directory: $outputDir');
    }

    // Create subdirectories for organized storage
    final tempDir = Directory('$outputDir/temp');
    final videoDir = Directory('$outputDir/Video');
    final audioDir = Directory('$outputDir/Audio');
    final subtitleDir = Directory('$outputDir/Subtitle');
    final coverDir = Directory('$outputDir/Cover');

    for (final subDir in [tempDir, videoDir, audioDir, subtitleDir, coverDir]) {
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
        AppLogger.info('Created directory: ${subDir.path}');
      }
    }

    // Determine download type
    final downloadType = settings.downloadType ?? 'combined';
    final isAudioOnly = downloadType == 'audio' || settings.extractAudio;

    // Preserve option order and repeated flags; several current yt-dlp options
    // (for example --js-runtimes and -P) may legitimately occur more than once.
    final options = <String>[...settings.toYtDlpArgs()];
    options.addAll(['--trim-filenames', '180']);

    // Add path configuration for organized storage
    // Note: We can't use multiple -P in options map, so we build output path directly
    String finalOutputPath;
    if (isAudioOnly) {
      finalOutputPath = audioDir.path;
    } else {
      finalOutputPath = videoDir.path;
    }

    // Use -o with full path instead of -P (more compatible with Android yt-dlp)
    options.addAll(['-o', '$finalOutputPath/${settings.outputTemplate}']);

    // Subtitle folder
    if (settings.downloadSubtitlesEnabled) {
      options.addAll([
        '--write-subs',
        if (settings.autoSubtitles) '--write-auto-subs',
        '--sub-langs',
        settings.subtitleLanguages,
        '--sub-format',
        'best',
        '--convert-subs',
        settings.subtitleFormat,
      ]);
      // Note: yt-dlp on Android may not support separate subtitle paths
      // Subtitles will be saved alongside the video
    }

    // Cover/Thumbnail folder
    if (settings.downloadThumbnailEnabled) {
      options.addAll(['--write-thumbnail', '--convert-thumbnails', 'jpg']);
      // Thumbnails will be saved to cover directory if supported
    }

    StreamSubscription<dynamic>? progressSubscription;
    String? cookieFilePath;
    try {
      // Keep plaintext cookie materialization inside the guarded scope so it
      // is removed even if native download setup fails before execution.
      cookieFilePath = await CookieStorageService.instance
          .materializeSelectedCookieForUrl(item.url);
      if (cookieFilePath != null) {
        options.addAll(['--cookies', cookieFilePath]);
        AppLogger.info('Using cookie file: $cookieFilePath');
      }

      AppLogger.info('Starting download for: ${item.title}');
      AppLogger.info('Output path: $outputDir');
      AppLogger.debug('Options: $options');

      // Update status to downloading
      var updatedItem = item.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
      await DatabaseService.instance.updateDownload(updatedItem);
      onUpdate(updatedItem);

      // Listen to progress updates
      progressSubscription = _eventChannel.receiveBroadcastStream().listen((
        event,
      ) {
        if (event is Map) {
          final downloadId = event['downloadId']?.toString();
          final progress = (event['progress'] as num?)?.toDouble();

          if (downloadId == item.id.toString() &&
              progress != null &&
              progress >= 0) {
            updatedItem = updatedItem.copyWith(progress: progress);
            DatabaseService.instance.updateDownload(updatedItem);
            onUpdate(updatedItem);
            AppLogger.debug(
              'Download progress: ${progress.toStringAsFixed(1)}%',
            );
          }
        }
      });

      // Start download via MethodChannel
      final result = await _channel.invokeMethod('startDownload', {
        'url': item.url,
        'outputPath': outputDir,
        'options': options,
        'downloadId': item.id.toString(),
        'title': item.title,
        'thumbnailUrl': item.thumbnail,
      });

      // Download completed
      final resultMap = Map<String, dynamic>.from(result as Map);
      final success = resultMap['success'] == true;
      final filePath = resultMap['filePath'] as String?;
      final relatedPaths =
          (resultMap['relatedFilePaths'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[];
      final publicUris =
          (resultMap['publicUris'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[];
      const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.avif'};
      const subtitleExtensions = {
        '.srt',
        '.vtt',
        '.ass',
        '.ssa',
        '.lrc',
        '.ttml',
      };
      final coverPath = relatedPaths.cast<String?>().firstWhere(
        (path) =>
            path != null &&
            imageExtensions.contains(p.extension(path).toLowerCase()),
        orElse: () => null,
      );
      final subtitlePaths = relatedPaths
          .where(
            (path) =>
                subtitleExtensions.contains(p.extension(path).toLowerCase()),
          )
          .toList(growable: false);

      if (success && filePath != null) {
        _cancelledDownloads.remove(item.id);
        // Success
        final file = File(filePath);
        final fileSize = await file.exists() ? await file.length() : null;

        updatedItem = updatedItem.copyWith(
          status: DownloadStatus.completed,
          progress: 100.0,
          filePath: filePath,
          fileSize: fileSize,
          completedAt: DateTime.now(),
          coverPath: coverPath,
          subtitlePaths: subtitlePaths,
          relatedFilePaths: relatedPaths,
          publicUris: publicUris,
          clearErrorMessage: true,
          clearCurrentPhase: true,
        );

        await DatabaseService.instance.updateDownload(updatedItem);
        onUpdate(updatedItem);
        AppLogger.info('Download completed: ${item.title}');
      } else {
        throw Exception('Download failed: No output file');
      }
    } catch (e, stackTrace) {
      if (_cancelledDownloads.remove(item.id)) {
        final cancelledItem = item.copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Download cancelled by user',
        );
        await DatabaseService.instance.updateDownload(cancelledItem);
        onUpdate(cancelledItem);
        return;
      }
      final errorMessage = DownloadErrorMapper.from(e).displayText;
      final updatedItem = item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: errorMessage,
      );

      await DatabaseService.instance.updateDownload(updatedItem);
      onUpdate(updatedItem);
      AppLogger.error('Download error for ${item.title}', e, stackTrace);
      rethrow;
    } finally {
      await progressSubscription?.cancel();
      await CookieStorageService.instance.releaseMaterializedCookie(
        cookieFilePath,
      );
    }
  }

  Future<String> _getDefaultAndroidDownloadPath() async {
    final path = await _channel.invokeMethod<String>('getDownloadPath');
    if (path == null || path.isEmpty) {
      throw StateError('Android download directory is unavailable');
    }
    return path;
  }

  /// Cancel download
  Future<void> cancelDownload(int downloadId) async {
    try {
      _cancelledDownloads.add(downloadId);
      await _channel.invokeMethod('cancelDownload', {
        'downloadId': downloadId.toString(),
      });
      AppLogger.info('Download cancelled: $downloadId');
    } catch (e) {
      AppLogger.error('Failed to cancel download', e);
    }
  }
}
