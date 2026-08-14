import 'package:flutter/services.dart';

class FriendlyDownloadError {
  const FriendlyDownloadError({
    required this.title,
    required this.message,
    required this.suggestion,
  });

  final String title;
  final String message;
  final String suggestion;

  String get displayText => '$title: $message $suggestion';
}

class DownloadErrorMapper {
  const DownloadErrorMapper._();

  static FriendlyDownloadError from(Object error) {
    final raw = error is PlatformException
        ? '${error.code} ${error.message ?? ''} ${error.details ?? ''}'
        : error.toString();
    return fromText(raw);
  }

  static FriendlyDownloadError fromText(String raw) {
    final text = raw.toLowerCase();

    if (_containsAny(text, const [
      'ffmpeg not found',
      'ffprobe not found',
      'ffmpeg-location',
      'unable to find ffmpeg',
    ])) {
      return const FriendlyDownloadError(
        title: 'Media tools are unavailable',
        message: 'FFmpeg or FFprobe could not be started.',
        suggestion: 'Open Settings › Tools and repair or update FFmpeg.',
      );
    }
    if (_containsAny(text, const [
      'requested format is not available',
      'format not available',
      'no video formats found',
    ])) {
      return const FriendlyDownloadError(
        title: 'That quality is no longer available',
        message: 'The source changed its available streams.',
        suggestion: 'Inspect the link again and choose another format.',
      );
    }
    if (_containsAny(text, const [
      'sign in to confirm',
      'login required',
      'cookies are needed',
      'use --cookies',
      'authentication required',
      'not a bot',
    ])) {
      return const FriendlyDownloadError(
        title: 'Sign-in is required',
        message: 'The website rejected anonymous access.',
        suggestion: 'Add a fresh cookies file in Settings and retry.',
      );
    }
    if (_containsAny(text, const [
      'private video',
      'video unavailable',
      'content is unavailable',
      'this video has been removed',
    ])) {
      return const FriendlyDownloadError(
        title: 'Media is unavailable',
        message: 'It may be private, deleted, age-restricted, or restricted.',
        suggestion: 'Check the link and your access to the source website.',
      );
    }
    if (_containsAny(text, const [
      'unsupported url',
      'no suitable extractor',
      'is not a valid url',
    ])) {
      return const FriendlyDownloadError(
        title: 'This link is not supported',
        message: 'yt-dlp could not recognize the address.',
        suggestion: 'Paste the direct page URL and update yt-dlp if needed.',
      );
    }
    if (_containsAny(text, const ['http error 429', 'too many requests'])) {
      return const FriendlyDownloadError(
        title: 'The website is rate-limiting requests',
        message: 'Too many requests were sent from this connection.',
        suggestion: 'Wait a few minutes, reduce concurrency, then retry.',
      );
    }
    if (_containsAny(text, const [
      'http error 403',
      'forbidden',
      'access denied',
    ])) {
      return const FriendlyDownloadError(
        title: 'The website blocked this request',
        message: 'Access was refused by the source server.',
        suggestion: 'Refresh cookies, disable the proxy, or retry later.',
      );
    }
    if (_containsAny(text, const [
      'geo restriction',
      'not available in your country',
      'not available in your region',
    ])) {
      return const FriendlyDownloadError(
        title: 'Region restriction',
        message: 'This media is not available from your current region.',
        suggestion: 'Use a permitted connection or another source.',
      );
    }
    if (_containsAny(text, const [
      'no space left',
      'disk full',
      'not enough space',
    ])) {
      return const FriendlyDownloadError(
        title: 'Storage is full',
        message: 'There is not enough free space to finish the download.',
        suggestion: 'Free some storage or choose another download folder.',
      );
    }
    if (_containsAny(text, const [
      'permission denied',
      'operation not permitted',
      'read-only file system',
    ])) {
      return const FriendlyDownloadError(
        title: 'Folder access was denied',
        message: 'MBNDL could not write to the selected location.',
        suggestion: 'Restore the default download folder or grant access.',
      );
    }
    if (_containsAny(text, const [
      'unable to download webpage',
      'temporary failure in name resolution',
      'name or service not known',
      'connection timed out',
      'connection reset',
      'network is unreachable',
      'socketexception',
    ])) {
      return const FriendlyDownloadError(
        title: 'Network connection failed',
        message: 'MBNDL could not reach the source website.',
        suggestion: 'Check the internet, proxy, VPN, and firewall, then retry.',
      );
    }
    if (_containsAny(text, const [
      'postprocessing',
      'post-processing',
      'merger',
      'merge failed',
    ])) {
      return const FriendlyDownloadError(
        title: 'Audio and video could not be combined',
        message: 'The streams downloaded, but post-processing failed.',
        suggestion: 'Repair FFmpeg or choose a ready-to-play format.',
      );
    }

    return const FriendlyDownloadError(
      title: 'Download could not be completed',
      message: 'The source or download engine returned an unexpected error.',
      suggestion: 'Retry once, then update yt-dlp and review the app log.',
    );
  }

  static bool _containsAny(String text, List<String> patterns) {
    return patterns.any(text.contains);
  }
}
