class YtDlpSettings {
  // Preset System
  final String preset; // 'default', 'quality', 'speed', 'audio', 'custom'

  // Engine and update channel
  final String updateChannel; // 'stable', 'nightly', 'master'
  final String jsRuntime; // 'auto', 'deno', 'node', 'quickjs', 'bun'
  final String jsRuntimePath;
  final bool allowRemoteComponents;

  // Format Selection
  final String? selectedFormatId;
  final String? downloadType; // 'combined', 'separate', 'audio'
  final bool downloadSubtitlesEnabled; // User preference for subtitle download
  final bool downloadThumbnailEnabled; // User preference for thumbnail download

  // Download Settings
  final String downloadPath;
  final int concurrentFragments;
  final int retries;
  final int fragmentRetries;
  final int fileAccessRetries;
  final String rateLimit;
  final String throttledRate;
  final bool useAria2c;
  final String bufferSize;
  final String httpChunkSize;

  // Playlist Settings
  final bool downloadPlaylist;
  final String playlistItems;
  final bool playlistRandom;
  final bool lazyPlaylist;
  final int skipPlaylistAfterErrors;

  // Network Settings
  final String proxy;
  final int socketTimeout;
  final String sourceAddress;
  final bool forceIpv4;
  final bool forceIpv6;
  final bool enableFileUrls;

  // Authentication
  final String cookiesFile;

  // Video Selection
  final String minFilesize;
  final String maxFilesize;
  final String date;
  final String datebefore;
  final String dateafter;
  final int maxDownloads;
  final bool breakOnExisting;

  // File Settings
  final String outputTemplate;
  final bool keepFragments;
  final bool overwriteFiles;
  final bool continueDownload;
  final bool noPartFiles;
  final bool restrictFilenames;
  final bool windowsFilenames;
  final int trimFilenameLength;
  final bool writeThumbnail;
  final bool writeAllThumbnails;
  final bool writeDescription;
  final bool writeInfoJson;
  final bool writeComments;

  // Subtitle Settings
  final bool downloadSubtitles;
  final bool autoSubtitles;
  final String subtitleLanguages;
  final String subtitleFormat;
  final bool embedSubtitles;
  final String convertSubtitles;

  // Post-processing
  final bool embedThumbnail;
  final bool embedMetadata;
  final bool embedChapters;
  final bool extractAudio;
  final String audioFormat;
  final String audioQuality;
  final String remuxVideo;
  final String recodeVideo;
  final bool keepVideo;
  final bool splitChapters;
  final String convertThumbnails;

  // SponsorBlock
  final bool sponsorblockMark;
  final String sponsorblockMarkCategories;
  final bool sponsorblockRemove;
  final String sponsorblockRemoveCategories;

  // Advanced
  final bool verbose;
  final bool quiet;
  final bool noWarnings;
  final bool ignoreErrors;
  final String userAgent;
  final String minSleepInterval;
  final String maxSleepInterval;
  final String retrySleep;
  final String sleepRequests;
  final String sleepSubtitles;
  final String extractorArgs;
  final String impersonateTarget;
  final String cookiesFromBrowser;
  final String downloadArchive;
  final bool breakPerInput;
  final bool liveFromStart;
  final String waitForVideo;
  final List<String> customArgs;

