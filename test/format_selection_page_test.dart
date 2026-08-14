import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/features/home/presentation/format_selection_page.dart';
import 'package:mbn_downloader/shared/models/video_format.dart';

void main() {
  testWidgets('separate video and audio can become one smart-merge output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const formats = [
      VideoFormat(
        formatId: '22',
        resolution: '720p',
        ext: 'mp4',
        vcodec: 'h264',
        acodec: 'aac',
        hasVideo: true,
        hasAudio: true,
      ),
      VideoFormat(
        formatId: '137',
        resolution: '1080p',
        ext: 'mp4',
        vcodec: 'h264',
        hasVideo: true,
      ),
      VideoFormat(
        formatId: '140',
        ext: 'm4a',
        acodec: 'aac',
        abr: 128,
        hasAudio: true,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: FormatSelectionPage(formats: formats, videoTitle: 'A test video'),
      ),
    );

    expect(find.text('1 output selected'), findsOneWidget);

    await tester.tap(find.text('Video (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('1080p').last);
    await tester.pump();

    await tester.tap(find.text('Audio (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('M4A').last);
    await tester.pump();

    expect(find.text('3 outputs selected'), findsOneWidget);
    await tester.tap(find.text('Smart merge separate streams'));
    await tester.pump();
    expect(find.text('2 outputs selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
