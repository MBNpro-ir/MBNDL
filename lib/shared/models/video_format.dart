class VideoFormat {
  final String formatId;
  final String? resolution;
  final String? ext;
  final int? width;
  final int? height;
  final double? fps;
  final String? vcodec;
  final String? acodec;
  final int? filesize;
  final int? filesizeApprox;
  final double? tbr; // Total bitrate
  final double? vbr; // Video bitrate
  final double? abr; // Audio bitrate
  final String? formatNote;
  final bool hasVideo;
  final bool hasAudio;

  const VideoFormat({
    required this.formatId,
    this.resolution,
    this.ext,
    this.width,
    this.height,
    this.fps,
    this.vcodec,
    this.acodec,
    this.filesize,
    this.filesizeApprox,
    this.tbr,
    this.vbr,
    this.abr,
    this.formatNote,
    this.hasVideo = false,
    this.hasAudio = false,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    String? optionalText(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
        return null;
      }
      return value;
    }

    int? positiveInt(String key) {
      final value = json[key] as num?;
      return value != null && value > 0 ? value.toInt() : null;
    }

    final vcodec = optionalText('vcodec');
    final acodec = optionalText('acodec');
    final ext = optionalText('ext');
    final videoExt = optionalText('video_ext');
    final audioExt = optionalText('audio_ext');
    const videoContainers = {
      'mp4',
      'mkv',
      'webm',
      'mov',
      'avi',
      'flv',
      'm4v',
      'ts',
    };
    final codecsUnknown = vcodec == null && acodec == null;
    final directVideoContainer =
        codecsUnknown && videoContainers.contains(ext?.toLowerCase());
    bool isPresent(String? value) =>
        value != null && value.toLowerCase() != 'none';

    return VideoFormat(
      formatId: json['format_id']?.toString() ?? json['id']?.toString() ?? '',
      resolution: optionalText('resolution'),
      ext: ext,
      width: positiveInt('width'),
      height: positiveInt('height'),
      fps: (json['fps'] as num?)?.toDouble(),
      vcodec: vcodec,
      acodec: acodec,
      filesize: positiveInt('filesize'),
      filesizeApprox: positiveInt('filesize_approx'),
      tbr: (json['tbr'] as num?)?.toDouble(),
      vbr: (json['vbr'] as num?)?.toDouble(),
      abr: (json['abr'] as num?)?.toDouble(),
      formatNote: optionalText('format_note'),
      hasVideo:
          isPresent(vcodec) || isPresent(videoExt) || directVideoContainer,
      hasAudio:
          isPresent(acodec) || isPresent(audioExt) || directVideoContainer,
    );
  }

  String get displayName {
    final parts = <String>[];

    if (resolution != null && resolution != '0p' && resolution != 'unknown') {
      parts.add(resolution!);
    } else if (height != null && height! > 0) {
      parts.add('${height}p');
    } else if (hasVideo) {
      parts.add('Video');
    } else if (hasAudio) {
      parts.add('Audio');
    }

    if (ext != null) {
      parts.add(ext!.toUpperCase());
    }

    if (formatNote != null &&
        formatNote!.isNotEmpty &&
        formatNote != 'none' &&
        formatNote != 'unknown') {
      parts.add(formatNote!);
    }

    if (vcodec != null && vcodec != 'none') {
      parts.add(vcodec!);
    }

    if (hasAudio && acodec != null && acodec != 'none') {
      parts.add('+ audio');
    }

    return parts.isEmpty ? 'Format $formatId' : parts.join(' • ');
  }

  String get filesizeDisplay {
    final size = filesize ?? filesizeApprox;
    if (size == null) return 'Unknown size';

    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get bitrateDisplay {
    if (tbr != null) return '${tbr!.toStringAsFixed(0)} kbps';
    if (vbr != null && abr != null) {
      return '${(vbr! + abr!).toStringAsFixed(0)} kbps';
    }
    if (vbr != null) return '${vbr!.toStringAsFixed(0)} kbps';
    if (abr != null) return '${abr!.toStringAsFixed(0)} kbps';
    return 'Unknown';
  }

  String get qualityScore {
    if (height != null) {
      if (height! >= 2160) return '4K';
      if (height! >= 1440) return '2K';
      if (height! >= 1080) return 'Full HD';
      if (height! >= 720) return 'HD';
      if (height! >= 480) return 'SD';
      return 'Low';
    }
    return 'Unknown';
  }

  // Helper methods to check if values are valid for display
  bool get hasValidFilesize {
    final size = filesize ?? filesizeApprox;
    return size != null && size > 0;
  }

  bool get hasValidBitrate {
    if (tbr != null && tbr! > 0) return true;
    if (vbr != null && vbr! > 0) return true;
    if (abr != null && abr! > 0) return true;
    return false;
  }

  bool get hasValidFps {
    return fps != null && fps! > 0;
  }
}

class FormatGroup {
  final String title;
  final List<VideoFormat> formats;
  final bool isVideoOnly;
  final bool isAudioOnly;
  final bool isCombined;

  const FormatGroup({
    required this.title,
    required this.formats,
    this.isVideoOnly = false,
    this.isAudioOnly = false,
    this.isCombined = false,
  });
}