  const YtDlpSettings({
    this.preset = 'default',
    this.updateChannel = 'nightly',
    this.jsRuntime = 'auto',
    this.jsRuntimePath = '',
    this.allowRemoteComponents = false,
    this.selectedFormatId,
    this.downloadType,
    this.downloadSubtitlesEnabled = false,
    this.downloadThumbnailEnabled = false,
    // Download Settings
    this.downloadPath = '',
    this.concurrentFragments = 4,
    this.retries = 10,
    this.fragmentRetries = 10,
    this.fileAccessRetries = 3,
    this.rateLimit = '',
    this.throttledRate = '',
    this.useAria2c = false,
    this.bufferSize = '',
    this.httpChunkSize = '',
    // Playlist Settings
    this.downloadPlaylist = true,
    this.playlistItems = '',
    this.playlistRandom = false,
    this.lazyPlaylist = false,
    this.skipPlaylistAfterErrors = 0,
    // Network Settings
    this.proxy = '',
    this.socketTimeout = 20,
    this.sourceAddress = '',
    this.forceIpv4 = false,
    this.forceIpv6 = false,
    this.enableFileUrls = false,
    // Authentication
    this.cookiesFile = '',
    // Video Selection
    this.minFilesize = '',
    this.maxFilesize = '',
    this.date = '',
    this.datebefore = '',
    this.dateafter = '',
    this.maxDownloads = 0,
    this.breakOnExisting = false,
    // File Settings
    this.outputTemplate = '%(title)s [%(id)s] [%(format_id)s].%(ext)s',
    this.keepFragments = false,
    this.overwriteFiles = false,
    this.continueDownload = true,
    this.noPartFiles = false,
    this.restrictFilenames = false,
    this.windowsFilenames = false,
    this.trimFilenameLength = 0,
    this.writeThumbnail = false,
    this.writeAllThumbnails = false,
    this.writeDescription = false,
    this.writeInfoJson = false,
    this.writeComments = false,
    // Subtitle Settings
    this.downloadSubtitles = false,
    this.autoSubtitles = false,
    this.subtitleLanguages = 'en',
    this.subtitleFormat = 'srt',
    this.embedSubtitles = false,
    this.convertSubtitles = '',
    // Post-processing
    this.embedThumbnail = false,
    this.embedMetadata = true,
    this.embedChapters = false,
    this.extractAudio = false,
    this.audioFormat = '',
    this.audioQuality = '5',
    this.remuxVideo = '',
    this.recodeVideo = '',
    this.keepVideo = false,
    this.splitChapters = false,
    this.convertThumbnails = '',
    // SponsorBlock
    this.sponsorblockMark = false,
    this.sponsorblockMarkCategories = '',
    this.sponsorblockRemove = false,
    this.sponsorblockRemoveCategories = '',
    // Advanced
    this.verbose = false,
    this.quiet = false,
    this.noWarnings = false,
    this.ignoreErrors = false,
    this.userAgent = '',
    this.minSleepInterval = '',
    this.maxSleepInterval = '',
    this.retrySleep = '',
    this.sleepRequests = '',
    this.sleepSubtitles = '',
    this.extractorArgs = '',
    this.impersonateTarget = '',
    this.cookiesFromBrowser = '',
    this.downloadArchive = '',
    this.breakPerInput = false,
    this.liveFromStart = false,
    this.waitForVideo = '',
    this.customArgs = const [],
  });

