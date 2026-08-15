import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../shared/models/download_item.dart';
import '../../shared/models/media_source.dart';
import '../../shared/models/video_format.dart';
import '../../shared/utils/media_url_classifier.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
import '../logger/app_logger.dart';
import '../logger/log_sanitizer.dart';
import '../network/windows_system_proxy_service.dart';
import '../database/database_service.dart';
import '../storage/cookie_storage_service.dart';
import 'ytdlp_manager.dart';
import 'ffmpeg_manager.dart';
import 'android_ytdlp_service.dart';
import 'download_error_mapper.dart';
import 'media_source_resolver.dart';

class DownloadService {
  static DownloadService? _instance;
  static DownloadService get instance {
    _instance ??= DownloadService._();
    return _instance!;
  }

  DownloadService._();

  String? _ytDlpPath;
  String? _androidCheckedChannel;
  List<String>? _detectedRuntimeArgs;
  String? _cachedExtractionKey;
  Map<String, dynamic>? _cachedExtraction;
  final Map<String, _ResolvedSourceProbe> _sourceProbes = {};
  final Map<int, Process> _activeDownloads = {};
  final Set<int> _cancelledDownloads = {};

  Future<void> initialize() async {
    // Android uses the embedded native yt-dlp toolchain.
    if (Platform.isAndroid) {
      try {
        await AndroidYtDlpService.instance.initialize();
        AppLogger.info('Android yt-dlp service initialized');
        return;
      } catch (e) {
        AppLogger.error('Failed to initialize Android yt-dlp service', e);
        rethrow;
      }
    }

    if (Platform.isIOS) {
      throw UnsupportedError('iOS downloads are not implemented in this build');
    }

    // A Windows release contains both required toolchains. Copy them into the
    // per-user writable directory before looking for system-wide fallbacks.
    // This is offline and replaces the old first-run download page.
    if (Platform.isWindows) {
      final ready = await Future.wait([
        YtDlpManager.instance.ensureBundledBootstrapReady(),
        FFmpegManager.instance.ensureBundledBootstrapReady(),
      ]);
      if (!ready.every((value) => value)) {
        AppLogger.warning(
          'One or more bundled Windows download tools could not be prepared',
        );
      }
    }

    // For desktop platforms, use yt-dlp binary
    // Try to get yt-dlp path from YtDlpManager (AppData)
    _ytDlpPath = await YtDlpManager.instance.getYtDlpPath();

    if (_ytDlpPath != null) {
      AppLogger.info('yt-dlp found in AppData: $_ytDlpPath');
      return;
    }

    // If not in AppData, check system PATH
    try {
      final result = await Process.run('yt-dlp', ['--version']);
      if (result.exitCode == 0) {
        _ytDlpPath = 'yt-dlp';
        AppLogger.info(
          'yt-dlp found in system PATH: version ${result.stdout.toString().trim()}',
        );
        return;
      }
    } catch (e) {
      AppLogger.warning('yt-dlp not found in system PATH');
    }

    // Not found - will be downloaded on first use
    AppLogger.warning('yt-dlp not found. Will be downloaded on first use.');
  }

  bool get isYtDlpAvailable => _ytDlpPath != null;

  Future<ResolvedMediaSource> resolveMediaSource(String url) =>
      MediaSourceResolver.instance.resolve(url);

