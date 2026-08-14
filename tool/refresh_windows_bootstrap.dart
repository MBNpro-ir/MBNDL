import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mbn_downloader/services/downloader/remote_zip_archive.dart';

const _archiveUrl =
    'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
const _versionUrl = '$_archiveUrl.ver';
const _checksumUrl = '$_archiveUrl.sha256';
const _headers = {'User-Agent': 'MBN-Downloader-Build'};

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('This bootstrap builder currently requires Windows.');
    exitCode = 1;
    return;
  }

  final project = Directory.current;
  if (!File(
    '${project.path}${Platform.pathSeparator}pubspec.yaml',
  ).existsSync()) {
    stderr.writeln('Run this command from the Flutter project root.');
    exitCode = 1;
    return;
  }

  final output = File(
    '${project.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}ffmpeg-windows-x64.zip',
  );
  final staging = await Directory.systemTemp.createTemp(
    'mbn_ffmpeg_bootstrap_',
  );
  final client = http.Client();

  try {
    final metadata = await Future.wait([
      client.get(Uri.parse(_versionUrl), headers: _headers),
      client.get(Uri.parse(_checksumUrl), headers: _headers),
    ]);
    if (metadata.any((response) => response.statusCode != HttpStatus.ok)) {
      throw const HttpException('Could not read FFmpeg release metadata');
    }
    final version = utf8.decode(metadata[0].bodyBytes).trim();
    final archiveSha256 = utf8.decode(metadata[1].bodyBytes).trim();

    final remote = RemoteZipArchive(
      uri: Uri.parse(_archiveUrl),
      client: client,
      headers: _headers,
      streamTimeout: const Duration(minutes: 2),
    );
    final selected = <String, String>{
      'ffmpeg.exe': 'ffmpeg.exe',
      'ffprobe.exe': 'ffprobe.exe',
      'LICENSE': 'LICENSE.txt',
      'README.txt': 'README.txt',
    };

    for (final pair in selected.entries) {
      final entry = await remote.findUniqueFile(pair.key);
      stdout.writeln(
        'Fetching ${pair.key} '
        '(${(entry.compressedSize / (1024 * 1024)).toStringAsFixed(1)} MiB)',
      );
      var lastBucket = -1;
      await remote.extractEntry(
        entry,
        File('${staging.path}${Platform.pathSeparator}${pair.value}'),
        onProgress: (received, total) {
          if (total <= 0) return;
          final bucket = (received * 10 ~/ total).clamp(0, 10);
          if (bucket != lastBucket) {
            lastBucket = bucket;
            stdout.writeln('  ${bucket * 10}%');
          }
        },
      );
    }

    await File(
      '${staging.path}${Platform.pathSeparator}SOURCE.txt',
    ).writeAsString(
      'FFmpeg Windows Essentials bootstrap\n'
      'Version: $version\n'
      'Source archive: $_archiveUrl\n'
      'Source archive SHA-256: $archiveSha256\n'
      'Bundled files: ffmpeg.exe, ffprobe.exe\n'
      'Excluded: ffplay.exe, HTML documentation, presets\n'
      'FFmpeg source: https://github.com/FFmpeg/FFmpeg\n',
      flush: true,
    );

    await output.parent.create(recursive: true);
    final command =
        'Compress-Archive -Path ${_quote('${staging.path}\\*')} '
        '-DestinationPath ${_quote(output.path)} '
        '-CompressionLevel Optimal -Force';
    final result = await Process.run('powershell.exe', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      command,
    ]).timeout(const Duration(minutes: 5));
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const ['Compress-Archive'],
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final digest = await sha256.bind(output.openRead()).first;
    stdout.writeln('Created ${output.path}');
    stdout.writeln('Version: $version');
    stdout.writeln('Size: ${await output.length()} bytes');
    stdout.writeln('SHA-256: $digest');
  } finally {
    client.close();
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

String _quote(String value) => "'${value.replaceAll("'", "''")}'";
