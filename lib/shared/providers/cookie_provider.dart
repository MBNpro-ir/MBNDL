import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/cookie_storage_service.dart';
import '../models/cookie_item.dart';

class CookieState {
  const CookieState({this.cookies = const [], this.selectedCookieId});

  final List<CookieItem> cookies;
  final String? selectedCookieId;

  CookieState copyWith({
    List<CookieItem>? cookies,
    String? selectedCookieId,
    bool clearSelection = false,
  }) {
    return CookieState(
      cookies: cookies ?? this.cookies,
      selectedCookieId: clearSelection
          ? null
          : selectedCookieId ?? this.selectedCookieId,
    );
  }

  CookieItem? get selectedCookie {
    if (selectedCookieId == null) return null;
    return cookies.where((cookie) => cookie.id == selectedCookieId).firstOrNull;
  }
}

final cookieProvider = NotifierProvider<CookieNotifier, CookieState>(
  CookieNotifier.new,
);

class CookieNotifier extends Notifier<CookieState> {
  @override
  CookieState build() => _readState();

  CookieState _readState() => CookieState(
    cookies: CookieStorageService.instance.getCookies(),
    selectedCookieId: CookieStorageService.instance.getSelectedCookieId(),
  );

  void _reload() => state = _readState();

  Future<void> addCookie(CookieItem cookie) async {
    await CookieStorageService.instance.addCookie(cookie);
    _reload();
  }

  Future<void> updateCookie(CookieItem cookie) async {
    await CookieStorageService.instance.updateCookie(cookie);
    _reload();
  }

  Future<void> deleteCookie(String id) async {
    await CookieStorageService.instance.deleteCookie(id);
    _reload();
  }

  Future<void> selectCookie(String id) async {
    await CookieStorageService.instance.selectCookie(id);
    _reload();
  }

  Future<void> clearSelection() async {
    await CookieStorageService.instance.clearSelection();
    _reload();
  }
}