  YtDlpSettings copyWith({
    String? preset,
    String? updateChannel,
    String? jsRuntime,
    String? jsRuntimePath,
    bool? allowRemoteComponents,
    String? selectedFormatId,
    String? downloadType,
    bool? downloadSubtitlesEnabled,
    bool? downloadThumbnailEnabled,
    String? downloadPath,
    int? concurrentFragments,
    int? retries,
    int? fragmentRetries,
    int? fileAccessRetries,
    String? rateLimit,
    String? throttledRate,
    bool? useAria2c,
    String? bufferSize,
    String? httpChunkSize,
    bool? downloadPlaylist,
    String? playlistItems,
    bool? playlistRandom,
    bool? lazyPlaylist,
    int? skipPlaylistAfterErrors,
    String? proxy,
    int? socketTimeout,
    String? sourceAddress,
    bool? forceIpv4,
    bool? forceIpv6,
    bool? enableFileUrls,
    String? cookiesFile,
    String? minFilesize,
    String? maxFilesize,
    String? date,
    String? datebefore,
    String? dateafter,
    int? maxDownloads,
    bool? breakOnExisting,
    String? outputTemplate,
    bool? keepFragments,
    bool? overwriteFiles,
    bool? continueDownload,
    bool? noPartFiles,
    bool? restrictFilenames,
    bool? windowsFilenames,
    int? trimFilenameLength,
    bool? writeThumbnail,
    bool? writeAllThumbnails,
    bool? writeDescription,
    bool? writeInfoJson,
    bool? writeComments,
    bool? downloadSubtitles,
    bool? autoSubtitles,
    String? subtitleLanguages,
    String? subtitleFormat,
    bool? embedSubtitles,
    String? convertSubtitles,
    bool? embedThumbnail,
    bool? embedMetadata,
    bool? embedChapters,
    bool? extractAudio,
    String? audioFormat,
    String? audioQuality,
    String? remuxVideo,
    String? recodeVideo,
    bool? keepVideo,
    bool? splitChapters,
    String? convertThumbnails,
    bool? sponsorblockMark,
    String? sponsorblockMarkCategories,
    bool? sponsorblockRemove,
    String? sponsorblockRemoveCategories,
    bool? verbose,
    bool? quiet,
    bool? noWarnings,
    bool? ignoreErrors,
    String? userAgent,
    String? minSleepInterval,
    String? maxSleepInterval,
    String? retrySleep,
    String? sleepRequests,
    String? sleepSubtitles,
    String? extractorArgs,
    String? impersonateTarget,
    String? cookiesFromBrowser,
    String? downloadArchive,
    bool? breakPerInput,
    bool? liveFromStart,
    String? waitForVideo,
    List<String>? customArgs,
  }) {
    return YtDlpSettings(
      preset: preset ?? this.preset,
      updateChannel: updateChannel ?? this.updateChannel,
      jsRuntime: jsRuntime ?? this.jsRuntime,
      jsRuntimePath: jsRuntimePath ?? this.jsRuntimePath,
      allowRemoteComponents:
          allowRemoteComponents ?? this.allowRemoteComponents,
      selectedFormatId: selectedFormatId ?? this.selectedFormatId,
      downloadType: downloadType ?? this.downloadType,
      downloadSubtitlesEnabled:
          downloadSubtitlesEnabled ?? this.downloadSubtitlesEnabled,
      downloadThumbnailEnabled:
          downloadThumbnailEnabled ?? this.downloadThumbnailEnabled,
      downloadPath: downloadPath ?? this.downloadPath,
      concurrentFragments: concurrentFragments ?? this.concurrentFragments,
      retries: retries ?? this.retries,
      fragmentRetries: fragmentRetries ?? this.fragmentRetries,
      fileAccessRetries: fileAccessRetries ?? this.fileAccessRetries,
      rateLimit: rateLimit ?? this.rateLimit,
      throttledRate: throttledRate ?? this.throttledRate,
      useAria2c: useAria2c ?? this.useAria2c,
      bufferSize: bufferSize ?? this.bufferSize,
      httpChunkSize: httpChunkSize ?? this.httpChunkSize,
      downloadPlaylist: downloadPlaylist ?? this.downloadPlaylist,
      playlistItems: playlistItems ?? this.playlistItems,
      playlistRandom: playlistRandom ?? this.playlistRandom,
      lazyPlaylist: lazyPlaylist ?? this.lazyPlaylist,
      skipPlaylistAfterErrors:
          skipPlaylistAfterErrors ?? this.skipPlaylistAfterErrors,
      proxy: proxy ?? this.proxy,
      socketTimeout: socketTimeout ?? this.socketTimeout,
      sourceAddress: sourceAddress ?? this.sourceAddress,
      forceIpv4: forceIpv4 ?? this.forceIpv4,
      forceIpv6: forceIpv6 ?? this.forceIpv6,
      enableFileUrls: enableFileUrls ?? this.enableFileUrls,
      cookiesFile: cookiesFile ?? this.cookiesFile,
      minFilesize: minFilesize ?? this.minFilesize,
      maxFilesize: maxFilesize ?? this.maxFilesize,
      date: date ?? this.date,
      datebefore: datebefore ?? this.datebefore,
      dateafter: dateafter ?? this.dateafter,
      maxDownloads: maxDownloads ?? this.maxDownloads,
      breakOnExisting: breakOnExisting ?? this.breakOnExisting,
      outputTemplate: outputTemplate ?? this.outputTemplate,
      keepFragments: keepFragments ?? this.keepFragments,
      overwriteFiles: overwriteFiles ?? this.overwriteFiles,
      continueDownload: continueDownload ?? this.continueDownload,
      noPartFiles: noPartFiles ?? this.noPartFiles,
      restrictFilenames: restrictFilenames ?? this.restrictFilenames,
      windowsFilenames: windowsFilenames ?? this.windowsFilenames,
      trimFilenameLength: trimFilenameLength ?? this.trimFilenameLength,
      writeThumbnail: writeThumbnail ?? this.writeThumbnail,
      writeAllThumbnails: writeAllThumbnails ?? this.writeAllThumbnails,
      writeDescription: writeDescription ?? this.writeDescription,
      writeInfoJson: writeInfoJson ?? this.writeInfoJson,
      writeComments: writeComments ?? this.writeComments,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      autoSubtitles: autoSubtitles ?? this.autoSubtitles,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      subtitleFormat: subtitleFormat ?? this.subtitleFormat,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      convertSubtitles: convertSubtitles ?? this.convertSubtitles,
      embedThumbnail: embedThumbnail ?? this.embedThumbnail,
      embedMetadata: embedMetadata ?? this.embedMetadata,
      embedChapters: embedChapters ?? this.embedChapters,
      extractAudio: extractAudio ?? this.extractAudio,
      audioFormat: audioFormat ?? this.audioFormat,
      audioQuality: audioQuality ?? this.audioQuality,
      remuxVideo: remuxVideo ?? this.remuxVideo,
      recodeVideo: recodeVideo ?? this.recodeVideo,
      keepVideo: keepVideo ?? this.keepVideo,
      splitChapters: splitChapters ?? this.splitChapters,
      convertThumbnails: convertThumbnails ?? this.convertThumbnails,
      sponsorblockMark: sponsorblockMark ?? this.sponsorblockMark,
      sponsorblockMarkCategories:
          sponsorblockMarkCategories ?? this.sponsorblockMarkCategories,
      sponsorblockRemove: sponsorblockRemove ?? this.sponsorblockRemove,
      sponsorblockRemoveCategories:
          sponsorblockRemoveCategories ?? this.sponsorblockRemoveCategories,
      verbose: verbose ?? this.verbose,
      quiet: quiet ?? this.quiet,
      noWarnings: noWarnings ?? this.noWarnings,
      ignoreErrors: ignoreErrors ?? this.ignoreErrors,
      userAgent: userAgent ?? this.userAgent,
      minSleepInterval: minSleepInterval ?? this.minSleepInterval,
      maxSleepInterval: maxSleepInterval ?? this.maxSleepInterval,
      retrySleep: retrySleep ?? this.retrySleep,
      sleepRequests: sleepRequests ?? this.sleepRequests,
      sleepSubtitles: sleepSubtitles ?? this.sleepSubtitles,
      extractorArgs: extractorArgs ?? this.extractorArgs,
      impersonateTarget: impersonateTarget ?? this.impersonateTarget,
      cookiesFromBrowser: cookiesFromBrowser ?? this.cookiesFromBrowser,
      downloadArchive: downloadArchive ?? this.downloadArchive,
      breakPerInput: breakPerInput ?? this.breakPerInput,
      liveFromStart: liveFromStart ?? this.liveFromStart,
      waitForVideo: waitForVideo ?? this.waitForVideo,
      customArgs: customArgs ?? this.customArgs,
    );
  }

