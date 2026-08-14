import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.name,
    required this.notes,
    required this.assetName,
    required this.downloadUrl,
    required this.size,
    this.sha256Digest,
  });

  final String version;
  final String tag;
  final String name;
  final String notes;
  final String assetName;
  final String downloadUrl;
  final int size;
  final String? sha256Digest;
}

class AppUpdateService {
  AppUpdateService._();

  static final instance = AppUpdateService._();
  static const _releaseEndpoint =
      'https://api.github.com/repos/MBNpro-ir/MBNDL/releases/latest';
  static const _androidChannel = MethodChannel('com.mbn.dl/app_updates');

  Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<AppRelease?> checkForUpdate() async {
    if (!Platform.isWindows && !Platform.isAndroid) return null;

    final response = await http
        .get(
          Uri.parse(_releaseEndpoint),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'MBNDL-app-updater',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub release check failed (${response.statusCode}).',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final latestVersion = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final installedVersion = await currentVersion();
    if (!_isNewer(latestVersion, installedVersion)) return null;

    final expectedAsset = await _expectedAssetName();
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    Map<String, dynamic>? selected;
    for (final asset in assets) {
      if (asset['name'] == expectedAsset) {
        selected = asset;
        break;
      }
    }
    if (selected == null) {
      throw StateError('$expectedAsset is missing from release $tag.');
    }

    final digestValue = selected['digest'] as String?;
    final digest = digestValue?.startsWith('sha256:') == true
        ? digestValue!.substring('sha256:'.length).toLowerCase()
        : null;
    return AppRelease(
      version: latestVersion,
      tag: tag,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : tag,
      notes: json['body'] as String? ?? '',
      assetName: expectedAsset,
      downloadUrl: selected['browser_download_url'] as String,
      size: (selected['size'] as num?)?.toInt() ?? 0,
      sha256Digest: digest,
    );
  }

  Future<File> download(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      p.join(root.path, 'MBNDL', 'updates', release.tag),
    );
    await directory.create(recursive: true);
    final output = File(p.join(directory.path, release.assetName));
    final partial = File('${output.path}.part');
    if (await partial.exists()) await partial.delete();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      request.headers['User-Agent'] = 'MBNDL-app-updater';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Update download failed (${response.statusCode}).');
      }

      final total = response.contentLength ?? release.size;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress((received / total).clamp(0, 1));
        }
      } finally {
        await sink.close();
      }

      if (release.sha256Digest != null) {
        final actual = (await sha256.bind(partial.openRead()).first).toString();
        if (actual.toLowerCase() != release.sha256Digest) {
          await partial.delete();
          throw const FormatException(
            'The downloaded update failed its SHA-256 integrity check.',
          );
        }
      }
      if (await output.exists()) await output.delete();
      final complete = await partial.rename(output.path);
      onProgress(1);
      return complete;
    } finally {
      client.close();
    }
  }

  Future<bool> install(File package) async {
    if (Platform.isAndroid) {
      return await _androidChannel.invokeMethod<bool>('installApk', {
            'path': package.path,
          }) ??
          false;
    }
    if (Platform.isWindows) {
      await _startWindowsUpdater(package);
      return true;
    }
    return false;
  }

  Future<void> openAndroidInstallPermission() async {
    if (!Platform.isAndroid) return;
    await _androidChannel.invokeMethod<void>('openInstallPermission');
  }

  Future<String> _expectedAssetName() async {
    if (Platform.isWindows) return 'MBNDL-Windows-x64.zip';
    final is64Bit =
        await _androidChannel.invokeMethod<bool>('is64BitDevice') ?? true;
    return is64Bit ? 'MBNDL-Android-arm64.apk' : 'MBNDL-Android-arm32.apk';
  }

  Future<void> _startWindowsUpdater(File package) async {
    final executable = File(Platform.resolvedExecutable).absolute;
    final bundledUpdater = File(p.join(executable.parent.path, 'updater.exe'));
    if (!await bundledUpdater.exists()) {
      throw StateError('updater.exe is missing beside MBNDL.exe.');
    }

    final root = await getTemporaryDirectory();
    final launcher = File(
      p.join(
        root.path,
        'MBNDL',
        'updater-launcher-${DateTime.now().millisecondsSinceEpoch}.exe',
      ),
    );
    await launcher.parent.create(recursive: true);
    await bundledUpdater.copy(launcher.path);
    await Process.start(launcher.path, [
      '--package',
      package.absolute.path,
      '--target',
      executable.parent.path,
      '--pid',
      pid.toString(),
      '--restart',
      executable.path,
    ], mode: ProcessStartMode.detached);
    AppLogger.info('Windows updater started for ${package.path}');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    exit(0);
  }

  bool _isNewer(String candidate, String installed) {
    final a = _numericVersion(candidate);
    final b = _numericVersion(installed);
    for (var index = 0; index < 4; index++) {
      if (a[index] != b[index]) return a[index] > b[index];
    }
    return false;
  }

  List<int> _numericVersion(String value) {
    final core = value.split(RegExp(r'[-+]')).first;
    final parts = core.split('.');
    return List<int>.generate(
      4,
      (index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }
}
