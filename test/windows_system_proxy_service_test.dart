import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbn_downloader/services/network/windows_system_proxy_service.dart';

void main() {
  test('queries the live Windows proxy safely', () async {
    final args = await WindowsSystemProxyService.instance.ytDlpArgsFor(
      'https://youtube.com/watch?v=test',
    );
    expect(args, isA<List<String>>());
  }, skip: !Platform.isWindows);

  test('selects the HTTPS mapping and normalizes its scheme', () {
    expect(
      WindowsSystemProxyService.selectProxy(
        'http=127.0.0.1:8080;https=proxy.example:4443',
        'https',
      ),
      'http://proxy.example:4443',
    );
  });

  test('supports a generic and a SOCKS system proxy', () {
    expect(
      WindowsSystemProxyService.selectProxy('localhost:7890', 'https'),
      'http://localhost:7890',
    );
    expect(
      WindowsSystemProxyService.selectProxy('socks=localhost:1080', 'https'),
      'socks5://localhost:1080',
    );
  });

  test('honors local and wildcard bypass rules', () {
    expect(
      WindowsSystemProxyService.isBypassed(
        Uri.parse('https://intranet/path'),
        '<local>;*.example.test',
      ),
      isTrue,
    );
    expect(
      WindowsSystemProxyService.isBypassed(
        Uri.parse('https://cdn.example.test/file'),
        '<local>;*.example.test',
      ),
      isTrue,
    );
    expect(
      WindowsSystemProxyService.isBypassed(
        Uri.parse('https://youtube.com/watch'),
        '<local>;*.example.test',
      ),
      isFalse,
    );
  });

  test('redacts proxy credentials before logging', () {
    expect(
      WindowsSystemProxyService.redact(
        'http://someone:secret@proxy.example:8080',
      ),
      isNot(contains('secret')),
    );
  });
}
