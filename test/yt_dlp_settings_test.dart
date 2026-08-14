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
      expect(args, containsAll(['--cookies-from-browser', 'firefox']));
      expect(args, containsAll(['--download-archive', 'archive.txt']));
      expect(args, contains('--live-from-start'));
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
            )
            .toJson(),
      );
      expect(restored.updateChannel, 'stable');
      expect(restored.allowRemoteComponents, isTrue);
      expect(restored.breakPerInput, isTrue);
    });
  });
}
