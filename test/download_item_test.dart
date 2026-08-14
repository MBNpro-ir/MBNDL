import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/shared/models/download_item.dart';

void main() {
  test('download artifacts survive a database map round trip', () {
    final item = DownloadItem(
      id: 7,
      url: 'https://example.com/video',
      title: 'Example',
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 8, 14),
      formatLabel: 'Smart merge • 1080p + 128 kbps',
      coverPath: r'C:\Downloads\MBNDL\Cover\example.jpg',
      subtitlePaths: const [r'C:\Downloads\MBNDL\Video\example.en.srt'],
      relatedFilePaths: const [r'C:\Downloads\MBNDL\Cover\example.jpg'],
      publicUris: const ['content://downloads/1'],
    );

    final restored = DownloadItem.fromMap(item.toMap());

    expect(restored.formatLabel, item.formatLabel);
    expect(restored.coverPath, item.coverPath);
    expect(restored.subtitlePaths, item.subtitlePaths);
    expect(restored.relatedFilePaths, item.relatedFilePaths);
    expect(restored.publicUris, item.publicUris);
  });

  test('retry can clear an old friendly error', () {
    final item = DownloadItem(
      url: 'https://example.com/video',
      title: 'Example',
      status: DownloadStatus.failed,
      errorMessage: 'Network connection failed',
      createdAt: DateTime.utc(2026, 8, 14),
    );

    expect(item.copyWith(clearErrorMessage: true).errorMessage, isNull);
  });
}