  Future<bool> ensureFFmpegReady({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) {
    return FFmpegManager.instance.ensureFFmpegReady(
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// Ensure yt-dlp is ready before use
  Future<bool> ensureYtDlpReady({
    Function(double)? onProgress,
    Function(String)? onStatus,
    String updateChannel = 'nightly',
  }) async {
    // Android bundles yt-dlp and QuickJS through youtubedl-android.
    if (Platform.isAndroid) {
      try {
        onStatus?.call('Checking yt-dlp...');
        final isInitialized = await AndroidYtDlpService.instance
            .isInitialized();
        if (!isInitialized) {
          onStatus?.call('Initializing yt-dlp...');
          await AndroidYtDlpService.instance.initialize();
        }

        if (_androidCheckedChannel != updateChannel) {
          onStatus?.call('Checking the $updateChannel channel...');
          final updated = await AndroidYtDlpService.instance
              .updateYtDlpFromChannel(updateChannel);
          _androidCheckedChannel = updateChannel;
          if (!updated) {
            AppLogger.warning(
              'Android yt-dlp update failed; continuing with bundled version',
            );
          }
        }
        onProgress?.call(100.0);
        return true;
      } catch (e) {
        AppLogger.error('Failed to initialize Android yt-dlp', e);
        return false;
      }
    }

    if (Platform.isIOS) return false;

    // Verify an existing binary, then let the manager compare it with the
    // selected official channel. A failed network check does not invalidate a
    // working local executable.
    var verifiedExisting = false;
    if (_ytDlpPath != null) {
      final file = File(_ytDlpPath!);
      if (_ytDlpPath == 'yt-dlp' || await file.exists()) {
        // Quick check - just verify it works
        try {
          final result = await Process.run(_ytDlpPath!, [
            '--version',
          ]).timeout(const Duration(seconds: 5));
          if (result.exitCode == 0) {
            verifiedExisting = true;
            AppLogger.debug('Existing yt-dlp executable is healthy');
          }
        } catch (e) {
          AppLogger.warning('yt-dlp verification failed: $e');
        }
      }
    }

    // Install, repair, or update the app-managed executable.
    onStatus?.call('Preparing yt-dlp...');
    final success = await YtDlpManager.instance.ensureYtDlpReady(
      onProgress: onProgress,
      onStatus: onStatus,
      channel: updateChannel,
    );

    if (success) {
      _ytDlpPath = await YtDlpManager.instance.getYtDlpPath();
      return _ytDlpPath != null;
    }

    return verifiedExisting;
  }

  Future<Map<String, dynamic>> extractVideoInfo(
    String url, {
    YtDlpSettings? settings,
  }) async {
    final source = await resolveMediaSource(url);

    // Use the native Android implementation.
    if (Platform.isAndroid) {
      if (source.provider == MediaProvider.spotify) {
        final probe = await _probeSpotifySource(source, settings);
        return _decorateSourceInfo(probe.androidInfo!, source);
      }
      final info = await AndroidYtDlpService.instance.extractVideoInfo(
        source.effectiveUrl,
        settings: settings,
      );
      return _decorateSourceInfo(info, source);
    }

    // Desktop implementation
    if (_ytDlpPath == null) {
      throw Exception('yt-dlp is not available');
    }

    AppLogger.info(
      'Extracting ${source.provider.displayName} media information',
    );

    try {
      final probe = source.provider == MediaProvider.spotify
          ? await _probeSpotifySource(source, settings)
          : null;
      final jsonData =
          probe?.desktopData ??
          await _extractDesktopData(source.effectiveUrl, settings);
      final representative = _representativeEntry(jsonData);
      final isPlaylist = jsonData['_type'] == 'playlist';
      AppLogger.info('Video info extracted: ${jsonData['title']}');

      return _decorateSourceInfo({
        'title': jsonData['title'] ?? representative['title'] ?? 'Unknown',
        'id': representative['id'],
        'thumbnail': representative['thumbnail'],
        'duration': representative['duration'],
        'uploader': representative['uploader'],
        'filesize':
            representative['filesize'] ?? representative['filesize_approx'],
        'isPlaylist': isPlaylist,
        'playlistCount':
            jsonData['playlist_count'] ??
            (jsonData['entries'] as List<dynamic>?)?.length,
      }, source);
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
    final source = await resolveMediaSource(url);

    if (source.provider == MediaProvider.spotify) {
      AppLogger.info('Fetching Spotify formats');
      final probe = await _probeSpotifySource(source, settings);
      AppLogger.info('Found ${probe.formats.length} Spotify formats');
      return List<VideoFormat>.of(probe.formats);
    }

    // Use the native Android implementation.
    if (Platform.isAndroid) {
      return AndroidYtDlpService.instance.getAvailableFormats(
        source.effectiveUrl,
        settings: settings,
      );
    }

    // Desktop implementation
    if (_ytDlpPath == null) {
      throw Exception('yt-dlp is not available');
    }

    AppLogger.info('Fetching ${source.provider.displayName} formats');

    try {
      final jsonData = await _extractDesktopData(source.effectiveUrl, settings);
      final formats = _formatsFromData(jsonData);

      if (formats.isEmpty) {
        AppLogger.warning(
          'No formats found for ${source.provider.displayName}',
        );
        return [];
      }

      AppLogger.info('Found ${formats.length} formats');
      return formats;
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching formats', e, stackTrace);
      rethrow;
    }
  }

  Future<_ResolvedSourceProbe> _probeSpotifySource(
    ResolvedMediaSource source,
    YtDlpSettings? settings,
  ) async {
    final cached = _sourceProbes[source.originalUrl];
    if (cached != null) return cached;

    Object? lastError;
    StackTrace? lastStackTrace;
    final candidates = source.candidateUrls;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      try {
        late final _ResolvedSourceProbe probe;
        if (Platform.isAndroid) {
          final info = await AndroidYtDlpService.instance.extractVideoInfo(
            candidate,
            settings: settings,
          );
          final formats = await AndroidYtDlpService.instance
              .getAvailableFormats(candidate, settings: settings);
          if (formats.isEmpty) {
            AppLogger.warning(
              'Spotify match ${index + 1}/${candidates.length} returned no '
              'formats',
            );
            continue;
          }
          probe = _ResolvedSourceProbe(
            effectiveUrl: _youtubePlaybackUrl(
              id: info['id'],
              fallback: candidate,
            ),
            formats: formats,
            androidInfo: info,
          );
        } else {
          if (_ytDlpPath == null) {
            throw StateError('yt-dlp is not available');
          }
          final data = await _extractDesktopData(candidate, settings);
          final formats = _formatsFromData(data);
          if (formats.isEmpty) {
            AppLogger.warning(
              'Spotify match ${index + 1}/${candidates.length} returned no '
              'formats',
            );
            continue;
          }
          final representative = _representativeEntry(data);
          probe = _ResolvedSourceProbe(
            effectiveUrl: _youtubePlaybackUrl(
              id: representative['id'],
              webpageUrl: representative['webpage_url'],
              fallback: candidate,
            ),
            formats: formats,
            desktopData: data,
          );
        }

        _sourceProbes[source.originalUrl] = probe;
        AppLogger.info(
          index == 0
              ? 'Matched Spotify metadata using the precise search'
              : 'Matched Spotify metadata using title fallback '
                    '${index + 1}/${candidates.length}',
        );
        return probe;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        AppLogger.warning(
          'Spotify match ${index + 1}/${candidates.length} failed: $error',
        );
      }
    }

    if (lastError != null && lastStackTrace != null) {
      AppLogger.error(
        'Spotify matching exhausted every search candidate',
        lastError,
        lastStackTrace,
      );
    }
    throw StateError(
      'Spotify match unavailable: metadata loaded, but no playable YouTube '
      'audio source was found.',
    );
  }

  List<VideoFormat> _formatsFromData(Map<String, dynamic> data) {
    final rawFormats = _representativeEntry(data)['formats'];
    if (rawFormats is! List) return const [];
    return rawFormats
        .whereType<Map>()
        .map(
          (format) => VideoFormat.fromJson(Map<String, dynamic>.from(format)),
        )
        .toList(growable: false);
  }

  String _youtubePlaybackUrl({
    required Object? id,
    required String fallback,
    Object? webpageUrl,
  }) {
    final page = webpageUrl?.toString().trim() ?? '';
    if (page.startsWith('https://') || page.startsWith('http://')) return page;
    final videoId = id?.toString().trim() ?? '';
    if (videoId.isEmpty) return fallback;
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  Map<String, dynamic> _decorateSourceInfo(
    Map<String, dynamic> info,
    ResolvedMediaSource source,
  ) {
    final first = source.tracks.isEmpty ? null : source.tracks.first;
    return {
      ...info,
      if (source.title?.isNotEmpty == true || first != null)
        'title': source.title ?? first!.title,
      if (source.thumbnail?.isNotEmpty == true || first?.thumbnail != null)
        'thumbnail': source.thumbnail ?? first?.thumbnail,
      'sourceProvider': source.provider.name,
      'sourceProviderLabel': source.provider.displayName,
      if (source.notice != null) 'sourceNotice': source.notice,
      if (source.isCollection)
        'catalogTracks': source.tracks.map((track) => track.toJson()).toList(),
      if (source.provider == MediaProvider.spotify)
        'isPlaylist': source.isCollection,
      if (source.provider == MediaProvider.spotify)
        'playlistCount': source.tracks.length,
    };
  }

  Future<Map<String, dynamic>> _extractDesktopData(
    String url,
    YtDlpSettings? settings,
  ) async {
    final args = <String>[
      ...(settings?.toExtractionArgs() ??
          const ['--ignore-config', '--no-color']),
    ];
    if (!args.contains('--js-runtimes') && !args.contains('--no-js-runtimes')) {
      args.addAll(await _detectJsRuntime());
    }
    if (!args.contains('--proxy')) {
      args.addAll(await WindowsSystemProxyService.instance.ytDlpArgsFor(url));
    }

    final selectedCookie = await CookieStorageService.instance
        .materializeSelectedCookieForUrl(url);
    if (selectedCookie != null && selectedCookie.isNotEmpty) {
      args.addAll(['--cookies', selectedCookie]);
    }

    try {
      final cacheKey = '$url\u0000${args.join('\u0000')}';
      if (_cachedExtractionKey == cacheKey && _cachedExtraction != null) {
        return _cachedExtraction!;
      }

      final playlistInspection = MediaUrlClassifier.isLikelyPlaylistUrl(url);
      final result = await Process.run(_ytDlpPath!, [
        ...args,
        '--dump-single-json',
        '--skip-download',
        if (playlistInspection) ...[
          '--playlist-end',
          '1',
        ] else ...[
          '--no-playlist',
        ],
        url,
      ]);
      if (result.exitCode != 0) {
        final error = result.stderr.toString().trim();
        throw Exception(error.isEmpty ? 'yt-dlp extraction failed' : error);
      }

      final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      _cachedExtractionKey = cacheKey;
      _cachedExtraction = data;
      return data;
    } finally {
      await CookieStorageService.instance.releaseMaterializedCookie(
        selectedCookie,
      );
    }
  }

  Map<String, dynamic> _representativeEntry(Map<String, dynamic> data) {
    final entries = data['entries'] as List<dynamic>?;
    if (entries == null || entries.isEmpty) return data;
    for (final entry in entries) {
      if (entry is Map) return Map<String, dynamic>.from(entry);
    }
    return data;
  }

  Future<List<String>> _detectJsRuntime() async {
    if (_detectedRuntimeArgs != null) return _detectedRuntimeArgs!;

    for (final runtime in const ['deno', 'node', 'qjs', 'bun']) {
      try {
        final result = await Process.run(runtime, const [
          '--version',
        ]).timeout(const Duration(seconds: 3));
        if (result.exitCode == 0) {
          final ytDlpName = runtime == 'qjs' ? 'quickjs' : runtime;
          _detectedRuntimeArgs = ['--js-runtimes', ytDlpName];
          AppLogger.info('Using JavaScript runtime: $ytDlpName');
          return _detectedRuntimeArgs!;
        }
      } catch (_) {
        // Try the next supported runtime.
      }
    }

    _detectedRuntimeArgs = const [];
    AppLogger.warning(
      'No desktop JavaScript runtime detected; YouTube formats may be limited',
    );
    return _detectedRuntimeArgs!;
  }

  /// Group formats by type (combined, video-only, audio-only)
  Map<String, List<VideoFormat>> groupFormats(List<VideoFormat> formats) {
    final combined = <VideoFormat>[];
    final videoOnly = <VideoFormat>[];
    final audioOnly = <VideoFormat>[];

    for (final format in formats) {
      if (format.hasVideo && format.hasAudio) {
        combined.add(format);
      } else if (format.hasVideo) {
        videoOnly.add(format);
      } else if (format.hasAudio) {
        audioOnly.add(format);
      }
    }

    // Sort by quality (height) descending
    combined.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    videoOnly.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    audioOnly.sort((a, b) => (b.abr ?? 0).compareTo(a.abr ?? 0));

    return {'combined': combined, 'video': videoOnly, 'audio': audioOnly};
  }

  Future<void> startDownload({
    required DownloadItem item,
    required YtDlpSettings settings,
    required Function(DownloadItem) onUpdate,
  }) async {
    final source = await resolveMediaSource(item.url);
    final downloadUrl = source.provider == MediaProvider.spotify
        ? (await _probeSpotifySource(source, settings)).effectiveUrl
        : source.effectiveUrl;

    // Use the native Android implementation.
    if (Platform.isAndroid) {
      return await AndroidYtDlpService.instance.startDownload(
        item: item,
        settings: settings,
        onUpdate: onUpdate,
        effectiveUrl: downloadUrl,
      );
    }

    // Desktop implementation
    if (_ytDlpPath == null) {
      throw Exception('yt-dlp is not available');
    }

    if (item.id == null) {
      throw Exception('Download item must have an ID');
    }

    // Determine base output directory
    String baseOutputDir;
    if (settings.downloadPath.isNotEmpty) {
      baseOutputDir = settings.downloadPath;
    } else {
      // Use default path based on platform
      if (Platform.isWindows) {
        final downloadsDir = await getDownloadsDirectory();
        final root =
            downloadsDir?.path ??
            (await getApplicationDocumentsDirectory()).path;
        baseOutputDir = '$root${Platform.pathSeparator}MBNDL';
      } else {
        final downloadsDir = await getDownloadsDirectory();
        baseOutputDir = downloadsDir == null
            ? (await getApplicationDocumentsDirectory()).path
            : '${downloadsDir.path}${Platform.pathSeparator}MBNDL';
      }
    }

    // Ensure base directory exists
    final dir = Directory(baseOutputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      AppLogger.info('Created base download directory: $baseOutputDir');
    }

    // Create subdirectories for organized storage
    final tempDir = Directory('$baseOutputDir${Platform.pathSeparator}temp');
    final videoDir = Directory('$baseOutputDir${Platform.pathSeparator}Video');
    final audioDir = Directory('$baseOutputDir${Platform.pathSeparator}Audio');
    final coverDir = Directory('$baseOutputDir${Platform.pathSeparator}Cover');

    for (final subDir in [tempDir, videoDir, audioDir, coverDir]) {
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
        AppLogger.info('Created directory: ${subDir.path}');
      }
    }

    // Determine download type from settings
    final downloadType = settings.downloadType ?? 'combined';
    final isAudioOnly = downloadType == 'audio' || settings.extractAudio;
    final selectedFormatId = settings.selectedFormatId ?? '';
    final shouldMergeStreams =
        !isAudioOnly && selectedFormatId.split('+').length == 2;

    // Build yt-dlp args with paths template for organized file storage
    final args = <String>[
      ...settings.toYtDlpArgs(),
      if (shouldMergeStreams) ...[
        // yt-dlp performs the video+audio download and FFmpeg merge in this
        // single invocation. Never retain the two intermediate streams.
        '--no-keep-video',
        '--no-keep-fragments',
      ],
      if (Platform.isWindows) '--windows-filenames',
      '--trim-filenames',
      '180',
      '--newline',
      '--progress',
      '--progress-template',
      'download:MBN_PROGRESS:%(progress._percent_str)s',
      '--print',
      'after_move:MBN_FILE:%(filepath)j',

      // Paths configuration using yt-dlp's -P option for organized storage
      // temp: temporary files during download
      '-P', 'temp:${tempDir.path}',
    ];

    // Add FFmpeg location if available
    final ffmpegPath = await FFmpegManager.instance.getFFmpegPath();
    if (ffmpegPath != null) {
      // Get the directory containing ffmpeg
      final ffmpegDir = File(ffmpegPath).parent.path;
      args.addAll(['--ffmpeg-location', ffmpegDir]);
      AppLogger.info('Using FFmpeg location: $ffmpegDir');
    }

    String? cookieFilePath;
    try {
      // Materialize the selected YouTube secret inside the guarded scope so
      // every early setup failure still removes the temporary plaintext file.
      cookieFilePath = await CookieStorageService.instance
          .materializeSelectedCookieForUrl(downloadUrl);

      if (isAudioOnly) {
        // Audio-only goes to Audio folder
        args.addAll([
          '-P',
          'home:${audioDir.path}',
          '-o',
          settings.outputTemplate,
        ]);
      } else {
        // Regular video goes to Video folder
        args.addAll([
          '-P',
          'home:${videoDir.path}',
          '-o',
          settings.outputTemplate,
        ]);
      }

      if (settings.downloadSubtitlesEnabled) {
        args.addAll([
          '--write-subs',
          if (settings.autoSubtitles) '--write-auto-subs',
          '--sub-langs', settings.subtitleLanguages,
          '--sub-format', 'best',
          '--convert-subs', settings.subtitleFormat,
          '-P', 'subtitle:${videoDir.path}', // Save subtitles with video
        ]);
      }

      if (settings.downloadThumbnailEnabled) {
        args.addAll([
          '--write-thumbnail',
          '--convert-thumbnails', 'jpg',
          '-P', 'thumbnail:${coverDir.path}', // Save covers in Cover folder
        ]);
      }

      args.add(downloadUrl);

      // Add runtime, cookies and FFmpeg immediately before the URL so all
      // modes, including Smart Merge, share the same engine configuration.
      final sharedArgs = <String>[];
      if (!args.contains('--js-runtimes') &&
          !args.contains('--no-js-runtimes')) {
        sharedArgs.addAll(await _detectJsRuntime());
      }
      if (ffmpegPath != null) {
        sharedArgs.addAll(['--ffmpeg-location', File(ffmpegPath).parent.path]);
      }
      if (cookieFilePath != null) {
        sharedArgs.addAll(['--cookies', cookieFilePath]);
      }
      if (!args.contains('--proxy')) {
        sharedArgs.addAll(
          await WindowsSystemProxyService.instance.ytDlpArgsFor(downloadUrl),
        );
      }
      final urlIndex = args.lastIndexOf(downloadUrl);
      if (urlIndex >= 0) {
        args.insertAll(urlIndex, sharedArgs);
      } else {
        args.addAll([...sharedArgs, downloadUrl]);
      }

      AppLogger.info('Starting download for: ${item.title}');
      AppLogger.info('Base output directory: $baseOutputDir');
      AppLogger.debug('yt-dlp args: ${LogSanitizer.commandArgs(args)}');

      // Prepare environment with ffmpeg path
      Map<String, String>? environment;
      if (ffmpegPath != null) {
        final ffmpegDir = File(ffmpegPath).parent.path;
        final currentPath = Platform.environment['PATH'] ?? '';
        environment = {
          ...Platform.environment,
          'PATH': '$ffmpegDir${Platform.isWindows ? ';' : ':'}$currentPath',
        };
        AppLogger.info('Added FFmpeg directory to PATH: $ffmpegDir');
      }

      final downloadStartedAt = DateTime.now();
      final process = await Process.start(
        _ytDlpPath!,
        args,
        environment: environment,
      );
      _activeDownloads[item.id!] = process;

      // Update status to downloading
      var updatedItem = item.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
      await DatabaseService.instance.updateDownload(updatedItem);
      onUpdate(updatedItem);

      final progressRegex = RegExp(
        r'^(?:MBN_PROGRESS:\s*|\[download\]\s+)(\d+\.?\d*)%',
      );
      final filenameRegex = RegExp(r'\[download\] Destination: (.+)');
      String? filePath;
      final stderrLines = <String>[];

      // Use systemEncoding decoder for Windows to handle Unicode properly
      final textDecoder = Platform.isWindows
          ? systemEncoding.decoder
          : const Utf8Decoder(allowMalformed: true);

      // Handle stdout with proper encoding
      process.stdout
          .transform(textDecoder)
          .transform(const LineSplitter())
          .listen((line) {
            AppLogger.toolOutput('yt-dlp', line, fallback: LogLevel.trace);

            // Extract progress
            final progressMatch = progressRegex.firstMatch(line);
            if (progressMatch != null) {
              final progress = double.tryParse(progressMatch.group(1)!) ?? 0.0;
              updatedItem = updatedItem.copyWith(progress: progress);
              onUpdate(updatedItem);
            }

            // Extract filename from [download] Destination line or --print output
            if (line.startsWith('MBN_FILE:')) {
              final encodedPath = line.substring('MBN_FILE:'.length).trim();
              try {
                filePath = jsonDecode(encodedPath) as String;
              } catch (_) {
                filePath = encodedPath.replaceAll('"', '');
              }
              AppLogger.debug('Final file path: $filePath');
            } else {
              final filenameMatch = filenameRegex.firstMatch(line);
              if (filenameMatch != null) {
                filePath = filenameMatch.group(1);
                AppLogger.debug('Download destination: $filePath');
              }
            }
          });

      // Handle stderr with proper encoding
      process.stderr
          .transform(textDecoder)
          .transform(const LineSplitter())
          .listen((line) {
            AppLogger.toolOutput(
              'yt-dlp stderr',
              line,
              fallback: LogLevel.warning,
            );
            stderrLines.add(line);
            if (stderrLines.length > 80) stderrLines.removeAt(0);
          });

      // Wait for completion
      final exitCode = await process.exitCode;
      _activeDownloads.remove(item.id);

      if (_cancelledDownloads.remove(item.id)) {
        updatedItem = updatedItem.copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Download cancelled by user',
        );
        await DatabaseService.instance.updateDownload(updatedItem);
        onUpdate(updatedItem);
        return;
      }

      if (exitCode == 0) {
        // Download successful
        File? downloadedFile;
        int? fileSize;

        // Search for the downloaded file
        if (filePath != null) {
          downloadedFile = File(filePath!);
        }

        // If file doesn't exist or path is null, search for it in the directory
        // This handles Unicode filenames that may not be captured correctly
        if (downloadedFile == null || !await downloadedFile.exists()) {
          if (filePath != null) {
            AppLogger.warning('File not found at captured path: $filePath');
          } else {
            AppLogger.warning(
              'No file path captured from yt-dlp, searching directory...',
            );
          }

          // Determine which directory to search in
          Directory searchDir;
          if (isAudioOnly) {
            searchDir = audioDir;
          } else {
            searchDir = videoDir;
          }

          if (await searchDir.exists()) {
            // Get all files in the directory
            final files = await searchDir
                .list()
                .where((e) => e is File)
                .toList();

            // Find the most recently modified file
            File? mostRecent;
            DateTime? mostRecentTime;

            for (final entity in files) {
              if (entity is File) {
                final stat = await entity.stat();
                if (mostRecentTime == null ||
                    stat.modified.isAfter(mostRecentTime)) {
                  mostRecentTime = stat.modified;
                  mostRecent = entity;
                }
              }
            }

            if (mostRecent != null) {
              downloadedFile = mostRecent;
              filePath = mostRecent.path;
              AppLogger.info('Found downloaded file by search: $filePath');
            }
          }
        }

        if (downloadedFile != null && await downloadedFile.exists()) {
          fileSize = await downloadedFile.length();
        }

        final artifacts = await _discoverArtifacts(
          primaryFile: downloadedFile,
          directories: [videoDir, audioDir, coverDir],
          startedAt: downloadStartedAt,
        );

        updatedItem = updatedItem.copyWith(
          status: DownloadStatus.completed,
          progress: 100.0,
          filePath: filePath,
          fileSize: fileSize,
          completedAt: DateTime.now(),
          coverPath: artifacts.coverPath,
          subtitlePaths: artifacts.subtitlePaths,
          relatedFilePaths: artifacts.relatedPaths,
          clearErrorMessage: true,
          clearCurrentPhase: true,
        );

        await DatabaseService.instance.updateDownload(updatedItem);
        onUpdate(updatedItem);
        AppLogger.info('Download completed successfully: ${item.title}');
      } else {
        // Download failed
        final rawError = stderrLines.isEmpty
            ? 'yt-dlp exited with code $exitCode'
            : stderrLines.join('\n');
        final friendly = DownloadErrorMapper.fromText(rawError);
        updatedItem = updatedItem.copyWith(
          status: DownloadStatus.failed,
          errorMessage: friendly.displayText,
        );

        await DatabaseService.instance.updateDownload(updatedItem);
        onUpdate(updatedItem);
        AppLogger.error('Download failed: ${item.title}');
        throw Exception(rawError);
      }
    } catch (e, stackTrace) {
      _activeDownloads.remove(item.id);

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
      await CookieStorageService.instance.releaseMaterializedCookie(
        cookieFilePath,
      );
    }
  }

  Future<void> cancelDownload(int downloadId) async {
    // Use the native Android implementation.
    if (Platform.isAndroid) {
      return await AndroidYtDlpService.instance.cancelDownload(downloadId);
    }

    // Desktop implementation
    final process = _activeDownloads[downloadId];
    if (process != null) {
      _cancelledDownloads.add(downloadId);
      process.kill();
      _activeDownloads.remove(downloadId);
      AppLogger.info('Download cancelled: $downloadId');
    }
  }

  Future<void> retryDownload({
    required DownloadItem item,
    required YtDlpSettings settings,
    required Function(DownloadItem) onUpdate,
  }) async {
    AppLogger.info('Retrying download: ${item.title}');

    final updatedItem = item.copyWith(
      status: DownloadStatus.pending,
      progress: 0.0,
      clearErrorMessage: true,
      clearCurrentPhase: true,
    );

    await DatabaseService.instance.updateDownload(updatedItem);
    onUpdate(updatedItem);

    await startDownload(
      item: updatedItem,
      settings: settings,
      onUpdate: onUpdate,
    );
  }

  bool isDownloading(int? downloadId) {
    if (downloadId == null) return false;
    return _activeDownloads.containsKey(downloadId);
  }

  Future<_DownloadedArtifacts> _discoverArtifacts({
    required File? primaryFile,
    required List<Directory> directories,
    required DateTime startedAt,
  }) async {
    final related = <String>[];
    final subtitles = <String>[];
    String? cover;
    final primaryPath = primaryFile?.absolute.path;
    final primaryBase = primaryFile == null
        ? null
        : p.basenameWithoutExtension(primaryFile.path);
    final earliest = startedAt.subtract(const Duration(seconds: 5));
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.avif'};
    const subtitleExtensions = {
      '.srt',
      '.vtt',
      '.ass',
      '.ssa',
      '.lrc',
      '.ttml',
    };

    for (final directory in directories) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list()) {
        if (entity is! File || entity.absolute.path == primaryPath) continue;
        final extension = p.extension(entity.path).toLowerCase();
        if (extension == '.part' || extension == '.ytdl') continue;
        final stat = await entity.stat();
        final base = p.basenameWithoutExtension(entity.path);
        final belongsToDownload = primaryBase == null
            ? stat.modified.isAfter(earliest)
            : base == primaryBase ||
                  base.startsWith('$primaryBase.') ||
                  primaryBase.startsWith('$base.');
        if (!belongsToDownload || stat.modified.isBefore(earliest)) continue;

        related.add(entity.path);
        if (imageExtensions.contains(extension)) cover ??= entity.path;
        if (subtitleExtensions.contains(extension)) subtitles.add(entity.path);
      }
    }

    return _DownloadedArtifacts(
      coverPath: cover,
      subtitlePaths: subtitles,
      relatedPaths: related,
    );
  }
}

class _DownloadedArtifacts {
  const _DownloadedArtifacts({
    required this.coverPath,
    required this.subtitlePaths,
    required this.relatedPaths,
  });

  final String? coverPath;
  final List<String> subtitlePaths;
  final List<String> relatedPaths;
}

class _ResolvedSourceProbe {
  const _ResolvedSourceProbe({
    required this.effectiveUrl,
    required this.formats,
    this.androidInfo,
    this.desktopData,
  });

  final String effectiveUrl;
  final List<VideoFormat> formats;
  final Map<String, dynamic>? androidInfo;
  final Map<String, dynamic>? desktopData;
}