  /// Removes flags that MBNDL owns as part of the download workflow. Old
  /// settings files may still contain these fields, but they must not override
  /// playlist detection, duplicate handling, format selection, or artifacts
  /// chosen on the format screen.
  YtDlpSettings normalizedForAppPolicy() => copyWith(
    downloadPlaylist: true,
    playlistItems: '',
    playlistRandom: false,
    lazyPlaylist: false,
    skipPlaylistAfterErrors: 0,
    enableFileUrls: false,
    cookiesFile: '',
    minFilesize: '',
    maxFilesize: '',
    date: '',
    datebefore: '',
    dateafter: '',
    maxDownloads: 0,
    breakOnExisting: false,
    outputTemplate: '%(title)s [%(id)s] [%(format_id)s].%(ext)s',
    keepFragments: false,
    overwriteFiles: false,
    continueDownload: true,
    noPartFiles: false,
    restrictFilenames: false,
    windowsFilenames: false,
    trimFilenameLength: 0,
    writeThumbnail: false,
    writeAllThumbnails: false,
    writeDescription: false,
    writeInfoJson: false,
    writeComments: false,
    downloadSubtitles: false,
    embedSubtitles: false,
    convertSubtitles: '',
    embedThumbnail: false,
    embedMetadata: true,
    embedChapters: false,
    extractAudio: false,
    audioFormat: '',
    remuxVideo: '',
    recodeVideo: '',
    keepVideo: false,
    splitChapters: false,
    convertThumbnails: '',
    sponsorblockMark: false,
    sponsorblockMarkCategories: '',
    sponsorblockRemove: false,
    sponsorblockRemoveCategories: '',
    quiet: false,
    noWarnings: false,
    ignoreErrors: false,
    cookiesFromBrowser: '',
    downloadArchive: '',
    breakPerInput: false,
    liveFromStart: false,
    waitForVideo: '',
  );

