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

  static bool isLikelyPlaylistUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return false;
    if (uri.pathSegments.any((segment) => segment == 'playlist')) return true;
    return uri.queryParameters['list']?.trim().isNotEmpty == true;
  }
}
