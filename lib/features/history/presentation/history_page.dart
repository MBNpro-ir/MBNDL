import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/downloader/download_service.dart';
import '../../../services/logger/app_logger.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../shared/models/download_item.dart';
import '../../../shared/providers/downloads_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../widgets/download_item_card.dart';

enum _StatusFilter { all, active, completed, failed, cancelled }

enum _DateFilter { all, today, last7Days, last30Days }

enum _FileFilter { all, video, audio, cover, subtitles, missing }

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  _StatusFilter _status = _StatusFilter.all;
  _DateFilter _date = _DateFilter.all;
  _FileFilter _file = _FileFilter.all;
  bool _gridView = true;

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

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 1180
              ? (constraints.maxWidth - 1120) / 2
              : 16.0;
          return RefreshIndicator(
            onRefresh: ref.read(downloadsProvider.notifier).loadDownloads,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('History'),
                  actions: [
                    IconButton(
                      tooltip: 'Open Downloads/MBNDL',
                      onPressed: _openDownloads,
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                    PopupMenuButton<_HistoryMenuAction>(
                      tooltip: 'History actions',
                      onSelected: _handleMenuAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _HistoryMenuAction.clearCompleted,
                          child: Text('Clear completed'),
                        ),
                        PopupMenuItem(
                          value: _HistoryMenuAction.clearAll,
                          child: Text('Clear all history'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
                  sliver: SliverToBoxAdapter(
                    child: downloadsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => _ErrorPanel(
                        onRetry: ref
                            .read(downloadsProvider.notifier)
                            .loadDownloads,
                      ),
                      data: (all) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummary(all),
                          const SizedBox(height: 16),
                          _buildFilters(sort, constraints.maxWidth),
                        ],
                      ),
                    ),
                  ),
                ),
                if (downloadsAsync.hasValue)
                  ..._buildResults(
                    constraints: constraints,
                    horizontal: horizontal,
                    allDownloads: sorted,
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(List<DownloadItem> downloads) {
    final active = downloads.where(_isActive).length;
    final completed = downloads
        .where((item) => item.status == DownloadStatus.completed)
        .length;
    final failed = downloads
        .where((item) => item.status == DownloadStatus.failed)
        .length;
    final bytes = downloads.fold<int>(
      0,
      (total, item) => total + (item.fileSize ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 820
            ? (constraints.maxWidth - 36) / 4
            : constraints.maxWidth >= 460
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              width: cardWidth,
              icon: Icons.library_add_check_rounded,
              label: 'All downloads',
              value: '${downloads.length}',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.downloading_rounded,
              label: 'Active',
              value: '$active',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: failed == 0
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              label: '$completed complete • $failed failed',
              value: _formatBytes(bytes),
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.collections_bookmark_rounded,
              label: 'Saved extras',
              value:
                  '${downloads.where((item) => item.coverPath != null).length} covers • '
                  '${downloads.fold<int>(0, (n, item) => n + item.subtitlePaths.length)} subs',
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(DownloadSortBy sort, double width) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search title, URL, format, or extension',
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
            Text(
              'Status',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in _StatusFilter.values)
                  FilterChip(
                    selected: _status == filter,
                    onSelected: (_) => setState(() => _status = filter),
                    avatar: Icon(filter.icon, size: 17),
                    label: Text(filter.label),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final controls = [
                  DropdownMenu<_DateFilter>(
                    initialSelection: _date,
                    expandedInsets: EdgeInsets.zero,
                    leadingIcon: const Icon(Icons.date_range_rounded),
                    label: const Text('Date'),
                    dropdownMenuEntries: [
                      for (final filter in _DateFilter.values)
                        DropdownMenuEntry(value: filter, label: filter.label),
                    ],
                    onSelected: (value) {
                      if (value != null) setState(() => _date = value);
                    },
                  ),
                  DropdownMenu<_FileFilter>(
                    initialSelection: _file,
                    expandedInsets: EdgeInsets.zero,
                    leadingIcon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('File'),
                    dropdownMenuEntries: [
                      for (final filter in _FileFilter.values)
                        DropdownMenuEntry(value: filter, label: filter.label),
                    ],
                    onSelected: (value) {
                      if (value != null) setState(() => _file = value);
                    },
                  ),
                  DropdownMenu<DownloadSortBy>(
                    initialSelection: sort,
                    expandedInsets: EdgeInsets.zero,
                    leadingIcon: const Icon(Icons.sort_rounded),
                    label: const Text('Sort'),
                    dropdownMenuEntries: [
                      for (final value in DownloadSortBy.values)
                        DropdownMenuEntry(value: value, label: value.label),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        ref.read(downloadSortProvider.notifier).setSort(value);
                      }
                    },
                  ),
                ];
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (final control in controls) ...[
                        SizedBox(width: double.infinity, child: control),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < controls.length; index++) ...[
                      Expanded(child: controls[index]),
                      if (index != controls.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults({
    required BoxConstraints constraints,
    required double horizontal,
    required List<DownloadItem> allDownloads,
  }) {
    final filtered = allDownloads
        .where(_matchesFilters)
        .toList(growable: false);
    final canGrid = constraints.maxWidth >= 760;
    final useGrid = canGrid && _gridView;

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canGrid) ...[
                IconButton(
                  tooltip: 'List view',
                  isSelected: !_gridView,
                  onPressed: () => setState(() => _gridView = false),
                  icon: const Icon(Icons.view_agenda_outlined),
                  selectedIcon: const Icon(Icons.view_agenda_rounded),
                ),
                IconButton(
                  tooltip: 'Grid view',
                  isSelected: _gridView,
                  onPressed: () => setState(() => _gridView = true),
                  icon: const Icon(Icons.grid_view_outlined),
                  selectedIcon: const Icon(Icons.grid_view_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
      if (filtered.isEmpty)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverToBoxAdapter(
            child: _EmptyHistory(
              filtered: allDownloads.isNotEmpty,
              onClearFilters: _resetFilters,
              onNewDownload: () => context.go('/home'),
            ),
          ),
        )
      else if (useGrid)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 1180 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 382,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _downloadCard(filtered[index], grid: true),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                SizedBox(height: 220, child: _downloadCard(filtered[index])),
          ),
        ),
    ];
  }

  Widget _downloadCard(DownloadItem item, {bool grid = false}) {
    final retryable =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled;
    return DownloadItemCard(
      item: item,
      grid: grid,
      onCancel: _isActive(item) ? () => _cancel(item) : null,
      onRetry: retryable ? () => _retry(item) : null,
      onDelete: item.id == null ? null : () => _confirmDelete(item),
    );
  }

  bool _matchesFilters(DownloadItem item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !item.title.toLowerCase().contains(query) &&
        !item.url.toLowerCase().contains(query) &&
        !(item.formatLabel?.toLowerCase().contains(query) ?? false) &&
        !(item.fileExtension?.toLowerCase().contains(query) ?? false)) {
      return false;
    }

    final statusMatch = switch (_status) {
      _StatusFilter.all => true,
      _StatusFilter.active => _isActive(item),
      _StatusFilter.completed => item.status == DownloadStatus.completed,
      _StatusFilter.failed => item.status == DownloadStatus.failed,
      _StatusFilter.cancelled => item.status == DownloadStatus.cancelled,
    };
    if (!statusMatch) return false;

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

    return switch (_file) {
      _FileFilter.all => true,
      _FileFilter.video =>
        item.downloadType == 'video' || item.downloadType == 'combined',
      _FileFilter.audio => item.downloadType == 'audio',
      _FileFilter.cover => item.coverPath != null,
      _FileFilter.subtitles => item.subtitlePaths.isNotEmpty,
      _FileFilter.missing =>
        item.status == DownloadStatus.completed &&
            (item.filePath == null || !File(item.filePath!).existsSync()),
    };
  }

  bool _isActive(DownloadItem item) =>
      item.status == DownloadStatus.pending ||
      item.status == DownloadStatus.processing ||
      item.status == DownloadStatus.downloading;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _status = _StatusFilter.all;
      _date = _DateFilter.all;
      _file = _FileFilter.all;
    });
  }

  Future<void> _retry(DownloadItem item) async {
    if (item.id == null || item.formatId == null) return;
    final base = ref.read(ytDlpSettingsProvider);
    final notifier = ref.read(downloadsProvider.notifier);
    final settings = base.copyWith(
      selectedFormatId: item.formatId,
      downloadType: item.downloadType ?? 'combined',
      extractAudio: item.downloadType == 'audio' ? base.extractAudio : false,
      downloadThumbnailEnabled: item.coverPath != null,
      downloadSubtitlesEnabled: item.subtitlePaths.isNotEmpty,
    );
    unawaited(
      DownloadService.instance
          .retryDownload(
            item: item,
            settings: settings,
            onUpdate: notifier.updateDownload,
          )
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.error('Retry failed', error, stackTrace);
          }),
    );
  }

  Future<void> _cancel(DownloadItem item) async {
    if (item.id == null) return;
    await DownloadService.instance.cancelDownload(item.id!);
    final cancelled = item.copyWith(
      status: DownloadStatus.cancelled,
      errorMessage: 'Download cancelled by user.',
      clearCurrentPhase: true,
    );
    await ref.read(downloadsProvider.notifier).updateDownload(cancelled);
  }

  Future<void> _confirmDelete(DownloadItem item) async {
    var deleteFiles = item.filePath != null || item.publicUris.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.delete_outline_rounded),
          title: const Text('Remove download?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) =>
                    setDialogState(() => deleteFiles = value ?? false),
                title: const Text('Delete downloaded files too'),
                subtitle: const Text(
                  'Includes the main file, cover, subtitles, and Android '
                  'published copies.',
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

  Future<void> _delete(DownloadItem item, {required bool deleteFiles}) async {
    if (item.id == null) return;
    try {
      if (_isActive(item)) {
        await DownloadService.instance.cancelDownload(item.id!);
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
    } catch (error, stackTrace) {
      AppLogger.error('Could not remove download', error, stackTrace);
      if (mounted) _message('Some downloaded files could not be removed.');
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
    if (!opened && mounted) {
      _message('The download folder could not be opened.');
    }
  }

  Future<void> _handleMenuAction(_HistoryMenuAction action) async {
    final items = ref.read(downloadsProvider).asData?.value ?? const [];
    final targets = action == _HistoryMenuAction.clearCompleted
        ? items
              .where((item) => item.status == DownloadStatus.completed)
              .toList(growable: false)
        : items;
    if (targets.isEmpty) {
      _message('There is nothing to clear.');
      return;
    }

    var deleteFiles = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            action == _HistoryMenuAction.clearCompleted
                ? 'Clear completed history?'
                : 'Clear all history?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${targets.length} history item(s) will be removed.'),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) =>
                    setDialogState(() => deleteFiles = value ?? false),
                title: const Text('Also delete downloaded files'),
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

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

enum _HistoryMenuAction { clearCompleted, clearAll }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.active => 'Active',
    _StatusFilter.completed => 'Completed',
    _StatusFilter.failed => 'Failed',
    _StatusFilter.cancelled => 'Cancelled',
  };

  IconData get icon => switch (this) {
    _StatusFilter.all => Icons.all_inbox_rounded,
    _StatusFilter.active => Icons.downloading_rounded,
    _StatusFilter.completed => Icons.check_circle_outline_rounded,
    _StatusFilter.failed => Icons.error_outline_rounded,
    _StatusFilter.cancelled => Icons.cancel_outlined,
  };
}

extension on _DateFilter {
  String get label => switch (this) {
    _DateFilter.all => 'Any date',
    _DateFilter.today => 'Today',
    _DateFilter.last7Days => 'Last 7 days',
    _DateFilter.last30Days => 'Last 30 days',
  };
}

extension on _FileFilter {
  String get label => switch (this) {
    _FileFilter.all => 'Any file',
    _FileFilter.video => 'Video',
    _FileFilter.audio => 'Audio',
    _FileFilter.cover => 'Has cover',
    _FileFilter.subtitles => 'Has subtitles',
    _FileFilter.missing => 'Missing file',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.filtered,
    required this.onClearFilters,
    required this.onNewDownload,
  });

  final bool filtered;
  final VoidCallback onClearFilters;
  final VoidCallback onNewDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            Icon(
              filtered
                  ? Icons.filter_alt_off_rounded
                  : Icons.download_done_rounded,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              filtered
                  ? 'No downloads match these filters'
                  : 'No downloads yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: filtered ? onClearFilters : onNewDownload,
              icon: Icon(
                filtered
                    ? Icons.filter_alt_off_rounded
                    : Icons.add_link_rounded,
              ),
              label: Text(filtered ? 'Clear filters' : 'Start a download'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: const Text('History could not be loaded'),
        trailing: IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}
