import 'package:flutter_test/flutter_test.dart';

import 'package:mbn_downloader/features/settings/domain/yt_dlp_settings.dart';

void main() {
  group('YtDlpSettings', () {
    test(
      'defaults to the recommended update channel without forcing a format',
      () {
        const settings = YtDlpSettings();
        final args = settings.toYtDlpArgs();

        expect(settings.updateChannel, 'nightly');
        expect(args, contains('--ignore-config'));
        expect(args, isNot(contains('-f')));
        expect(args, isNot(contains('--remote-components')));
      },
    );

    test('emits current runtime and extractor options', () {
      const settings = YtDlpSettings(
        jsRuntime: 'node',
        jsRuntimePath: r'C:\Tools\node.exe',
        allowRemoteComponents: true,
        retrySleep: 'http:linear=1::2:5',
        sleepRequests: '0.75',
        extractorArgs: 'youtube:player_client=web_safari',
        impersonateTarget: 'chrome',
        cookiesFromBrowser: 'firefox',
        downloadArchive: 'archive.txt',
        liveFromStart: true,
        waitForVideo: '30-120',
        extractorRetries: 7,
        checkFormats: true,
        hlsUseMpegTs: true,
      );
      final args = settings.toYtDlpArgs();

      expect(
        args,
        containsAllInOrder([
          '--js-runtimes',
          r'node:C:\Tools\node.exe',
          '--remote-components',
          'ejs:github',
        ]),
      );
      expect(args, containsAll(['--retry-sleep', 'http:linear=1::2:5']));
      expect(
        args,
        containsAll(['--extractor-args', 'youtube:player_client=web_safari']),
      );
      expect(args, containsAll(['--impersonate', 'chrome']));
      expect(args, isNot(contains('--cookies-from-browser')));
      expect(args, isNot(contains('--download-archive')));
      expect(args, contains('--live-from-start'));
      expect(args, containsAll(['--wait-for-video', '30-120']));
      expect(args, containsAll(['--extractor-retries', '7']));
      expect(args, contains('--check-formats'));
      expect(args, contains('--hls-use-mpegts'));
      expect(args, containsAll(['--continue', '--no-overwrites']));
    });

    test('migrates older JSON and preserves new preferences', () {
      final migrated = YtDlpSettings.fromJson({
        'sleepInterval': '3-8',
        'downloadSubtitlesEnabled': true,
      });

      expect(migrated.updateChannel, 'nightly');
      expect(migrated.jsRuntime, 'auto');
      expect(migrated.minSleepInterval, '3');
      expect(migrated.maxSleepInterval, '8');
      expect(migrated.downloadSubtitlesEnabled, isTrue);

      final restored = YtDlpSettings.fromJson(
        migrated
            .copyWith(
              updateChannel: 'stable',
              allowRemoteComponents: true,
              breakPerInput: true,
              extractorRetries: 8,
              checkFormats: true,
            )
            .toJson(),
      );
      expect(restored.updateChannel, 'stable');
      expect(restored.allowRemoteComponents, isTrue);
      expect(restored.breakPerInput, isTrue);
      expect(restored.extractorRetries, 8);
      expect(restored.checkFormats, isTrue);
    });

    test('normalizes settings owned by the app workflow', () {
      const legacy = YtDlpSettings(
        downloadPath: r'C:\Downloads\MBNDL',
        downloadPlaylist: false,
        overwriteFiles: true,
        writeThumbnail: true,
        cookiesFromBrowser: 'chrome',
        quiet: true,
      );

      final normalized = legacy.normalizedForAppPolicy();
      expect(normalized.downloadPath, r'C:\Downloads\MBNDL');
      expect(normalized.downloadPlaylist, isTrue);
      expect(normalized.overwriteFiles, isFalse);
      expect(normalized.writeThumbnail, isFalse);
      expect(normalized.cookiesFromBrowser, isEmpty);
      expect(normalized.quiet, isFalse);
    });
  });
}