  List<String> toYtDlpArgs() {
    final args = <String>['--ignore-config'];

    if (selectedFormatId != null && selectedFormatId!.isNotEmpty) {
      args.addAll(['-f', selectedFormatId!]);
    }

    if (jsRuntime != 'auto') {
      args.add('--no-js-runtimes');
      final runtime = jsRuntimePath.trim().isEmpty
          ? jsRuntime
          : '$jsRuntime:${jsRuntimePath.trim()}';
      args.addAll(['--js-runtimes', runtime]);
    }
    if (allowRemoteComponents) {
      args.addAll(['--remote-components', 'ejs:github']);
    }

    if (concurrentFragments > 1) {
      args.addAll(['-N', '$concurrentFragments']);
    }
    args.addAll(['-R', '$retries']);
    if (fragmentRetries != 10) {
      args.addAll(['--fragment-retries', '$fragmentRetries']);
    }
    if (fileAccessRetries != 3) {
      args.addAll(['--file-access-retries', '$fileAccessRetries']);
    }
    if (rateLimit.isNotEmpty) args.addAll(['-r', rateLimit]);
    if (throttledRate.isNotEmpty) {
      args.addAll(['--throttled-rate', throttledRate]);
    }
    if (bufferSize.isNotEmpty) args.addAll(['--buffer-size', bufferSize]);
    if (httpChunkSize.isNotEmpty) {
      args.addAll(['--http-chunk-size', httpChunkSize]);
    }
    if (useAria2c) {
      args.addAll([
        '--downloader',
        'aria2c',
        '--downloader-args',
        'aria2c:"-x 16 -s 16 -k 1M"',
      ]);
    }

    if (proxy.isNotEmpty) args.addAll(['--proxy', proxy]);
    args.addAll(['--socket-timeout', '$socketTimeout']);
    if (sourceAddress.isNotEmpty) {
      args.addAll(['--source-address', sourceAddress]);
    }
    if (forceIpv4) {
      args.add('-4');
    } else if (forceIpv6) {
      args.add('-6');
    }

    if (verbose) args.add('-v');
    if (userAgent.isNotEmpty) args.addAll(['--user-agent', userAgent]);
    if (minSleepInterval.isNotEmpty) {
      args.addAll(['--min-sleep-interval', minSleepInterval]);
    }
    if (minSleepInterval.isNotEmpty && maxSleepInterval.isNotEmpty) {
      args.addAll(['--max-sleep-interval', maxSleepInterval]);
    }
    if (retrySleep.isNotEmpty) args.addAll(['--retry-sleep', retrySleep]);
    if (sleepRequests.isNotEmpty) {
      args.addAll(['--sleep-requests', sleepRequests]);
    }
    if (sleepSubtitles.isNotEmpty) {
      args.addAll(['--sleep-subtitles', sleepSubtitles]);
    }
    if (extractorArgs.isNotEmpty) {
      args.addAll(['--extractor-args', extractorArgs]);
    }
    if (impersonateTarget.isNotEmpty) {
      args.addAll(['--impersonate', impersonateTarget]);
    }

    // MBNDL owns playlist detection, output naming, duplicate handling,
    // subtitles, covers and post-processing. These safe defaults cannot be
    // overridden by stale settings files.
    args.addAll(['--continue', '--no-overwrites', '--embed-metadata']);
    args.add('--no-color');
    return args;
  }

  /// Options that affect metadata extraction without selecting or downloading
  /// a format. This keeps the format picker consistent with authenticated,
  /// proxied and JavaScript-enabled downloads.
  List<String> toExtractionArgs() {
    final args = <String>['--ignore-config', '--no-color'];

    if (jsRuntime != 'auto') {
      args.add('--no-js-runtimes');
      final runtime = jsRuntimePath.trim().isEmpty
          ? jsRuntime
          : '$jsRuntime:${jsRuntimePath.trim()}';
      args.addAll(['--js-runtimes', runtime]);
    }
    if (allowRemoteComponents) {
      args.addAll(['--remote-components', 'ejs:github']);
    }
    if (proxy.isNotEmpty) args.addAll(['--proxy', proxy]);
    args.addAll(['--socket-timeout', '$socketTimeout']);
    if (sourceAddress.isNotEmpty) {
      args.addAll(['--source-address', sourceAddress]);
    }
    if (forceIpv4) {
      args.add('-4');
    } else if (forceIpv6) {
      args.add('-6');
    }
    if (retrySleep.isNotEmpty) args.addAll(['--retry-sleep', retrySleep]);
    if (sleepRequests.isNotEmpty) {
      args.addAll(['--sleep-requests', sleepRequests]);
    }
    if (userAgent.isNotEmpty) args.addAll(['--user-agent', userAgent]);
    if (extractorArgs.isNotEmpty) {
      args.addAll(['--extractor-args', extractorArgs]);
    }
    if (impersonateTarget.isNotEmpty) {
      args.addAll(['--impersonate', impersonateTarget]);
    }
    return args;
  }

