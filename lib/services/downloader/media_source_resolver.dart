import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/media_source.dart';
import '../../shared/utils/media_url_classifier.dart';
import '../logger/app_logger.dart';

/// Resolves catalog links before handing them to yt-dlp.
///
/// yt-dlp already handles the broad set of direct media websites. Spotify is
/// intentionally different: its public embed metadata is converted to a
/// precise YouTube/YouTube Music search, following the same transparent
/// metadata-to-audio approach used by spotDL.
class MediaSourceResolver {
  MediaSourceResolver._();

  static final MediaSourceResolver instance = MediaSourceResolver._();
  static const _spotifyNotice =
      'Spotify supplies the title, artist, and cover only. MBNDL matches the '
      'track against YouTube/YouTube Music, so verify the result before '
      'downloading.';
  final Map<String, ResolvedMediaSource> _cache = {};

  Future<ResolvedMediaSource> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    final cached = _cache[url];
    if (cached != null) return cached;

    final provider = MediaUrlClassifier.providerFor(url);
    if (provider != MediaProvider.spotify) {
      return _cache[url] = ResolvedMediaSource(
        originalUrl: url,
        effectiveUrl: url,
        provider: provider,
      );
    }
    return _resolveSpotify(url);
  }

  Future<ResolvedMediaSource> _resolveSpotify(String originalUrl) async {
    final initial = Uri.parse(originalUrl);
    final initialResponse = await http
        .get(initial, headers: _headers)
        .timeout(const Duration(seconds: 20));
    final resolvedUri = initialResponse.request?.url ?? initial;
    final parts = resolvedUri.pathSegments
        .where(
          (segment) =>
              segment.isNotEmpty && !segment.toLowerCase().startsWith('intl-'),
        )
        .toList(growable: false);
    final embedIndex = parts.indexOf('embed');
    final start = embedIndex >= 0 ? embedIndex + 1 : 0;
    if (parts.length < start + 2) {
      throw const FormatException('This Spotify link type is not supported');
    }
    final type = parts[start];
    final id = parts[start + 1];
    if (!const {
      'track',
      'album',
      'playlist',
      'artist',
      'episode',
      'show',
    }.contains(type)) {
      throw FormatException('Spotify $type links are not supported yet');
    }

    final embedUri = Uri.https('open.spotify.com', '/embed/$type/$id');
    final response = resolvedUri.pathSegments.contains('embed')
        ? initialResponse
        : await http
              .get(embedUri, headers: _headers)
              .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Spotify metadata could not be read (HTTP ${response.statusCode})',
      );
    }

    final match = RegExp(
      r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(response.body);
    if (match == null) {
      throw const FormatException('Spotify returned an unknown page format');
    }
    final document = jsonDecode(match.group(1)!);
    final entity = _mapAt(document, const [
      'props',
      'pageProps',
      'state',
      'data',
      'entity',
    ]);
    if (entity == null) {
      throw const FormatException('Spotify metadata is missing');
    }

    final collectionImage = _bestImage(entity);
    final rawTracks = entity['trackList'];
    final tracks = <ResolvedMediaTrack>[];
    if (rawTracks is List && rawTracks.isNotEmpty) {
      for (final raw in rawTracks) {
        if (raw is! Map) continue;
        final track = Map<String, dynamic>.from(raw);
        final title = track['title']?.toString().trim() ?? '';
        final artist = track['subtitle']?.toString().trim() ?? '';
        final sourceUrl = _spotifyWebUrl(track['uri']?.toString());
        if (title.isEmpty || sourceUrl == null) continue;
        final searchUrls = _searchUrls(title, artist);
        tracks.add(
          ResolvedMediaTrack(
            sourceUrl: sourceUrl,
            effectiveUrl: searchUrls.first,
            fallbackUrls: searchUrls.skip(1).toList(growable: false),
            title: title,
            artist: artist.isEmpty ? null : artist,
            thumbnail: collectionImage,
            durationSeconds: _seconds(track['duration']),
          ),
        );
      }
    } else {
      final title =
          entity['title']?.toString().trim() ??
          entity['name']?.toString().trim() ??
          '';
      final artists = entity['artists'];
      final artist = artists is List
          ? artists
                .whereType<Map>()
                .map((value) => value['name']?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .join(', ')
          : entity['subtitle']?.toString().trim() ?? '';
      if (title.isEmpty) {
        throw const FormatException('Spotify item has no readable title');
      }
      final searchUrls = _searchUrls(title, artist);
      tracks.add(
        ResolvedMediaTrack(
          sourceUrl: 'https://open.spotify.com/$type/$id',
          effectiveUrl: searchUrls.first,
          fallbackUrls: searchUrls.skip(1).toList(growable: false),
          title: title,
          artist: artist.isEmpty ? null : artist,
          thumbnail: collectionImage,
          durationSeconds: _seconds(entity['duration']),
        ),
      );
    }
    if (tracks.isEmpty) {
      throw const FormatException('No playable Spotify tracks were found');
    }

    final first = tracks.first;
    final result = ResolvedMediaSource(
      originalUrl: originalUrl,
      effectiveUrl: first.effectiveUrl,
      fallbackUrls: first.fallbackUrls,
      provider: MediaProvider.spotify,
      title: tracks.length > 1
          ? entity['title']?.toString() ?? entity['name']?.toString()
          : first.title,
      thumbnail: collectionImage ?? first.thumbnail,
      notice: _spotifyNotice,
      tracks: tracks,
    );
    _cache[originalUrl] = result;
    for (final track in tracks) {
      _cache[track.sourceUrl] = ResolvedMediaSource(
        originalUrl: track.sourceUrl,
        effectiveUrl: track.effectiveUrl,
        fallbackUrls: track.fallbackUrls,
        provider: MediaProvider.spotify,
        title: track.title,
        thumbnail: track.thumbnail,
        notice: _spotifyNotice,
        tracks: [track],
      );
    }
    AppLogger.info(
      'Resolved Spotify ${tracks.length == 1 ? 'track' : 'collection'} '
      'with ${tracks.length} item(s)',
    );
    return result;
  }

  static const _headers = {
    'accept': 'text/html,application/xhtml+xml',
    'accept-language': 'en-US,en;q=0.8',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/124 Safari/537.36',
  };

  List<String> _searchUrls(String title, String artist) {
    final preciseQuery = [artist, title, 'official audio']
        .where((value) => value.trim().isNotEmpty)
        .join(' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final titleQuery = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return {
      'ytsearch1:$preciseQuery',
      // Some distributors publish the same recording under a different
      // YouTube channel name. A title-only retry keeps those tracks usable
      // without weakening the preferred artist-aware match for normal songs.
      'ytsearch1:$titleQuery',
    }.toList(growable: false);
  }

  String? _spotifyWebUrl(String? uri) {
    final match = RegExp(
      r'^spotify:(track|episode):([\w]+)$',
    ).firstMatch(uri ?? '');
    if (match == null) return null;
    return 'https://open.spotify.com/${match.group(1)}/${match.group(2)}';
  }

  int? _seconds(Object? duration) {
    if (duration is! num) return null;
    return (duration / 1000).round();
  }

  String? _bestImage(Map<String, dynamic> entity) {
    final visual = entity['visualIdentity'];
    if (visual is! Map) return null;
    final images = visual['image'];
    if (images is! List || images.isEmpty) return null;
    Map? best;
    for (final image in images.whereType<Map>()) {
      if (best == null ||
          (image['maxWidth'] as num? ?? 0) > (best['maxWidth'] as num? ?? 0)) {
        best = image;
      }
    }
    return best?['url']?.toString();
  }

  Map<String, dynamic>? _mapAt(Object? value, List<String> path) {
    Object? current = value;
    for (final key in path) {
      if (current is! Map || !current.containsKey(key)) return null;
      current = current[key];
    }
    return current is Map ? Map<String, dynamic>.from(current) : null;
  }
}
