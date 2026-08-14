import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/logger/app_logger.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../shared/models/download_item.dart';
import '../../../shared/providers/downloads_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../widgets/download_item_card.dart';

enum _LibraryStatus { all, active, completed, attention }

enum _DateFilter { all, today, last7Days, last30Days }

enum _MediaFilter { all, video, audio }

enum _ArtifactFilter { all, cover, subtitles, missing }

enum _HistoryMenuAction { clearCompleted, clearAll }

enum _BulkAction { retry, cancel, remove }

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  _LibraryStatus _status = _LibraryStatus.all;
  _DateFilter _date = _DateFilter.all;
  _MediaFilter _media = _MediaFilter.all;
  _ArtifactFilter _artifact = _ArtifactFilter.all;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadsAsync = ref.watch(downloadsProvider);
    final sorted = ref.watch(sortedDownloadsProvider);
    final sort = ref.watch(downloadSortProvider);
    final all = downloadsAsync.asData?.value ?? const <DownloadItem>[];
    final filtered = sorted.where(_matchesFilters).toList(growable: false);
    final groups = _groupDownloads(
      filtered,
      oldestFirst: sort == DownloadSortBy.dateOldest,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: ref.read(downloadsProvider.notifier).loadDownloads,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              title: Text(
                _selectionMode
                    ? '${_selectedIds.length} selected'
                    : 'Downloads',
              ),
              actions: [
                if (_selectionMode) ...[
                  IconButton(
                    tooltip:
                        _selectedIds.length == filtered.length &&
                            filtered.isNotEmpty
                        ? 'Clear selection'
                        : 'Select all results',
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _selectAll(filtered),
                    icon: Icon(
                      _selectedIds.length == filtered.length &&
                              filtered.isNotEmpty
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                  ),
                  PopupMenuButton<_BulkAction>(
                    tooltip: 'Actions for selected downloads',
                    enabled: _selectedIds.isNotEmpty,
                    onSelected: (action) => _handleBulkAction(action, all),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _BulkAction.retry,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.refresh_rounded),
                          title: Text('Retry eligible'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _BulkAction.cancel,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.stop_circle_outlined),
                          title: Text('Cancel active'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _BulkAction.remove,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Remove selected…'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Finish selecting',
                    onPressed: _exitSelectionMode,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Select downloads',
                    onPressed: () => setState(() => _selectionMode = true),
                    icon: const Icon(Icons.checklist_rounded),
                  ),
                  IconButton(
                    tooltip: 'Open Downloads/MBNDL',
                    onPressed: _openDownloads,
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                  PopupMenuButton<_HistoryMenuAction>(
                    tooltip: 'Library actions',
                    onSelected: _handleMenuAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _HistoryMenuAction.clearCompleted,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.playlist_remove_rounded),
                          title: Text('Clear completed'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _HistoryMenuAction.clearAll,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_sweep_outlined),
                          title: Text('Clear all history'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (downloadsAsync.isLoading)
                          const LinearProgressIndicator()
                        else if (downloadsAsync.hasError)
                          _LoadError(
                            onRetry: ref
                                .read(downloadsProvider.notifier)
                                .loadDownloads,
                          )
                        else ...[
                          _LibraryOverview(downloads: all),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: 'Search downloads',
                              helperText:
                                  'Title, source link, quality, or file type',
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StatusSelector(
                            selected: _status,
                            downloads: all,
                            onChanged: (value) =>
                                setState(() => _status = value),
                          ),
                          const SizedBox(height: 12),
                          _LibraryToolbar(
                            resultCount: filtered.length,
                            activeFilterCount: _activeFilterCount,
                            sort: sort,
                            onFilters: _showFilters,
                            onSort: (value) => ref
                                .read(downloadSortProvider.notifier)
                                .setSort(value),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (downloadsAsync.hasValue && filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: _EmptyLibrary(
                        hasDownloads: all.isNotEmpty,
                        onReset: _resetFilters,
                        onDownload: () => context.go('/home'),
                      ),
                    ),
                  ),
                ),
              )
            else
              for (final group in groups.entries) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.key,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '${group.value.length}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.crossAxisExtent >= 1180;
                      final rowCount = twoColumns
                          ? (group.value.length + 1) ~/ 2
                          : group.value.length;
                      return SliverList.separated(
                        itemCount: rowCount,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, rowIndex) {
                          final firstIndex = twoColumns
                              ? rowIndex * 2
                              : rowIndex;
                          final secondIndex = firstIndex + 1;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1320),
                              child: twoColumns
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _downloadCard(
                                            group.value[firstIndex],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              secondIndex < group.value.length
                                              ? _downloadCard(
                                                  group.value[secondIndex],
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    )
                                  : _downloadCard(group.value[firstIndex]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _downloadCard(DownloadItem item) {
    final retryable =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled;
    return DownloadItemCard(
      item: item,
      selectionMode: _selectionMode,
      selected: item.id != null && _selectedIds.contains(item.id),
      onSelectionChanged: item.id == null
          ? null
          : (_) => _toggleSelection(item),
      onCancel: _isActive(item) ? () => _cancel(item) : null,
      onRetry: retryable ? () => _retry(item) : null,
      onDelete: item.id == null ? null : () => _confirmDelete(item),
    );
  }

  Map<String, List<DownloadItem>> _groupDownloads(
    List<DownloadItem> items, {
    required bool oldestFirst,
  }) {
    final collected = <String, List<DownloadItem>>{};
    for (final item in items) {
      final label = _dateGroup(item.createdAt);
      collected.putIfAbsent(label, () => []).add(item);
    }
    const newestFirstLabels = <String>[
      'Today',
      'Yesterday',
      'Earlier this week',
      'This month',
      'Older',
    ];
    final labels = oldestFirst ? newestFirstLabels.reversed : newestFirstLabels;
    return {
      for (final label in labels)
        if (collected[label]?.isNotEmpty == true) label: collected[label]!,
    };
  }

  String _dateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    final days = today.difference(value).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return 'Earlier this week';
    if (date.year == now.year && date.month == now.month) return 'This month';
    return 'Older';
  }

  bool _matchesFilters(DownloadItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !item.title.toLowerCase().contains(query) &&
        !item.url.toLowerCase().contains(query) &&
        !(item.formatLabel?.toLowerCase().contains(query) ?? false) &&
        !(item.quality?.toLowerCase().contains(query) ?? false) &&
        !(item.fileExtension?.toLowerCase().contains(query) ?? false)) {
      return false;
    }

    final statusMatches = switch (_status) {
      _LibraryStatus.all => true,
      _LibraryStatus.active => _isActive(item),
      _LibraryStatus.completed => item.status == DownloadStatus.completed,
      _LibraryStatus.attention =>
        item.status == DownloadStatus.failed ||
            item.status == DownloadStatus.cancelled,
    };
    if (!statusMatches) return false;

    final cutoff = switch (_date) {
      _DateFilter.all => null,
      _DateFilter.today => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      _DateFilter.last7Days => DateTime.now().subtract(const Duration(days: 7)),
      _DateFilter.last30Days => DateTime.now().subtract(
        const Duration(days: 30),
      ),
    };
    if (cutoff != null && item.createdAt.isBefore(cutoff)) return false;

    final mediaMatches = switch (_media) {
      _MediaFilter.all => true,
      _MediaFilter.video =>
        item.downloadType == 'video' ||
            item.downloadType == 'combined' ||
            item.downloadType == 'separate',
      _MediaFilter.audio => item.downloadType == 'audio',
    };
    if (!mediaMatches) return false;

    return switch (_artifact) {
      _ArtifactFilter.all => true,
      _ArtifactFilter.cover => item.coverPath != null,
      _ArtifactFilter.subtitles => item.subtitlePaths.isNotEmpty,
      _ArtifactFilter.missing =>
        item.status == DownloadStatus.completed &&
            (item.filePath == null || !File(item.filePath!).existsSync()),
    };
  }

  int get _activeFilterCount =>
      (_date == _DateFilter.all ? 0 : 1) +
      (_media == _MediaFilter.all ? 0 : 1) +
      (_artifact == _ArtifactFilter.all ? 0 : 1);

  bool _isActive(DownloadItem item) =>
      item.status == DownloadStatus.pending ||
      item.status == DownloadStatus.processing ||
      item.status == DownloadStatus.downloading;

  void _toggleSelection(DownloadItem item) {
    final id = item.id;
    if (id == null) return;
    setState(() {
      _selectionMode = true;
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _selectAll(List<DownloadItem> visibleItems) {
    final visibleIds = visibleItems
        .map((item) => item.id)
        .whereType<int>()
        .toSet();
    setState(() {
      if (visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds)) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  List<DownloadItem> _selectedItems(List<DownloadItem> all) => all
      .where((item) => item.id != null && _selectedIds.contains(item.id))
      .toList(growable: false);

  Future<void> _handleBulkAction(
    _BulkAction action,
    List<DownloadItem> all,
  ) async {
    final selected = _selectedItems(all);
    if (selected.isEmpty) return;
    switch (action) {
      case _BulkAction.retry:
        final targets = selected
            .where(
              (item) =>
                  item.status == DownloadStatus.failed ||
                  item.status == DownloadStatus.cancelled,
            )
            .toList(growable: false);
        var queued = 0;
        for (final item in targets) {
          if (await _retry(item, notify: false)) queued++;
        }
        _message(
          queued == 0
              ? 'No selected download can be retried.'
              : '$queued download${queued == 1 ? '' : 's'} added to the queue.',
        );
        _exitSelectionMode();
      case _BulkAction.cancel:
        final targets = selected.where(_isActive).toList(growable: false);
        var cancelled = 0;
        for (final item in targets) {
          if (await _cancel(item, notify: false)) cancelled++;
        }
        _message(
          cancelled == 0
              ? 'No selected download is active.'
              : '$cancelled active download${cancelled == 1 ? '' : 's'} cancelled.',
        );
        _exitSelectionMode();
      case _BulkAction.remove:
        await _confirmBulkDelete(selected);
    }
  }

  Future<void> _confirmBulkDelete(List<DownloadItem> items) async {
    var deleteFiles = items.any(
      (item) => item.filePath != null || item.publicUris.isNotEmpty,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.delete_sweep_outlined),
          title: Text('Remove ${items.length} downloads?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The selected entries will be removed from History.'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) =>
                    setDialogState(() => deleteFiles = value ?? false),
                title: const Text('Delete files from the device'),
                subtitle: const Text(
                  'Includes media, covers, subtitles, and Android copies',
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove selected'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    var removed = 0;
    for (final item in items) {
      if (await _delete(item, deleteFiles: deleteFiles, notify: false)) {
        removed++;
      }
    }
    _exitSelectionMode();
    _message('$removed download${removed == 1 ? '' : 's'} removed.');
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _status = _LibraryStatus.all;
      _date = _DateFilter.all;
      _media = _MediaFilter.all;
      _artifact = _ArtifactFilter.all;
    });
  }

  Future<void> _showFilters() async {
    var date = _date;
    var media = _media;
    var artifact = _artifact;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter downloads',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _FilterChoices<_DateFilter>(
                  title: 'Added',
                  values: _DateFilter.values,
                  selected: date,
                  label: (value) => value.label,
                  onSelected: (value) => setSheetState(() => date = value),
                ),
                const SizedBox(height: 20),
                _FilterChoices<_MediaFilter>(
                  title: 'Media',
                  values: _MediaFilter.values,
                  selected: media,
                  label: (value) => value.label,
                  onSelected: (value) => setSheetState(() => media = value),
                ),
                const SizedBox(height: 20),
                _FilterChoices<_ArtifactFilter>(
                  title: 'Files and extras',
                  values: _ArtifactFilter.values,
                  selected: artifact,
                  label: (value) => value.label,
                  onSelected: (value) => setSheetState(() => artifact = value),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            date = _DateFilter.all;
                            media = _MediaFilter.all;
                            artifact = _ArtifactFilter.all;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Show results'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      setState(() {
        _date = date;
        _media = media;
        _artifact = artifact;
      });
    }
  }

  Future<bool> _retry(DownloadItem item, {bool notify = true}) async {
    if (item.id == null || item.formatId == null) {
      if (notify) {
        _message(
          'This older item has no saved format. Inspect the link again.',
        );
      }
      return false;
    }
    final base = ref.read(ytDlpSettingsProvider);
    final settings = base.copyWith(
      selectedFormatId: item.formatId,
      downloadType: item.downloadType ?? 'combined',
      extractAudio: item.downloadType == 'audio' ? base.extractAudio : false,
      downloadThumbnailEnabled: item.coverPath != null,
      downloadSubtitlesEnabled: item.subtitlePaths.isNotEmpty,
    );
    try {
      await ref
          .read(downloadsProvider.notifier)
          .retryDownload(item: item, settings: settings);
      if (notify) _message('Download added to the queue.');
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Retry could not be queued', error, stackTrace);
      if (notify) _message('The download could not be queued. Try again.');
      return false;
    }
  }

  Future<bool> _cancel(DownloadItem item, {bool notify = true}) async {
    try {
      await ref.read(downloadsProvider.notifier).cancelDownload(item);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Download cancellation failed', error, stackTrace);
      if (notify) _message('The download could not be cancelled.');
      return false;
    }
  }

  Future<void> _confirmDelete(DownloadItem item) async {
    var deleteFiles = item.filePath != null || item.publicUris.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.delete_outline_rounded),
          title: const Text('Remove from Downloads?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) =>
                    setDialogState(() => deleteFiles = value ?? false),
                title: const Text('Delete files from the device'),
                subtitle: const Text(
                  'Main media, cover, subtitles, and published Android copies',
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await _delete(item, deleteFiles: deleteFiles);
  }

  Future<bool> _delete(
    DownloadItem item, {
    required bool deleteFiles,
    bool notify = true,
  }) async {
    if (item.id == null) return false;
    try {
      if (_isActive(item)) {
        await ref.read(downloadsProvider.notifier).cancelDownload(item);
      }
      if (deleteFiles) {
        final paths = <String>{
          if (item.filePath != null) item.filePath!,
          if (item.coverPath != null) item.coverPath!,
          ...item.subtitlePaths,
          ...item.relatedFilePaths,
        };
        for (final path in paths) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        await DownloadPathService.instance.deletePublishedAndroidFiles(
          item.publicUris,
        );
      }
      await ref.read(downloadsProvider.notifier).deleteDownload(item.id!);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Could not remove download', error, stackTrace);
      if (notify) _message('Some files could not be removed.');
      return false;
    }
  }

  Future<void> _openDownloads() async {
    final settings = ref.read(ytDlpSettingsProvider);
    final path = settings.downloadPath.isEmpty
        ? await DownloadPathService.instance.getDefaultDownloadPath()
        : settings.downloadPath;
    final opened = await DownloadPathService.instance.openDownloadLocation(
      path,
    );
    if (!opened) _message('The download folder could not be opened.');
  }

  Future<void> _handleMenuAction(_HistoryMenuAction action) async {
    final all = ref.read(downloadsProvider).asData?.value ?? const [];
    final targets = action == _HistoryMenuAction.clearCompleted
        ? all
              .where((item) => item.status == DownloadStatus.completed)
              .toList(growable: false)
        : List<DownloadItem>.of(all);
    if (targets.isEmpty) {
      _message('There is nothing to clear.');
      return;
    }

    var deleteFiles = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.cleaning_services_outlined),
          title: Text(
            action == _HistoryMenuAction.clearCompleted
                ? 'Clear completed downloads?'
                : 'Clear the whole library?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${targets.length} item(s) will be removed from this list.'),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) =>
                    setDialogState(() => deleteFiles = value ?? false),
                title: const Text('Also delete files from the device'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    for (final item in targets) {
      await _delete(item, deleteFiles: deleteFiles);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _LibraryOverview extends StatelessWidget {
  const _LibraryOverview({required this.downloads});

  final List<DownloadItem> downloads;

  @override
  Widget build(BuildContext context) {
    final active = downloads.where(_isActiveStatus).length;
    final completed = downloads
        .where((item) => item.status == DownloadStatus.completed)
        .length;
    final attention = downloads
        .where(
          (item) =>
              item.status == DownloadStatus.failed ||
              item.status == DownloadStatus.cancelled,
        )
        .length;
    final bytes = downloads.fold<int>(
      0,
      (total, item) => total + (item.fileSize ?? 0),
    );
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              child: Icon(Icons.video_library_rounded),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completed ready · $active active',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${downloads.length} total · ${_fileSize(bytes)}'
                    '${attention == 0 ? '' : ' · $attention need attention'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.selected,
    required this.downloads,
    required this.onChanged,
  });

  final _LibraryStatus selected;
  final List<DownloadItem> downloads;
  final ValueChanged<_LibraryStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in _LibraryStatus.values) ...[
            FilterChip(
              selected: selected == value,
              onSelected: (_) => onChanged(value),
              avatar: Icon(value.icon, size: 17),
              label: Text('${value.label} ${_count(value)}'),
            ),
            if (value != _LibraryStatus.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  int _count(_LibraryStatus value) => switch (value) {
    _LibraryStatus.all => downloads.length,
    _LibraryStatus.active => downloads.where(_isActiveStatus).length,
    _LibraryStatus.completed =>
      downloads.where((item) => item.status == DownloadStatus.completed).length,
    _LibraryStatus.attention =>
      downloads
          .where(
            (item) =>
                item.status == DownloadStatus.failed ||
                item.status == DownloadStatus.cancelled,
          )
          .length,
  };
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.resultCount,
    required this.activeFilterCount,
    required this.sort,
    required this.onFilters,
    required this.onSort,
  });

  final int resultCount;
  final int activeFilterCount;
  final DownloadSortBy sort;
  final VoidCallback onFilters;
  final ValueChanged<DownloadSortBy> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$resultCount result${resultCount == 1 ? '' : 's'}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onFilters,
          icon: Badge(
            isLabelVisible: activeFilterCount > 0,
            label: Text('$activeFilterCount'),
            child: const Icon(Icons.filter_alt_outlined),
          ),
          label: const Text('Filters'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<DownloadSortBy>(
          tooltip: 'Sort downloads',
          initialValue: sort,
          onSelected: onSort,
          itemBuilder: (_) => [
            for (final value in DownloadSortBy.values)
              PopupMenuItem(value: value, child: Text(value.label)),
          ],
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.sort_rounded),
          ),
        ),
      ],
    );
  }
}

class _FilterChoices<T> extends StatelessWidget {
  const _FilterChoices({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                selected: value == selected,
                onSelected: (_) => onSelected(value),
                label: Text(label(value)),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.hasDownloads,
    required this.onReset,
    required this.onDownload,
  });

  final bool hasDownloads;
  final VoidCallback onReset;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            Icon(
              hasDownloads
                  ? Icons.filter_alt_off_rounded
                  : Icons.download_done_rounded,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              hasDownloads
                  ? 'Nothing matches this view'
                  : 'Your downloads will appear here',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasDownloads
                  ? 'Clear the search or filters to see the rest of your library.'
                  : 'Add a media link from Home to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: hasDownloads ? onReset : onDownload,
              icon: Icon(
                hasDownloads
                    ? Icons.filter_alt_off_rounded
                    : Icons.add_link_rounded,
              ),
              label: Text(hasDownloads ? 'Reset view' : 'New download'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: const Text('Downloads could not be loaded'),
        subtitle: const Text('Your files were not changed.'),
        trailing: IconButton(
          tooltip: 'Retry',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}

bool _isActiveStatus(DownloadItem item) =>
    item.status == DownloadStatus.pending ||
    item.status == DownloadStatus.processing ||
    item.status == DownloadStatus.downloading;

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

extension on _LibraryStatus {
  String get label => switch (this) {
    _LibraryStatus.all => 'All',
    _LibraryStatus.active => 'Active',
    _LibraryStatus.completed => 'Ready',
    _LibraryStatus.attention => 'Attention',
  };

  IconData get icon => switch (this) {
    _LibraryStatus.all => Icons.all_inbox_rounded,
    _LibraryStatus.active => Icons.downloading_rounded,
    _LibraryStatus.completed => Icons.check_circle_outline_rounded,
    _LibraryStatus.attention => Icons.error_outline_rounded,
  };
}

extension on _DateFilter {
  String get label => switch (this) {
    _DateFilter.all => 'Any time',
    _DateFilter.today => 'Today',
    _DateFilter.last7Days => 'Last 7 days',
    _DateFilter.last30Days => 'Last 30 days',
  };
}

extension on _MediaFilter {
  String get label => switch (this) {
    _MediaFilter.all => 'Any media',
    _MediaFilter.video => 'Video',
    _MediaFilter.audio => 'Audio',
  };
}

extension on _ArtifactFilter {
  String get label => switch (this) {
    _ArtifactFilter.all => 'Any files',
    _ArtifactFilter.cover => 'Has cover',
    _ArtifactFilter.subtitles => 'Has subtitles',
    _ArtifactFilter.missing => 'Missing main file',
  };
}

extension on DownloadSortBy {
  String get label => switch (this) {
    DownloadSortBy.dateNewest => 'Newest first',
    DownloadSortBy.dateOldest => 'Oldest first',
    DownloadSortBy.titleAZ => 'Title A–Z',
    DownloadSortBy.titleZA => 'Title Z–A',
    DownloadSortBy.sizeSmallest => 'Smallest first',
    DownloadSortBy.sizeLargest => 'Largest first',
  };
}
