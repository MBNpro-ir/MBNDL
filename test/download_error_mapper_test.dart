import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/downloader/download_error_mapper.dart';

void main() {
  group('DownloadErrorMapper', () {
    test('explains FFmpeg failures with a repair action', () {
      final error = DownloadErrorMapper.fromText('ERROR: ffmpeg not found');

      expect(error.title, 'Media tools are unavailable');
      expect(error.suggestion, contains('repair or update FFmpeg'));
    });

    test('explains cookie authentication failures', () {
      final error = DownloadErrorMapper.fromText(
        'Sign in to confirm you are not a bot. Use --cookies.',
      );

      expect(error.title, 'YouTube sign-in is required');
      expect(error.suggestion, contains('YouTube account'));
      expect(
        DownloadErrorMapper.isYouTubeAuthenticationError(
          Exception('Sign in to confirm you are not a bot'),
        ),
        isTrue,
      );
    });

    test('explains an exhausted Spotify match without engine jargon', () {
      final error = DownloadErrorMapper.fromText(
        'Spotify match unavailable: no playable source',
      );

      expect(error.title, 'No matching audio source was found');
      expect(error.message, contains('Spotify metadata loaded'));
      expect(error.suggestion, contains('direct YouTube link'));
    });

    test('does not expose an opaque fallback error', () {
      final error = DownloadErrorMapper.fromText('exit code 123');

      expect(error.displayText, contains('Download could not be completed'));
      expect(error.displayText, contains('Retry'));
    });
  });
}
