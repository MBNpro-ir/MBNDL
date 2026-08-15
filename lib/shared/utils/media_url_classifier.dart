import '../models/media_source.dart';

class MediaUrlClassifier {
  const MediaUrlClassifier._();

  static bool isYouTubeUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
  }

  static bool isSpotifyUrl(String rawUrl) {
    final host = Uri.tryParse(rawUrl.trim())?.host.toLowerCase();
    return host == 'open.spotify.com' ||
        host == 'spotify.com' ||
        host?.endsWith('.spotify.com') == true ||
        host == 'spotify.link';
  }

  static MediaProvider providerFor(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    final host = uri?.host.toLowerCase() ?? '';
    if (host == 'music.youtube.com') return MediaProvider.youtubeMusic;
    if (isYouTubeUrl(rawUrl)) return MediaProvider.youtube;
    if (isSpotifyUrl(rawUrl)) return MediaProvider.spotify;
    if (host == 'soundcloud.com' || host.endsWith('.soundcloud.com')) {
      return MediaProvider.soundCloud;
    }
    if (host == 'bandcamp.com' || host.endsWith('.bandcamp.com')) {
      return MediaProvider.bandcamp;
    }
    if (host == 'audiomack.com' || host.endsWith('.audiomack.com')) {
      return MediaProvider.audiomack;
    }
    if (host == 'audius.co' || host.endsWith('.audius.co')) {
      return MediaProvider.audius;
    }
    if (host == 'mixcloud.com' || host.endsWith('.mixcloud.com')) {
      return MediaProvider.mixcloud;
    }
    if (host == 'podcasts.apple.com') return MediaProvider.applePodcasts;
    if (host == 'archive.org' || host.endsWith('.archive.org')) {
      return MediaProvider.internetArchive;
    }
    return MediaProvider.direct;
  }

  static bool isLikelyPlaylistUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    if (uri.pathSegments.any((segment) => segment == 'playlist')) return true;
    return uri.queryParameters['list']?.trim().isNotEmpty == true;
  }
}