  Map<String, dynamic> toJson() => {
    'preset': preset,
    'updateChannel': updateChannel,
    'jsRuntime': jsRuntime,
    'jsRuntimePath': jsRuntimePath,
    'allowRemoteComponents': allowRemoteComponents,
    'selectedFormatId': selectedFormatId,
    'downloadType': downloadType,
    'downloadSubtitlesEnabled': downloadSubtitlesEnabled,
    'downloadThumbnailEnabled': downloadThumbnailEnabled,
    'downloadPath': downloadPath,
    'concurrentFragments': concurrentFragments,
    'retries': retries,
    'fragmentRetries': fragmentRetries,
    'fileAccessRetries': fileAccessRetries,
    'rateLimit': rateLimit,
    'throttledRate': throttledRate,
    'useAria2c': useAria2c,
    'bufferSize': bufferSize,
    'httpChunkSize': httpChunkSize,
    'downloadPlaylist': downloadPlaylist,
    'playlistItems': playlistItems,
    'playlistRandom': playlistRandom,
    'lazyPlaylist': lazyPlaylist,
    'skipPlaylistAfterErrors': skipPlaylistAfterErrors,
    'proxy': proxy,
    'socketTimeout': socketTimeout,
    'sourceAddress': sourceAddress,
    'forceIpv4': forceIpv4,
    'forceIpv6': forceIpv6,
    'enableFileUrls': enableFileUrls,
    'cookiesFile': cookiesFile,
    'minFilesize': minFilesize,
    'maxFilesize': maxFilesize,
    'date': date,
    'datebefore': datebefore,
    'dateafter': dateafter,
    'maxDownloads': maxDownloads,
    'breakOnExisting': breakOnExisting,
    'outputTemplate': outputTemplate,
    'keepFragments': keepFragments,
    'overwriteFiles': overwriteFiles,
    'continueDownload': continueDownload,
    'noPartFiles': noPartFiles,
    'restrictFilenames': restrictFilenames,
    'windowsFilenames': windowsFilenames,
    'trimFilenameLength': trimFilenameLength,
    'writeThumbnail': writeThumbnail,
    'writeAllThumbnails': writeAllThumbnails,
    'writeDescription': writeDescription,
    'writeInfoJson': writeInfoJson,
    'writeComments': writeComments,
    'downloadSubtitles': downloadSubtitles,
    'autoSubtitles': autoSubtitles,
    'subtitleLanguages': subtitleLanguages,
    'subtitleFormat': subtitleFormat,
    'embedSubtitles': embedSubtitles,
    'convertSubtitles': convertSubtitles,
    'embedThumbnail': embedThumbnail,
    'embedMetadata': embedMetadata,
    'embedChapters': embedChapters,
    'extractAudio': extractAudio,
    'audioFormat': audioFormat,
    'audioQuality': audioQuality,
    'remuxVideo': remuxVideo,
    'recodeVideo': recodeVideo,
    'keepVideo': keepVideo,
    'splitChapters': splitChapters,
    'convertThumbnails': convertThumbnails,
    'sponsorblockMark': sponsorblockMark,
    'sponsorblockMarkCategories': sponsorblockMarkCategories,
    'sponsorblockRemove': sponsorblockRemove,
    'sponsorblockRemoveCategories': sponsorblockRemoveCategories,
    'verbose': verbose,
    'quiet': quiet,
    'noWarnings': noWarnings,
    'ignoreErrors': ignoreErrors,
    'userAgent': userAgent,
    'minSleepInterval': minSleepInterval,
    'maxSleepInterval': maxSleepInterval,
    'retrySleep': retrySleep,
    'sleepRequests': sleepRequests,
    'sleepSubtitles': sleepSubtitles,
    'extractorArgs': extractorArgs,
    'impersonateTarget': impersonateTarget,
    'cookiesFromBrowser': cookiesFromBrowser,
    'downloadArchive': downloadArchive,
    'breakPerInput': breakPerInput,
    'liveFromStart': liveFromStart,
    'waitForVideo': waitForVideo,
    'customArgs': customArgs,
  };

