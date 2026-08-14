import 'package:flutter_test/flutter_test.dart';

import 'package:mbn_downloader/shared/models/video_format.dart';

void main() {
  test('format labels omit zero and null metadata', () {
    final format = VideoFormat.fromJson({
      'format_id': 'http-0',
      'ext': 'mp4',
      'height': 0,
      'resolution': '0p',
      'format_note': 'null',
      'vcodec': 'h264',
      'acodec': 'aac',
      'filesize': 0,
    });

    expect(format.displayName, 'Video • MP4 • h264 • + audio');
    expect(format.displayName, isNot(contains('0p')));
    expect(format.displayName, isNot(contains('null')));
    expect(format.hasValidFilesize, isFalse);
  });

  test('direct video containers remain selectable when codecs are unknown', () {
    final format = VideoFormat.fromJson({
      'format_id': 'mp4',
      'ext': 'mp4',
      'video_ext': 'mp4',
      'audio_ext': 'none',
      'protocol': 'https',
    });

    expect(format.hasVideo, isTrue);
    expect(format.hasAudio, isTrue);
    expect(format.displayName, 'Video • MP4');
  });
}
