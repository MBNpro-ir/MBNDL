enum MediaProvider {
  youtube('YouTube'),
  youtubeMusic('YouTube Music'),
  spotify('Spotify'),
  soundCloud('SoundCloud'),
  bandcamp('Bandcamp'),
  audiomack('Audiomack'),
  audius('Audius'),
  mixcloud('Mixcloud'),
  applePodcasts('Apple Podcasts'),
  internetArchive('Internet Archive'),
  direct('Supported website');

  const MediaProvider(this.displayName);

  final String displayName;
}

class ResolvedMediaTrack {
  const ResolvedMediaTrack({
    required this.sourceUrl,
    required this.effectiveUrl,
    required this.title,
    this.fallbackUrls = const [],
    this.artist,
    this.thumbnail,
    this.durationSeconds,
  });

  final String sourceUrl;
  final String effectiveUrl;
  final List<String> fallbackUrls;
  final String title;
  final String? artist;
  final String? thumbnail;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'effectiveUrl': effectiveUrl,
    'title': title,
    if (artist?.isNotEmpty == true) 'artist': artist,
    if (thumbnail?.isNotEmpty == true) 'thumbnail': thumbnail,
    if (durationSeconds != null) 'duration': durationSeconds,
  };

  List<String> get candidateUrls => List.unmodifiable({
    effectiveUrl,
    ...fallbackUrls.where((url) => url.isNotEmpty),
  });
}

class ResolvedMediaSource {
  const ResolvedMediaSource({
    required this.originalUrl,
    required this.effectiveUrl,
    required this.provider,
    this.fallbackUrls = const [],
    this.title,
    this.thumbnail,
    this.notice,
    this.tracks = const [],
  });

  final String originalUrl;
  final String effectiveUrl;
  final List<String> fallbackUrls;
  final MediaProvider provider;
  final String? title;
  final String? thumbnail;
  final String? notice;
  final List<ResolvedMediaTrack> tracks;

  bool get isCollection => tracks.length > 1;

  List<String> get candidateUrls => List.unmodifiable({
    effectiveUrl,
    ...fallbackUrls.where((url) => url.isNotEmpty),
  });
}
