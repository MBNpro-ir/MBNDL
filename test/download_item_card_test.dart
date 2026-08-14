import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/features/history/widgets/download_item_card.dart';
import 'package:mbn_downloader/shared/models/download_item.dart';

void main() {
  testWidgets('selection mode exposes a clear selected state', (tester) async {
    var nextSelection = false;
    final item = DownloadItem(
      id: 7,
      url: 'https://example.com/video',
      title: 'Example download',
      status: DownloadStatus.completed,
      createdAt: DateTime(2026, 8, 15),
      quality: '1080p',
      fileExtension: 'mp4',
      downloadType: 'combined',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: DownloadItemCard(
              item: item,
              selectionMode: true,
              selected: true,
              onSelectionChanged: (value) => nextSelection = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    expect(nextSelection, isFalse);
    expect(tester.takeException(), isNull);
  });
}
