import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database/database_service.dart';
import '../../services/logger/app_logger.dart';
import '../models/download_item.dart';

enum DownloadSortBy {
  dateNewest,
  dateOldest,
  titleAZ,
  titleZA,
  sizeSmallest,
  sizeLargest,
}

final downloadSortProvider =
    NotifierProvider<DownloadSortNotifier, DownloadSortBy>(
      DownloadSortNotifier.new,
    );

class DownloadSortNotifier extends Notifier<DownloadSortBy> {
  @override
  DownloadSortBy build() => DownloadSortBy.dateNewest;

  void setSort(DownloadSortBy value) => state = value;
}

final downloadsProvider =
    AsyncNotifierProvider<DownloadsNotifier, List<DownloadItem>>(
      DownloadsNotifier.new,
    );

class DownloadsNotifier extends AsyncNotifier<List<DownloadItem>> {
  @override
  Future<List<DownloadItem>> build() async {
    try {
      final downloads = await DatabaseService.instance.getAllDownloads();
      AppLogger.debug('Loaded ${downloads.length} downloads');
      return downloads;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load downloads', error, stackTrace);
      rethrow;
    }
  }

  Future<void> loadDownloads() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(DatabaseService.instance.getAllDownloads);
  }

  Future<DownloadItem> addDownload(DownloadItem item) async {
    try {
      final id = await DatabaseService.instance.insertDownload(item);
      final inserted = item.copyWith(id: id);
      final current = state.asData?.value ?? const <DownloadItem>[];
      state = AsyncData([inserted, ...current]);
      AppLogger.info('Added download: ${item.title}');
      return inserted;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to add download', error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateDownload(DownloadItem item) async {
    try {
      await DatabaseService.instance.updateDownload(item);
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData([
        for (final download in current)
          if (download.id == item.id) item else download,
      ]);
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update download', error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteDownload(int id) async {
    try {
      await DatabaseService.instance.deleteDownload(id);
      final current = state.asData?.value ?? const <DownloadItem>[];
      state = AsyncData(
        current.where((download) => download.id != id).toList(),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to delete download', error, stackTrace);
      rethrow;
    }
  }

  Future<void> clearAllDownloads() async {
    await DatabaseService.instance.clearAllDownloads();
    state = const AsyncData([]);
  }

  Future<void> clearCompletedDownloads() async {
    await DatabaseService.instance.clearCompletedDownloads();
    final current = state.asData?.value ?? const <DownloadItem>[];
    state = AsyncData(
      current
          .where((download) => download.status != DownloadStatus.completed)
          .toList(),
    );
  }

  List<DownloadItem> getSortedDownloads(
    List<DownloadItem> downloads,
    DownloadSortBy sortBy,
  ) {
    final sorted = List<DownloadItem>.of(downloads);
    switch (sortBy) {
      case DownloadSortBy.dateNewest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case DownloadSortBy.dateOldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case DownloadSortBy.titleAZ:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case DownloadSortBy.titleZA:
        sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case DownloadSortBy.sizeSmallest:
        sorted.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
      case DownloadSortBy.sizeLargest:
        sorted.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));
    }
    return sorted;
  }
}

final sortedDownloadsProvider = Provider<List<DownloadItem>>((ref) {
  final downloads = ref.watch(downloadsProvider).asData?.value;
  if (downloads == null) return const [];
  return ref
      .read(downloadsProvider.notifier)
      .getSortedDownloads(downloads, ref.watch(downloadSortProvider));
});
