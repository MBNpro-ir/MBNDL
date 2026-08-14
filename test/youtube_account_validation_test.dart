import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/storage/cookie_storage_service.dart';
import 'package:mbn_downloader/shared/utils/media_url_classifier.dart';

void main() {
  group('YouTube account safety', () {
    test('recognizes YouTube and YouTube Music only', () {
      expect(
        MediaUrlClassifier.isYouTubeUrl('https://music.youtube.com/watch?v=x'),
        isTrue,
      );
      expect(MediaUrlClassifier.isYouTubeUrl('https://youtu.be/x'), isTrue);
      expect(
        MediaUrlClassifier.isYouTubeUrl('https://example.com/youtube.com'),
        isFalse,
      );
    });

    test('detects playlist links without a manual setting', () {
      expect(
        MediaUrlClassifier.isLikelyPlaylistUrl(
          'https://www.youtube.com/playlist?list=PL123',
        ),
        isTrue,
      );
      expect(
        MediaUrlClassifier.isLikelyPlaylistUrl(
          'https://www.youtube.com/watch?v=abc',
        ),
        isFalse,
      );
    });

    test('accepts only Netscape files containing YouTube cookies', () {
      const valid =
          '# Netscape HTTP Cookie File\n'
          '.youtube.com\tTRUE\t/\tTRUE\t2147483647\tSID\tsecret';
      const unrelated =
          '# Netscape HTTP Cookie File\n'
          '.example.com\tTRUE\t/\tTRUE\t2147483647\tSID\tsecret';
      const deceptive =
          '# Netscape HTTP Cookie File\n'
          '.notgoogle.com\tTRUE\t/\tTRUE\t2147483647\tSID\tsecret';

      expect(CookieStorageService.validateYouTubeCookieFile(valid), isNull);
      expect(
        CookieStorageService.validateYouTubeCookieFile(unrelated),
        contains('YouTube or Google'),
      );
      expect(
        CookieStorageService.validateYouTubeCookieFile(deceptive),
        contains('YouTube or Google'),
      );
      expect(
        CookieStorageService.validateYouTubeCookieFile('SID=secret'),
        contains('first line'),
      );
    });
  });
}
