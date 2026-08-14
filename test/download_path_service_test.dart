import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/storage/download_path_service.dart';

void main() {
  test('finds managed format selectors in existing output files', () async {
    final root = await Directory.systemTemp.createTemp('mbndl-path-test-');
    try {
      final video = await Directory(
        '${root.path}${Platform.pathSeparator}Video',
      ).create();
      final audio = await Directory(
        '${root.path}${Platform.pathSeparator}Audio',
      ).create();
      await File(
        '${video.path}${Platform.pathSeparator}'
        'Example [media.id+1] [137+140].mp4',
      ).create();
      await File(
        '${video.path}${Platform.pathSeparator}'
        'Example [media.id+1] [137+140] (copy 2).mp4',
      ).create();
      await File(
        '${audio.path}${Platform.pathSeparator}'
        'Example [media.id+1] [251].webm',
      ).create();
      await File(
        '${audio.path}${Platform.pathSeparator}'
        'Unrelated [another-id] [251].webm',
      ).create();

      final result = await DownloadPathService.instance
          .findExistingFormatSelectors(
            mediaId: 'media.id+1',
            downloadPath: root.path,
          );

      expect(result, {'137+140': 2, '251': 1});
    } finally {
      await root.delete(recursive: true);
    }
  });
}
