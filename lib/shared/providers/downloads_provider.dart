import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database/database_service.dart';
import '../../services/downloader/download_error_mapper.dart';
import '../../services/downloader/download_service.dart';
import '../../services/logger/app_logger.dart';
import '../../features/settings/domain/yt_dlp_settings.dart';
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
  final Queue<_QueuedDownload> _queue = ListQueue<_QueuedDownload>();
  final Set<int> _cancelledIds = <int>{};
  Future<void> _serviceUpdateChain = Future<void>.value();
  bool _isPumping = false;
  bool _downloadServiceReady = false;

  @override
  Future<List<DownloadItem>> build() async {
    try {
      final downloads = await DatabaseService.instance.getAllDownloads();
      final recovered = <DownloadItem>[];
      for (final download in downloads) {
        if (_isActive(download.status)) {
          final interrupted = download.copyWith(
            status: DownloadStatus.failed,
            errorMessage:
                'The app closed before this download finished. Tap Retry to continue.',
            clearCurrentPhase: true,
          );
          await DatabaseService.instance.updateDownload(interrupted);
          recovered.add(interrupted);
        } else {
          recovered.add(download);
        }
      }
      AppLogger.debug('Loaded ${downloads.length} downloads');
      return recovered;
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

  Future<DownloadItem> enqueueDownload({
    required DownloadItem item,
    required YtDlpSettings settings,
  }) async {
    final inserted = await addDownload(item);
    _queue.add(_QueuedDownload(inserted, settings));
    unawaited(_pumpQueue());
    return inserted;
  }

  Future<void> retryDownload({
    required DownloadItem item,
    required YtDlpSettings settings,
  }) async {
    if (item.id == null) return;
    _queue.removeWhere((task) => task.item.id == item.id);
    final pending = item.copyWith(
      status: DownloadStatus.pending,
      progress: 0,
      clearErrorMessage: true,
      clearCurrentPhase: true,
    );
    await updateDownload(pending);
    _queue.add(_QueuedDownload(pending, settings));
    unawaited(_pumpQueue());
  }

  Future<void> cancelDownload(DownloadItem item) async {
    final id = item.id;
    if (id == null) return;
    final wasQueued = _queue.any((task) => task.item.id == id);
    _queue.removeWhere((task) => task.item.id == id);
    if (!wasQueued) {
      _cancelledIds.add(id);
      await DownloadService.instance.cancelDownload(id);
    }
    await updateDownload(
      item.copyWith(
        status: DownloadStatus.cancelled,
        errorMessage: 'Download cancelled by user.',
        clearCurrentPhase: true,
      ),
    );
  }

  Future<void> _pumpQueue() async {
    if (_isPumping) return;
    _isPumping = true;
    try {
      while (_queue.isNotEmpty) {
        final task = _queue.removeFirst();
        final current = _findById(task.item.id);
        if (current?.status == DownloadStatus.cancelled) continue;

        try {
          final processing = (current ?? task.item).copyWith(
            status: DownloadStatus.processing,
            progress: 0,
            clearErrorMessage: true,
            currentPhase: 'Preparing',
          );
          await updateDownload(processing);
          if (!_downloadServiceReady) {
            await DownloadService.instance.initialize();
            _downloadServiceReady = true;
          }
          if (_cancelledIds.contains(task.item.id)) {
            await _restoreCancellationIfNeeded(task.item.id);
            continue;
          }
          await DownloadService.instance.startDownload(
            item: processing,
            settings: task.settings,
            onUpdate: _acceptServiceUpdate,
          );
          await _restoreCancellationIfNeeded(task.item.id);
        } catch (error, stackTrace) {
          AppLogger.error('Queued download failed', error, stackTrace);
          if (await _restoreCancellationIfNeeded(task.item.id)) continue;
          final latest = _findById(task.item.id);
          if (latest != null &&
              latest.status != DownloadStatus.completed &&
              latest.status != DownloadStatus.cancelled &&
              latest.status != DownloadStatus.failed) {
            final friendly = DownloadErrorMapper.from(error);
            await updateDownload(
              latest.copyWith(
                status: DownloadStatus.failed,
                errorMessage: friendly.displayText,
                clearCurrentPhase: true,
              ),
            );
          }
        }
      }
    } finally {
      _isPumping = false;
      if (_queue.isNotEmpty) unawaited(_pumpQueue());
    }
  }

  DownloadItem? _findById(int? id) {
    if (id == null) return null;
    for (final item in state.asData?.value ?? const <DownloadItem>[]) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _acceptServiceUpdate(DownloadItem updated) {
    final id = updated.id;
    if (id != null && _cancelledIds.contains(id)) return;

    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData([
        for (final item in current)
          if (item.id == updated.id) updated else item,
      ]);
    }
    // Progress callbacks may arrive very quickly. Serialize their database
    // writes so an older percentage can never overwrite a final status.
    _serviceUpdateChain = _serviceUpdateChain
        .then<void>((_) async {
          await DatabaseService.instance.updateDownload(updated);
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.error(
            'Failed to persist a download progress update',
            error,
            stackTrace,
          );
        });
  }

  Future<bool> _restoreCancellationIfNeeded(int? id) async {
    if (id == null || !_cancelledIds.remove(id)) return false;
    final latest = _findById(id);
    if (latest != null && latest.status != DownloadStatus.cancelled) {
      await updateDownload(
        latest.copyWith(
          status: DownloadStatus.cancelled,
          errorMessage: 'Download cancelled by user.',
          clearCurrentPhase: true,
        ),
      );
    }
    return true;
  }

  bool _isActive(DownloadStatus status) =>
      status == DownloadStatus.pending ||
      status == DownloadStatus.processing ||
      status == DownloadStatus.downloading;

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

class _QueuedDownload {
  const _QueuedDownload(this.item, this.settings);

  final DownloadItem item;
  final YtDlpSettings settings;
}

final sortedDownloadsProvider = Provider<List<DownloadItem>>((ref) {
  final downloads = ref.watch(downloadsProvider).asData?.value;
  if (downloads == null) return const [];
  return ref
      .read(downloadsProvider.notifier)
      .getSortedDownloads(downloads, ref.watch(downloadSortProvider));
});
