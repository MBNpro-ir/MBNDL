import 'dart:convert';

enum DownloadStatus {
  pending,
  processing,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadItem {
  final int? id;
  final String url;
  final String title;
  final String? thumbnail;
  final DownloadStatus status;
  final String? filePath;
  final int? fileSize;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double progress;

  // Enhanced metadata
  final String? formatId; // e.g., "299+140"
  final String? videoCodec; // e.g., "avc1.64001F"
  final String? audioCodec; // e.g., "mp4a.40.2"
  final String? fileExtension; // e.g., "mp4", "webm"
  final String? quality; // e.g., "1080p", "720p"
  final String? downloadType; // "video", "audio", "combined", "separate"
  final String? currentPhase; // "video", "audio", "cover", "subtitle"
  final String? formatLabel;
  final String? coverPath;
  final List<String> subtitlePaths;
  final List<String> relatedFilePaths;
  final List<String> publicUris;

  DownloadItem({
    this.id,
    required this.url,
    required this.title,
    this.thumbnail,
    required this.status,
    this.filePath,
    this.fileSize,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.progress = 0.0,
    this.formatId,
    this.videoCodec,
    this.audioCodec,
    this.fileExtension,
    this.quality,
    this.downloadType,
    this.currentPhase,
    this.formatLabel,
    this.coverPath,
    this.subtitlePaths = const [],
    this.relatedFilePaths = const [],
    this.publicUris = const [],
  });

  DownloadItem copyWith({
    int? id,
    String? url,
    String? title,
    String? thumbnail,
    DownloadStatus? status,
    String? filePath,
    int? fileSize,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    double? progress,
    String? formatId,
    String? videoCodec,
    String? audioCodec,
    String? fileExtension,
    String? quality,
    String? downloadType,
    String? currentPhase,
    String? formatLabel,
    String? coverPath,
    List<String>? subtitlePaths,
    List<String>? relatedFilePaths,
    List<String>? publicUris,
    bool clearErrorMessage = false,
    bool clearCurrentPhase = false,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      progress: progress ?? this.progress,
      formatId: formatId ?? this.formatId,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      fileExtension: fileExtension ?? this.fileExtension,
      quality: quality ?? this.quality,
      downloadType: downloadType ?? this.downloadType,
      currentPhase: clearCurrentPhase
          ? null
          : currentPhase ?? this.currentPhase,
      formatLabel: formatLabel ?? this.formatLabel,
      coverPath: coverPath ?? this.coverPath,
      subtitlePaths: subtitlePaths ?? this.subtitlePaths,
      relatedFilePaths: relatedFilePaths ?? this.relatedFilePaths,
      publicUris: publicUris ?? this.publicUris,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnail': thumbnail,
      'status': status.index,
      'filePath': filePath,
      'fileSize': fileSize,
      'errorMessage': errorMessage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'progress': progress,
      'formatId': formatId,
      'videoCodec': videoCodec,
      'audioCodec': audioCodec,
      'fileExtension': fileExtension,
      'quality': quality,
      'downloadType': downloadType,
      'currentPhase': currentPhase,
      'formatLabel': formatLabel,
      'coverPath': coverPath,
      'subtitlePaths': jsonEncode(subtitlePaths),
      'relatedFilePaths': jsonEncode(relatedFilePaths),
      'publicUris': jsonEncode(publicUris),
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(String key) {
      final raw = map[key];
      if (raw == null || raw.toString().isEmpty) return const [];
      try {
        return (jsonDecode(raw.toString()) as List<dynamic>)
            .map((value) => value.toString())
            .toList(growable: false);
      } catch (_) {
        return const [];
      }
    }

    return DownloadItem(
      id: map['id'] as int?,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnail: map['thumbnail'] as String?,
      status: DownloadStatus.values[map['status'] as int],
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      formatId: map['formatId'] as String?,
      videoCodec: map['videoCodec'] as String?,
      audioCodec: map['audioCodec'] as String?,
      fileExtension: map['fileExtension'] as String?,
      quality: map['quality'] as String?,
      downloadType: map['downloadType'] as String?,
      currentPhase: map['currentPhase'] as String?,
      formatLabel: map['formatLabel'] as String?,
      coverPath: map['coverPath'] as String?,
      subtitlePaths: decodeList('subtitlePaths'),
      relatedFilePaths: decodeList('relatedFilePaths'),
      publicUris: decodeList('publicUris'),
    );
  }
}