  factory YtDlpSettings.fromJson(Map<String, dynamic> json) {
    // Migration: Handle old sleepInterval format (e.g., "3-8")
    String minSleep = json['minSleepInterval'] ?? '';
    String maxSleep = json['maxSleepInterval'] ?? '';

    // If old sleepInterval exists and new ones don't
    if (minSleep.isEmpty && json['sleepInterval'] != null) {
      final oldSleepInterval = json['sleepInterval'].toString();
      if (oldSleepInterval.contains('-')) {
        // Parse range format like "3-8"
        final parts = oldSleepInterval.split('-');
        if (parts.length == 2) {
          minSleep = parts[0].trim();
          maxSleep = parts[1].trim();
        }
      } else {
        // Single value, use it as min
        minSleep = oldSleepInterval;
      }
    }

    return YtDlpSettings(
      preset: json['preset'] ?? 'default',
      updateChannel: json['updateChannel'] ?? 'nightly',
      jsRuntime: json['jsRuntime'] ?? 'auto',
      jsRuntimePath: json['jsRuntimePath'] ?? '',
      allowRemoteComponents: json['allowRemoteComponents'] ?? false,
      selectedFormatId: json['selectedFormatId'],
      downloadType: json['downloadType'],
      downloadSubtitlesEnabled: json['downloadSubtitlesEnabled'] ?? false,
      downloadThumbnailEnabled: json['downloadThumbnailEnabled'] ?? false,
      downloadPath: json['downloadPath'] ?? '',
      concurrentFragments: json['concurrentFragments'] ?? 1,
      retries: json['retries'] ?? 10,
      fragmentRetries: json['fragmentRetries'] ?? 10,
      fileAccessRetries: json['fileAccessRetries'] ?? 3,
      rateLimit: json['rateLimit'] ?? '',
      throttledRate: json['throttledRate'] ?? '',
      useAria2c: json['useAria2c'] ?? false,
      bufferSize: json['bufferSize'] ?? '',
      httpChunkSize: json['httpChunkSize'] ?? '',
      downloadPlaylist: json['downloadPlaylist'] ?? true,
      playlistItems: json['playlistItems'] ?? '',
      playlistRandom: json['playlistRandom'] ?? false,
      lazyPlaylist: json['lazyPlaylist'] ?? false,
      skipPlaylistAfterErrors: json['skipPlaylistAfterErrors'] ?? 0,
      proxy: json['proxy'] ?? '',
      socketTimeout: json['socketTimeout'] ?? 20,
      sourceAddress: json['sourceAddress'] ?? '',
      forceIpv4: json['forceIpv4'] ?? false,
      forceIpv6: json['forceIpv6'] ?? false,
      enableFileUrls: json['enableFileUrls'] ?? false,
      cookiesFile: json['cookiesFile'] ?? '',
      minFilesize: json['minFilesize'] ?? '',
      maxFilesize: json['maxFilesize'] ?? '',
      date: json['date'] ?? '',
      datebefore: json['datebefore'] ?? '',
      dateafter: json['dateafter'] ?? '',
      maxDownloads: json['maxDownloads'] ?? 0,
      breakOnExisting: json['breakOnExisting'] ?? false,
      outputTemplate:
          json['outputTemplate'] ??
          '%(title)s [%(id)s] [%(format_id)s].%(ext)s',
      keepFragments: json['keepFragments'] ?? false,
      overwriteFiles: json['overwriteFiles'] ?? false,
      continueDownload: json['continueDownload'] ?? true,
      noPartFiles: json['noPartFiles'] ?? false,
      restrictFilenames: json['restrictFilenames'] ?? false,
      windowsFilenames: json['windowsFilenames'] ?? false,
      trimFilenameLength: json['trimFilenameLength'] ?? 0,
      writeThumbnail: json['writeThumbnail'] ?? false,
      writeAllThumbnails: json['writeAllThumbnails'] ?? false,
      writeDescription: json['writeDescription'] ?? false,
      writeInfoJson: json['writeInfoJson'] ?? false,
      writeComments: json['writeComments'] ?? false,
      downloadSubtitles: json['downloadSubtitles'] ?? false,
      autoSubtitles: json['autoSubtitles'] ?? false,
      subtitleLanguages: json['subtitleLanguages'] ?? 'en',
      subtitleFormat: json['subtitleFormat'] ?? 'srt',
      embedSubtitles: json['embedSubtitles'] ?? false,
      convertSubtitles: json['convertSubtitles'] ?? '',
      embedThumbnail: json['embedThumbnail'] ?? false,
      embedMetadata: json['embedMetadata'] ?? true,
      embedChapters: json['embedChapters'] ?? false,
      extractAudio: json['extractAudio'] ?? false,
      audioFormat: json['audioFormat'] ?? '',
      audioQuality: json['audioQuality'] ?? '5',
      remuxVideo: json['remuxVideo'] ?? '',
      recodeVideo: json['recodeVideo'] ?? '',
      keepVideo: json['keepVideo'] ?? false,
      splitChapters: json['splitChapters'] ?? false,
      convertThumbnails: json['convertThumbnails'] ?? '',
      sponsorblockMark: json['sponsorblockMark'] ?? false,
      sponsorblockMarkCategories: json['sponsorblockMarkCategories'] ?? '',
      sponsorblockRemove: json['sponsorblockRemove'] ?? false,
      sponsorblockRemoveCategories: json['sponsorblockRemoveCategories'] ?? '',
      verbose: json['verbose'] ?? false,
      quiet: json['quiet'] ?? false,
      noWarnings: json['noWarnings'] ?? false,
      ignoreErrors: json['ignoreErrors'] ?? false,
      userAgent: json['userAgent'] ?? '',
      minSleepInterval: minSleep,
      maxSleepInterval: maxSleep,
      retrySleep: json['retrySleep'] ?? '',
      sleepRequests: json['sleepRequests'] ?? '',
      sleepSubtitles: json['sleepSubtitles'] ?? '',
      extractorArgs: json['extractorArgs'] ?? '',
      impersonateTarget: json['impersonateTarget'] ?? '',
      cookiesFromBrowser: json['cookiesFromBrowser'] ?? '',
      downloadArchive: json['downloadArchive'] ?? '',
      breakPerInput: json['breakPerInput'] ?? false,
      liveFromStart: json['liveFromStart'] ?? false,
      waitForVideo: json['waitForVideo'] ?? '',
      customArgs: (json['customArgs'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  // Preset factory methods
  factory YtDlpSettings.defaultPreset() => const YtDlpSettings(
    preset: 'default',
    concurrentFragments: 4,
    retries: 10,
    fragmentRetries: 10,
    fileAccessRetries: 3,
    socketTimeout: 20,
  );

  factory YtDlpSettings.speedPreset() => const YtDlpSettings(
    preset: 'speed',
    // Keep the built-in preset portable. The optional aria2c engine is
    // available on Android, but it is not bundled with the Windows release.
    useAria2c: false,
    concurrentFragments: 8,
    retries: 10,
    fragmentRetries: 10,
    socketTimeout: 20,
  );

  factory YtDlpSettings.resilientPreset() => const YtDlpSettings(
    preset: 'resilient',
    useAria2c: false,
    concurrentFragments: 1,
    retries: 30,
    fragmentRetries: 30,
    fileAccessRetries: 10,
    socketTimeout: 60,
    retrySleep: 'http:exp=1:20',
  );

  factory YtDlpSettings.gentleYouTubePreset() => const YtDlpSettings(
    preset: 'gentle_youtube',
    concurrentFragments: 1,
    retries: 10,
    fragmentRetries: 10,
    fileAccessRetries: 3,
    socketTimeout: 30,
    minSleepInterval: '5',
    maxSleepInterval: '10',
    sleepRequests: '1',
  );

  factory YtDlpSettings.limitedBandwidthPreset() => const YtDlpSettings(
    preset: 'limited_bandwidth',
    concurrentFragments: 1,
    retries: 20,
    fragmentRetries: 20,
    fileAccessRetries: 5,
    rateLimit: '2M',
    socketTimeout: 60,
  );
}
