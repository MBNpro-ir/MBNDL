import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../logger/app_logger.dart';

final class _InternetProxyInfo extends Struct {
  @Uint32()
  external int accessType;

  external Pointer<Utf16> proxy;
  external Pointer<Utf16> bypass;
}

typedef _InternetQueryOptionNative =
    Int32 Function(
      IntPtr internet,
      Uint32 option,
      Pointer<Void> buffer,
      Pointer<Uint32> bufferLength,
    );
typedef _InternetQueryOptionDart =
    int Function(
      int internet,
      int option,
      Pointer<Void> buffer,
      Pointer<Uint32> bufferLength,
    );
typedef _GlobalFreeNative = Pointer<Void> Function(Pointer<Void> memory);
typedef _GlobalFreeDart = Pointer<Void> Function(Pointer<Void> memory);

class WindowsSystemProxyService {
  WindowsSystemProxyService._();

  static final WindowsSystemProxyService instance =
      WindowsSystemProxyService._();
  static const _internetOptionProxy = 38;
  static const _internetOpenTypeProxy = 3;

  /// Reads the current per-user WinINet configuration every time. This is
  /// deliberately not cached: changing Windows Settings must affect the next
  /// inspection or download without restarting MBNDL.
  Future<List<String>> ytDlpArgsFor(String targetUrl) async {
    if (!Platform.isWindows) return const [];
    try {
      final settings = _readProxySettings();
      if (settings == null || settings.proxy.trim().isEmpty) return const [];
      final target = Uri.tryParse(targetUrl);
      if (target != null && isBypassed(target, settings.bypass)) {
        AppLogger.debug('Windows system proxy bypassed for ${target.host}');
        return const [];
      }
      final selected = selectProxy(settings.proxy, target?.scheme ?? 'https');
      if (selected == null) return const [];
      AppLogger.info('Using Windows system proxy: ${redact(selected)}');
      return ['--proxy', selected];
    } catch (error, stackTrace) {
      // Proxy discovery should never make an otherwise direct download fail.
      AppLogger.warning(
        'Could not read Windows system proxy; using direct connection',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  _ProxySettings? _readProxySettings() {
    final wininet = DynamicLibrary.open('wininet.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final query = wininet
        .lookupFunction<_InternetQueryOptionNative, _InternetQueryOptionDart>(
          'InternetQueryOptionW',
        );
    final globalFree = kernel32
        .lookupFunction<_GlobalFreeNative, _GlobalFreeDart>('GlobalFree');
    final info = calloc<_InternetProxyInfo>();
    final length = calloc<Uint32>()..value = sizeOf<_InternetProxyInfo>();
    Pointer<Utf16> proxyPointer = nullptr;
    Pointer<Utf16> bypassPointer = nullptr;
    try {
      final ok = query(0, _internetOptionProxy, info.cast<Void>(), length);
      if (ok == 0 || info.ref.accessType != _internetOpenTypeProxy) return null;
      proxyPointer = info.ref.proxy;
      bypassPointer = info.ref.bypass;
      return _ProxySettings(
        proxy: proxyPointer == nullptr ? '' : proxyPointer.toDartString(),
        bypass: bypassPointer == nullptr ? '' : bypassPointer.toDartString(),
      );
    } finally {
      if (proxyPointer != nullptr) globalFree(proxyPointer.cast<Void>());
      if (bypassPointer != nullptr) globalFree(bypassPointer.cast<Void>());
      calloc.free(length);
      calloc.free(info);
    }
  }

  @visibleForTesting
  static String? selectProxy(String rawList, String targetScheme) {
    final source = rawList.trim();
    if (source.isEmpty) return null;
    final entries = <String, String>{};
    String? generic;
    for (final segment in source.split(RegExp(r'[;\s]+'))) {
      final value = segment.trim();
      if (value.isEmpty) continue;
      final separator = value.indexOf('=');
      if (separator > 0) {
        entries[value.substring(0, separator).toLowerCase()] = value.substring(
          separator + 1,
        );
      } else {
        generic ??= value;
      }
    }
    final scheme = targetScheme.toLowerCase();
    final selected =
        entries[scheme] ??
        entries[scheme == 'https' ? 'http' : 'https'] ??
        entries['socks'] ??
        generic;
    if (selected == null || selected.trim().isEmpty) return null;
    final normalized = selected.trim();
    if (normalized.contains('://')) return normalized;
    final isSocks = entries['socks'] == selected;
    return '${isSocks ? 'socks5' : 'http'}://$normalized';
  }

  @visibleForTesting
  static bool isBypassed(Uri target, String rawBypass) {
    final host = target.host.toLowerCase();
    if (host.isEmpty || rawBypass.trim().isEmpty) return false;
    for (final raw in rawBypass.split(RegExp(r'[;\s]+'))) {
      final rule = raw.trim().toLowerCase();
      if (rule.isEmpty) continue;
      if (rule == '<local>' && !host.contains('.')) return true;
      final withoutScheme = rule.replaceFirst(RegExp(r'^https?://'), '');
      final withoutPort = withoutScheme.replaceFirst(RegExp(r':\d+$'), '');
      final pattern =
          '^${RegExp.escape(withoutPort).replaceAll(r'\*', '.*')}\$';
      if (RegExp(pattern, caseSensitive: false).hasMatch(host)) return true;
    }
    return false;
  }

  @visibleForTesting
  static String redact(String proxy) {
    final uri = Uri.tryParse(proxy);
    if (uri == null || uri.userInfo.isEmpty) return proxy;
    return uri.replace(userInfo: '***').toString();
  }
}

class _ProxySettings {
  const _ProxySettings({required this.proxy, required this.bypass});

  final String proxy;
  final String bypass;
}
