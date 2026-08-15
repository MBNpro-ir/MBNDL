import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/shared/models/media_source.dart';
import 'package:mbn_downloader/shared/utils/media_url_classifier.dart';

void main() {
  test('recognizes direct and smart-match media providers', () {
    expect(
      MediaUrlClassifier.providerFor(
        'https://open.spotify.com/track/123?si=abc',
      ),
      MediaProvider.spotify,
    );
    expect(
      MediaUrlClassifier.providerFor('https://music.youtube.com/watch?v=123'),
      MediaProvider.youtubeMusic,
    );
    expect(
      MediaUrlClassifier.providerFor('https://soundcloud.com/user/song'),
      MediaProvider.soundCloud,
    );
    expect(
      MediaUrlClassifier.providerFor('https://artist.bandcamp.com/track/song'),
      MediaProvider.bandcamp,
    );
  });
}
