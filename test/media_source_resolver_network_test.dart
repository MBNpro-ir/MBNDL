import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/downloader/download_service.dart';
import 'package:mbn_downloader/services/downloader/media_source_resolver.dart';
import 'package:mbn_downloader/shared/models/media_source.dart';

void main() {
  final enabled = Platform.environment['MBNDL_NETWORK_TEST'] == '1';

  test(
    'resolves a public Spotify track to a transparent search source',
    () async {
      final result = await MediaSourceResolver.instance.resolve(
        'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
      );

      expect(result.provider, MediaProvider.spotify);
      expect(result.title, 'Blinding Lights');
      expect(result.effectiveUrl, startsWith('ytsearch1:'));
      expect(result.effectiveUrl, contains('The Weeknd'));
      expect(result.notice, contains('YouTube'));
    },
    skip: enabled ? false : 'Set MBNDL_NETWORK_TEST=1 for live verification',
  );

  test(
    'keeps a title-only fallback for Spotify tracks with unmatched artists',
    () async {
      final result = await MediaSourceResolver.instance.resolve(
        'https://open.spotify.com/track/4BOsgeRX1R5DUYnnofLv7b',
      );

      expect(result.provider, MediaProvider.spotify);
      expect(result.title, 'Tell The Devil I’m Busy');
      expect(result.candidateUrls, hasLength(2));
      expect(result.candidateUrls.first, contains('Manllii, Broken Vale'));
      expect(result.candidateUrls.last, 'ytsearch1:Tell The Devil I’m Busy');
    },
    skip: enabled ? false : 'Set MBNDL_NETWORK_TEST=1 for live verification',
  );

  test(
    'uses the Spotify fallback to expose downloadable audio formats',
    () async {
      await DownloadService.instance.initialize();
      const url =
          'https://open.spotify.com/track/4BOsgeRX1R5DUYnnofLv7b'
          '?si=08220539856c4bb3';

      final info = await DownloadService.instance.extractVideoInfo(url);
      final formats = await DownloadService.instance.getAvailableFormats(url);

      expect(info['title'], 'Tell The Devil I’m Busy');
      expect(formats, isNotEmpty);
      expect(formats.any((format) => format.hasAudio), isTrue);
    },
    skip: enabled && Platform.isWindows
        ? false
        : 'Set MBNDL_NETWORK_TEST=1 and run on Windows for live verification',
  );

  test(
    'expands a public Spotify album into individual track jobs',
    () async {
      final result = await MediaSourceResolver.instance.resolve(
        'https://open.spotify.com/album/4yP0hdKOZPNshxUOjY0cZj',
      );

      expect(result.provider, MediaProvider.spotify);
      expect(result.tracks.length, greaterThan(10));
      expect(result.tracks.first.sourceUrl, contains('/track/'));
      expect(result.isCollection, isTrue);
    },
    skip: enabled ? false : 'Set MBNDL_NETWORK_TEST=1 for live verification',
  );

  test(
    'expands a public Spotify artist into top-track jobs',
    () async {
      final result = await MediaSourceResolver.instance.resolve(
        'https://open.spotify.com/artist/1Xyo4u8uXC1ZmMpatF05PJ',
      );

      expect(result.provider, MediaProvider.spotify);
      expect(result.title, 'The Weeknd');
      expect(result.tracks.length, greaterThanOrEqualTo(5));
      expect(result.tracks.every((track) => track.title.isNotEmpty), isTrue);
    },
    skip: enabled ? false : 'Set MBNDL_NETWORK_TEST=1 for live verification',
  );
}
