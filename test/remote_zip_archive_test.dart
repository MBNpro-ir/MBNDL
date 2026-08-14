import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbn_downloader/services/downloader/remote_zip_archive.dart';

void main() {
  group('RemoteZipArchive', () {
    late HttpServer server;
    late Uint8List archiveBytes;
    late List<String> requestedRanges;

    setUp(() async {
      archiveBytes = _buildZip({
        'ffmpeg-test/bin/ffmpeg.exe': utf8.encode('ffmpeg executable'),
        'ffmpeg-test/bin/ffplay.exe': utf8.encode('unused player'),
        'ffmpeg-test/bin/ffprobe.exe': utf8.encode('ffprobe executable'),
      });
      requestedRanges = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range == null) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        requestedRanges.add(range);

        final (start, end) = _parseRange(range, archiveBytes.length);
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${archiveBytes.length}',
          )
          ..headers.set(HttpHeaders.etagHeader, '"test-archive"')
          ..contentLength = end - start + 1
          ..add(archiveBytes.sublist(start, end + 1));
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('downloads and verifies only explicitly selected entries', () async {
      final client = http.Client();
      final temporary = await Directory.systemTemp.createTemp(
        'mbn_remote_zip_test_',
      );
      try {
        final remote = RemoteZipArchive(
          uri: Uri.parse('http://127.0.0.1:${server.port}/tools.zip'),
          client: client,
        );
        final ffmpeg = await remote.findUniqueFile('ffmpeg.exe');
        final ffprobe = await remote.findUniqueFile('ffprobe.exe');
        final ffmpegFile = File('${temporary.path}/ffmpeg.exe');
        final ffprobeFile = File('${temporary.path}/ffprobe.exe');

        await remote.extractEntry(ffmpeg, ffmpegFile);
        await remote.extractEntry(ffprobe, ffprobeFile);

        expect(await ffmpegFile.readAsString(), 'ffmpeg executable');
        expect(await ffprobeFile.readAsString(), 'ffprobe executable');
        // Tail + central directory + header/data for exactly two files.
        expect(requestedRanges, hasLength(6));
      } finally {
        client.close();
        await temporary.delete(recursive: true);
      }
    });

    test('rejects a selected entry when CRC-32 does not match', () async {
      final client = http.Client();
      final temporary = await Directory.systemTemp.createTemp(
        'mbn_remote_zip_crc_test_',
      );
      try {
        final remote = RemoteZipArchive(
          uri: Uri.parse('http://127.0.0.1:${server.port}/tools.zip'),
          client: client,
        );
        final entry = await remote.findUniqueFile('ffmpeg.exe');
        final invalidEntry = RemoteZipEntry(
          name: entry.name,
          flags: entry.flags,
          compressionMethod: entry.compressionMethod,
          crc32: entry.crc32 ^ 1,
          compressedSize: entry.compressedSize,
          uncompressedSize: entry.uncompressedSize,
          localHeaderOffset: entry.localHeaderOffset,
        );
        final output = File('${temporary.path}/ffmpeg.exe');

        await expectLater(
          remote.extractEntry(invalidEntry, output),
          throwsA(isA<FormatException>()),
        );
        expect(await output.exists(), isFalse);
      } finally {
        client.close();
        await temporary.delete(recursive: true);
      }
    });
  });
}

(int, int) _parseRange(String header, int length) {
  final suffix = RegExp(r'^bytes=-(\d+)$').firstMatch(header);
  if (suffix != null) {
    final count = int.parse(suffix.group(1)!);
    return ((length - count).clamp(0, length - 1), length - 1);
  }
  final explicit = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(header);
  if (explicit == null) throw FormatException('Unexpected range: $header');
  return (int.parse(explicit.group(1)!), int.parse(explicit.group(2)!));
}

Uint8List _buildZip(Map<String, List<int>> files) {
  final output = BytesBuilder(copy: false);
  final records = <_ZipRecord>[];

  for (final file in files.entries) {
    final name = utf8.encode(file.key);
    final compressed = ZLibEncoder(raw: true).convert(file.value);
    final record = _ZipRecord(
      name: name,
      crc32: updateZipCrc32(0, file.value),
      compressed: compressed,
      uncompressedSize: file.value.length,
      localOffset: output.length,
    );
    records.add(record);

    _writeUint32(output, 0x04034b50);
    _writeUint16(output, 20);
    _writeUint16(output, 0x0800);
    _writeUint16(output, 8);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint32(output, record.crc32);
    _writeUint32(output, compressed.length);
    _writeUint32(output, file.value.length);
    _writeUint16(output, name.length);
    _writeUint16(output, 0);
    output
      ..add(name)
      ..add(compressed);
  }

  final centralOffset = output.length;
  for (final record in records) {
    _writeUint32(output, 0x02014b50);
    _writeUint16(output, 20);
    _writeUint16(output, 20);
    _writeUint16(output, 0x0800);
    _writeUint16(output, 8);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint32(output, record.crc32);
    _writeUint32(output, record.compressed.length);
    _writeUint32(output, record.uncompressedSize);
    _writeUint16(output, record.name.length);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint32(output, 0);
    _writeUint32(output, record.localOffset);
    output.add(record.name);
  }
  final centralSize = output.length - centralOffset;

  _writeUint32(output, 0x06054b50);
  _writeUint16(output, 0);
  _writeUint16(output, 0);
  _writeUint16(output, records.length);
  _writeUint16(output, records.length);
  _writeUint32(output, centralSize);
  _writeUint32(output, centralOffset);
  _writeUint16(output, 0);
  return output.takeBytes();
}

void _writeUint16(BytesBuilder output, int value) {
  output.add([value & 0xff, (value >> 8) & 0xff]);
}

void _writeUint32(BytesBuilder output, int value) {
  output.add([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

class _ZipRecord {
  const _ZipRecord({
    required this.name,
    required this.crc32,
    required this.compressed,
    required this.uncompressedSize,
    required this.localOffset,
  });

  final List<int> name;
  final int crc32;
  final List<int> compressed;
  final int uncompressedSize;
  final int localOffset;
}
