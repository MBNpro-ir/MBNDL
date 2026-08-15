import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/features/home/presentation/format_selection_page.dart';
import 'package:mbn_downloader/shared/models/video_format.dart';

void main() {
  testWidgets('separate video and audio can become one smart-merge output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 900);
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

    FormatSelectionResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<FormatSelectionResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FormatSelectionPage(
                        formats: formats,
                        videoTitle: 'A test video',
                      ),
                    ),
                  );
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('1 final file'), findsOneWidget);

    await tester.tap(find.text('Video (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('H.264 • MP4'));
    await tester.pump();

    await tester.tap(find.text('Audio (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AAC • M4A'));
    await tester.pump();

    expect(find.text('3 final files'), findsOneWidget);
    await tester.tap(find.text('Smart merge into one file'));
    await tester.pump();
    expect(find.text('2 final files'), findsOneWidget);
    await tester.tap(find.text('Add 2 outputs'));
    await tester.pumpAndSettle();

    final merge = result!.jobs.singleWhere((job) => job.isSmartMerge);
    expect(merge.downloadType, 'combined');
    expect(merge.formatSelector, '137+140');
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloaded formats are green and require copy confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const format = VideoFormat(
      formatId: '22',
      resolution: '720p',
      ext: 'mp4',
      vcodec: 'h264',
      acodec: 'aac',
      hasVideo: true,
      hasAudio: true,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: FormatSelectionPage(
          formats: [format],
          videoTitle: 'Downloaded video',
          previousDownloads: {'22': 1},
        ),
      ),
    );

    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Nothing selected'), findsOneWidget);
    await tester.tap(find.text('H.264 • MP4 + audio'));
    await tester.pumpAndSettle();
    expect(find.text('This quality was downloaded before'), findsOneWidget);
    await tester.tap(find.text('Download another copy'));
    await tester.pumpAndSettle();
    expect(find.text('1 final file'), findsOneWidget);
  });

  testWidgets('same resolution shows compact codec variants on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const formats = [
      VideoFormat(
        formatId: '135',
        resolution: '854x480',
        height: 480,
        ext: 'mp4',
        vcodec: 'avc1.4d401f',
        hasVideo: true,
      ),
      VideoFormat(
        formatId: '244',
        resolution: '854x480',
        height: 480,
        ext: 'webm',
        vcodec: 'vp9',
        hasVideo: true,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: FormatSelectionPage(
          formats: formats,
          videoTitle: 'Codec comparison',
        ),
      ),
    );
    await tester.tap(find.text('Video (0)'));
    await tester.pumpAndSettle();

    expect(find.text('480p resolution'), findsOneWidget);
    expect(find.text('H.264 • MP4'), findsOneWidget);
    expect(find.text('VP9 • WEBM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multilingual audio shows country flag, code, and stream facts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const format = VideoFormat(
      formatId: '251-en-gb',
      ext: 'webm',
      acodec: 'opus',
      abr: 128,
      language: 'en-GB',
      audioChannels: 2,
      audioSampleRate: 48000,
      protocol: 'https',
      formatNote: 'original',
      hasAudio: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FormatSelectionPage(
          formats: [format],
          videoTitle: 'Multilingual audio',
        ),
      ),
    );
    await tester.tap(find.text('Audio (0)'));
    await tester.pumpAndSettle();

    expect(find.text('🇬🇧 EN-GB'), findsOneWidget);
    expect(find.text('Stereo · 2 ch'), findsOneWidget);
    expect(find.text('48 kHz'), findsOneWidget);
    expect(find.text('HTTPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
