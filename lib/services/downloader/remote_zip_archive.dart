import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A ZIP entry that can be fetched independently with HTTP range requests.
class RemoteZipEntry {
  const RemoteZipEntry({
    required this.name,
    required this.flags,
    required this.compressionMethod,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String name;
  final int flags;
  final int compressionMethod;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

/// Reads a normal (non-ZIP64) remote ZIP without downloading the whole file.
///
/// Only the end-of-central-directory, the central directory, local headers and
/// explicitly selected compressed entries are transferred. This is useful for
/// large tool bundles that contain binaries the app does not need.
class RemoteZipArchive {
  RemoteZipArchive({
    required this.uri,
    required http.Client client,
    this.requestTimeout = const Duration(seconds: 30),
    this.streamTimeout = const Duration(seconds: 45),
    this.headers = const {},
  }) : _client = client;

  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _centralDirectorySignature = 0x02014b50;
  static const int _localFileHeaderSignature = 0x04034b50;
  static const int _maximumTailLength = 65_535 + 22;

  final Uri uri;
  final http.Client _client;
  final Duration requestTimeout;
  final Duration streamTimeout;
  final Map<String, String> headers;

  int? _archiveLength;
  String? _etag;
  List<RemoteZipEntry>? _entries;

  /// Reads and caches the ZIP central directory.
  Future<List<RemoteZipEntry>> readEntries() async {
    final cached = _entries;
    if (cached != null) return cached;

    final tailResponse = await _openRange('bytes=-$_maximumTailLength');
    final tail = await _collectBytes(
      tailResponse.stream.timeout(streamTimeout),
    );
    final endOffset = _findEndOfCentralDirectory(tail);

    final diskNumber = _uint16(tail, endOffset + 4);
    final centralDirectoryDisk = _uint16(tail, endOffset + 6);
    final entriesOnDisk = _uint16(tail, endOffset + 8);
    final totalEntries = _uint16(tail, endOffset + 10);
    final centralDirectorySize = _uint32(tail, endOffset + 12);
    final centralDirectoryOffset = _uint32(tail, endOffset + 16);

    if (diskNumber != 0 ||
        centralDirectoryDisk != 0 ||
        entriesOnDisk != totalEntries) {
      throw const FormatException('Multi-disk ZIP archives are unsupported');
    }
    if (totalEntries == 0xffff ||
        centralDirectorySize == 0xffffffff ||
        centralDirectoryOffset == 0xffffffff) {
      throw const FormatException('ZIP64 archives are unsupported');
    }

    final archiveLength = _archiveLength!;
    if (centralDirectorySize <= 0 ||
        centralDirectoryOffset < 0 ||
        centralDirectoryOffset + centralDirectorySize > archiveLength) {
      throw const FormatException('Invalid ZIP central-directory bounds');
    }

    final directory = await _readRange(
      centralDirectoryOffset,
      centralDirectoryOffset + centralDirectorySize - 1,
    );
    final parsed = <RemoteZipEntry>[];
    var offset = 0;

    while (offset < directory.length) {
      if (directory.length - offset < 46 ||
          _uint32(directory, offset) != _centralDirectorySignature) {
        throw const FormatException('Invalid ZIP central-directory entry');
      }

      final flags = _uint16(directory, offset + 8);
      final compressionMethod = _uint16(directory, offset + 10);
      final crc32 = _uint32(directory, offset + 16);
      final compressedSize = _uint32(directory, offset + 20);
      final uncompressedSize = _uint32(directory, offset + 24);
      final nameLength = _uint16(directory, offset + 28);
      final extraLength = _uint16(directory, offset + 30);
      final commentLength = _uint16(directory, offset + 32);
      final localHeaderOffset = _uint32(directory, offset + 42);
      final entryLength = 46 + nameLength + extraLength + commentLength;

      if (offset + entryLength > directory.length) {
        throw const FormatException('Truncated ZIP central-directory entry');
      }

      final nameBytes = directory.sublist(
        offset + 46,
        offset + 46 + nameLength,
      );
      final name = (flags & 0x0800) != 0
          ? utf8.decode(nameBytes, allowMalformed: true)
          : latin1.decode(nameBytes);

      parsed.add(
        RemoteZipEntry(
          name: name,
          flags: flags,
          compressionMethod: compressionMethod,
          crc32: crc32,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          localHeaderOffset: localHeaderOffset,
        ),
      );
      offset += entryLength;
    }

    if (parsed.length != totalEntries) {
      throw FormatException(
        'ZIP entry count mismatch: expected $totalEntries, got ${parsed.length}',
      );
    }

    _entries = List.unmodifiable(parsed);
    return _entries!;
  }

  /// Finds one file by basename, regardless of its directory in the archive.
  Future<RemoteZipEntry> findUniqueFile(String basename) async {
    final normalized = basename.toLowerCase();
    final matches = (await readEntries()).where((entry) {
      final name = entry.name.replaceAll('\\', '/').toLowerCase();
      return name == normalized || name.endsWith('/$normalized');
    }).toList();

    if (matches.length != 1) {
      throw StateError(
        'Expected exactly one $basename entry, found ${matches.length}',
      );
    }
    return matches.single;
  }

  /// Downloads, inflates and verifies one selected entry to [destination].
  Future<void> extractEntry(
    RemoteZipEntry entry,
    File destination, {
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    if ((entry.flags & 0x0001) != 0) {
      throw const FormatException('Encrypted ZIP entries are unsupported');
    }
    if (entry.compressionMethod != 0 && entry.compressionMethod != 8) {
      throw FormatException(
        'Unsupported ZIP compression method ${entry.compressionMethod}',
      );
    }

    final localHeader = await _readRange(
      entry.localHeaderOffset,
      entry.localHeaderOffset + 29,
    );
    if (_uint32(localHeader, 0) != _localFileHeaderSignature) {
      throw const FormatException('Invalid ZIP local-file header');
    }

    final localFlags = _uint16(localHeader, 6);
    final localMethod = _uint16(localHeader, 8);
    final nameLength = _uint16(localHeader, 26);
    final extraLength = _uint16(localHeader, 28);
    if ((localFlags & 0x0001) != 0 || localMethod != entry.compressionMethod) {
      throw const FormatException('ZIP local header does not match directory');
    }

    final dataStart = entry.localHeaderOffset + 30 + nameLength + extraLength;
    await destination.parent.create(recursive: true);
    if (await destination.exists()) await destination.delete();

    if (entry.compressedSize == 0) {
      await destination.create();
      if (entry.uncompressedSize != 0 || entry.crc32 != 0) {
        await destination.delete();
        throw const FormatException('Invalid empty ZIP entry');
      }
      onProgress?.call(0, 0);
      return;
    }

    IOSink? sink;
    try {
      final response = await _openRange(
        'bytes=$dataStart-${dataStart + entry.compressedSize - 1}',
        expectedStart: dataStart,
        expectedEnd: dataStart + entry.compressedSize - 1,
      );

      var receivedBytes = 0;
      Stream<List<int>> compressed = response.stream.timeout(streamTimeout).map(
        (chunk) {
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, entry.compressedSize);
          return chunk;
        },
      );
      final uncompressed = entry.compressionMethod == 8
          ? compressed.transform(ZLibDecoder(raw: true))
          : compressed;

      sink = destination.openWrite();
      var writtenBytes = 0;
      var actualCrc32 = 0;
      await for (final chunk in uncompressed) {
        sink.add(chunk);
        writtenBytes += chunk.length;
        actualCrc32 = updateZipCrc32(actualCrc32, chunk);
      }
      await sink.close();
      sink = null;

      if (receivedBytes != entry.compressedSize ||
          writtenBytes != entry.uncompressedSize) {
        throw const FormatException('ZIP entry size verification failed');
      }
      if (actualCrc32 != entry.crc32) {
        throw const FormatException('ZIP entry CRC-32 verification failed');
      }
    } catch (_) {
      await sink?.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  int _findEndOfCentralDirectory(Uint8List bytes) {
    for (var offset = bytes.length - 22; offset >= 0; offset--) {
      if (_uint32(bytes, offset) != _endOfCentralDirectorySignature) continue;
      final commentLength = _uint16(bytes, offset + 20);
      if (offset + 22 + commentLength == bytes.length) return offset;
    }
    throw const FormatException('ZIP end-of-central-directory was not found');
  }

  Future<Uint8List> _readRange(int start, int end) async {
    final response = await _openRange(
      'bytes=$start-$end',
      expectedStart: start,
      expectedEnd: end,
    );
    final bytes = await _collectBytes(response.stream.timeout(streamTimeout));
    if (bytes.length != end - start + 1) {
      throw const HttpException('Incomplete HTTP range response');
    }
    return bytes;
  }

  Future<http.StreamedResponse> _openRange(
    String range, {
    int? expectedStart,
    int? expectedEnd,
  }) async {
    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Accept': 'application/zip, application/octet-stream',
      'Accept-Encoding': 'identity',
      'Range': range,
      ...headers,
    });
    final etag = _etag;
    if (etag != null && !etag.startsWith('W/')) {
      request.headers['If-Range'] = etag;
    }

    final response = await _client.send(request).timeout(requestTimeout);
    if (response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
        'Server must honor byte ranges; received HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final contentRange = response.headers['content-range'];
    final match = contentRange == null
        ? null
        : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(contentRange.trim());
    if (match == null) {
      throw const HttpException('Invalid Content-Range response header');
    }

    final actualStart = int.parse(match.group(1)!);
    final actualEnd = int.parse(match.group(2)!);
    final totalLength = int.parse(match.group(3)!);
    if ((expectedStart != null && actualStart != expectedStart) ||
        (expectedEnd != null && actualEnd != expectedEnd)) {
      throw const HttpException('Server returned an unexpected byte range');
    }

    final knownLength = _archiveLength;
    if (knownLength != null && knownLength != totalLength) {
      throw const HttpException('Remote ZIP changed during download');
    }
    _archiveLength = totalLength;
    _etag ??= response.headers['etag'];
    return response;
  }
}

Future<Uint8List> _collectBytes(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Incrementally updates a standard ZIP CRC-32 value.
int updateZipCrc32(int previousCrc, List<int> bytes) {
  var crc = previousCrc ^ 0xffffffff;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

int _uint16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _uint32(List<int> bytes, int offset) =>
    (bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24)) &
    0xffffffff;

final List<int> _crc32Table = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >> 1) : value >> 1;
  }
  return value & 0xffffffff;
}, growable: false);
