import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database/database_service.dart';
import '../../services/logger/app_logger.dart';
import '../models/recent_link.dart';

final recentLinksProvider =
    AsyncNotifierProvider<RecentLinksNotifier, List<RecentLink>>(
      RecentLinksNotifier.new,
    );

class RecentLinksNotifier extends AsyncNotifier<List<RecentLink>> {
  @override
  Future<List<RecentLink>> build() =>
      DatabaseService.instance.getAllRecentLinks();

  Future<void> loadRecentLinks() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(DatabaseService.instance.getAllRecentLinks);
  }

  Future<RecentLink> addRecentLink(RecentLink link) async {
    try {
      final id = await DatabaseService.instance.insertRecentLink(link);
      final inserted = link.copyWith(id: id);
      await loadRecentLinks();
      return inserted;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to add recent link', error, stackTrace);
      rethrow;
    }
  }

  Future<RecentLink?> getRecentLinkByUrl(String url) async {
    try {
      return DatabaseService.instance.getRecentLinkByUrl(url);
    } catch (error, stackTrace) {
      AppLogger.error('Failed to find recent link', error, stackTrace);
      return null;
    }
  }

  Future<void> deleteRecentLink(int id) async {
    await DatabaseService.instance.deleteRecentLink(id);
    final current = state.asData?.value ?? const <RecentLink>[];
    state = AsyncData(current.where((link) => link.id != id).toList());
  }

  Future<void> clearAllRecentLinks() async {
    await DatabaseService.instance.clearAllRecentLinks();
    state = const AsyncData([]);
  }

  Future<List<RecentLink>> searchRecentLinks(String query) async {
    try {
      return DatabaseService.instance.searchRecentLinks(query);
    } catch (error, stackTrace) {
      AppLogger.error('Failed to search recent links', error, stackTrace);
      return const [];
    }
  }
}
