import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/logger/app_logger.dart';
import '../../../core/notifications/app_notification.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../shared/models/download_item.dart';

class DownloadItemCard extends StatelessWidget {
  const DownloadItemCard({
    super.key,
    required this.item,
    this.onDelete,
    this.onRetry,
    this.onCancel,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
  });

  final DownloadItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;

  bool get _active =>
      item.status == DownloadStatus.pending ||
      item.status == DownloadStatus.processing ||
      item.status == DownloadStatus.downloading;

  bool get _mainFileExists =>
      item.filePath != null && File(item.filePath!).existsSync();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected
          ? colors.secondaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: selected
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: selectionMode
            ? () => onSelectionChanged?.call(!selected)
            : () => _showDetails(context),
        onLongPress: onSelectionChanged == null
            ? null
            : () => onSelectionChanged?.call(true),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: compact ? 104 : 148,
                      height: compact ? 128 : 140,
                      child: _thumbnail(context),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                        child: _content(context, compact: compact),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_active) ...[
              LinearProgressIndicator(
                value: item.progress > 0 ? item.progress / 100 : null,
                minHeight: 3,
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat('MMM d · HH:mm').format(item.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _primaryAction(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback() => ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Icon(
          item.downloadType == 'audio'
              ? Icons.graphic_eq_rounded
              : Icons.movie_outlined,
          size: 42,
          color: colors.onSecondaryContainer,
        ),
      ),
    );

    final localCover = item.coverPath;
    final image = localCover != null && File(localCover).existsSync()
        ? Image.file(
            File(localCover),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          )
        : item.thumbnail == null
        ? fallback()
        : Image.network(
            item.thumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (item.coverPath != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: _SmallArtifactBadge(
              icon: Icons.image_rounded,
              label: 'Cover',
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
            if (selectionMode)
              Tooltip(
                message: selected ? 'Deselect download' : 'Select download',
                child: Checkbox(
                  value: selected,
                  onChanged: (value) =>
                      onSelectionChanged?.call(value ?? false),
                ),
              )
            else
              _MoreMenu(
                item: item,
                canShare: _mainFileExists,
                onSelected: (value) => _handleMenu(context, value),
              ),
          ],
        ),
        const SizedBox(height: 7),
        _StatusLine(item: item),
        const SizedBox(height: 8),
        Text(
          _metadata,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (item.subtitlePaths.isNotEmpty || item.coverPath != null) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            children: [
              if (item.subtitlePaths.isNotEmpty)
                Text(
                  '${item.subtitlePaths.length} subtitle file${item.subtitlePaths.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (item.coverPath != null)
                Text(
                  'Cover saved',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
        if (item.errorMessage != null && !_active) ...[
          const SizedBox(height: 7),
          Text(
            item.errorMessage!,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryAction(BuildContext context) {
    if (selectionMode) {
      return TextButton.icon(
        onPressed: () => onSelectionChanged?.call(!selected),
        icon: Icon(
          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 19,
        ),
        label: Text(selected ? 'Selected' : 'Select'),
      );
    }
    if (_active && onCancel != null) {
      return TextButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.stop_circle_outlined, size: 19),
        label: const Text('Cancel'),
      );
    }
    if (onRetry != null) {
      return FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 19),
        label: const Text('Retry'),
      );
    }
    if (item.status == DownloadStatus.completed && _mainFileExists) {
      return FilledButton.tonalIcon(
        onPressed: () => _openPath(context, item.filePath!),
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: const Text('Open'),
      );
    }
    return TextButton(
      onPressed: () => _showDetails(context),
      child: const Text('Details'),
    );
  }

  String get _metadata {
    final values = <String>[
      if (item.quality?.isNotEmpty == true) item.quality!,
      if (item.fileExtension?.isNotEmpty == true)
        item.fileExtension!.toUpperCase(),
      if (item.downloadType?.isNotEmpty == true) _typeLabel(item.downloadType!),
      if (item.fileSize != null) _fileSize(item.fileSize!),
    ];
    return values.isEmpty
        ? item.formatLabel ?? 'Default format'
        : values.join(' · ');
  }

  int? get _resolvedFileSize {
    if (item.fileSize != null && item.fileSize! > 0) return item.fileSize;
    final path = item.filePath;
    if (path == null) return null;
    try {
      final file = File(path);
      return file.existsSync() ? file.lengthSync() : null;
    } catch (_) {
      return null;
    }
  }

  String? get _fileName {
    final path = item.filePath;
    if (path == null || path.isEmpty) return null;
    final segments = File(path).uri.pathSegments;
    return segments.isEmpty ? path : segments.last;
  }

  String? get _elapsedTime {
    final completed = item.completedAt;
    if (completed == null) return null;
    final duration = completed.difference(item.createdAt);
    if (duration.isNegative) return null;
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m '
          '${duration.inSeconds.remainder(60)}s';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }

  String _typeLabel(String type) => switch (type) {
    'audio' => 'Audio',
    'video' => 'Video only',
    'separate' => 'Separate streams',
    'combined' => 'Video + audio',
    _ => type,
  };

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'details':
        _showDetails(context);
      case 'open':
        if (item.filePath != null) await _openPath(context, item.filePath!);
      case 'folder':
        await _openFolder(context);
      case 'share':
        await _share(context);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.url));
        if (context.mounted) _message(context, 'Source link copied.');
      case 'delete':
        onDelete?.call();
    }
  }

  Future<void> _openPath(BuildContext context, String path) async {
    try {
      if (!await File(path).exists()) throw StateError('File not found');
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) throw StateError(result.message);
    } catch (error, stackTrace) {
      AppLogger.error('Could not open downloaded file', error, stackTrace);
      if (context.mounted) {
        _message(context, 'This file is missing or cannot be opened.');
      }
    }
  }

  Future<void> _openFolder(BuildContext context) async {
    final path = item.filePath;
    if (path == null) return;
    final opened = await DownloadPathService.instance.openDownloadLocation(
      File(path).parent.path,
    );
    if (!opened && context.mounted) {
      _message(context, 'The download folder could not be opened.');
    }
  }

  Future<void> _share(BuildContext context) async {
    final path = item.filePath;
    if (path == null || !await File(path).exists()) {
      if (context.mounted) {
        _message(context, 'This file is no longer available.');
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: item.title),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.96,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(status: item.status),
              ],
            ),
            const SizedBox(height: 20),
            _DetailsSection(
              title: 'Download',
              children: [
                _DetailRow(
                  label: 'Format',
                  value: item.formatLabel ?? _metadata,
                ),
                if (item.quality?.isNotEmpty == true)
                  _DetailRow(label: 'Quality', value: item.quality!),
                if (item.downloadType?.isNotEmpty == true)
                  _DetailRow(
                    label: 'Output',
                    value: _typeLabel(item.downloadType!),
                  ),
                if (item.formatId?.isNotEmpty == true)
                  _DetailRow(label: 'Format ID', value: item.formatId!),
                if (item.fileExtension?.isNotEmpty == true)
                  _DetailRow(
                    label: 'Container',
                    value: item.fileExtension!.toUpperCase(),
                  ),
                if (_resolvedFileSize != null)
                  _DetailRow(
                    label: 'File size',
                    value: _fileSize(_resolvedFileSize!),
                  ),
                _DetailRow(
                  label: 'Added',
                  value: DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).format(item.createdAt),
                ),
                if (item.completedAt != null)
                  _DetailRow(
                    label: 'Completed',
                    value: DateFormat(
                      'yyyy-MM-dd HH:mm:ss',
                    ).format(item.completedAt!),
                  ),
                if (_elapsedTime != null)
                  _DetailRow(label: 'Elapsed', value: _elapsedTime!),
                if (_fileName != null)
                  _DetailRow(label: 'File name', value: _fileName!),
                if (item.filePath != null)
                  _DetailRow(
                    label: 'Folder',
                    value: File(item.filePath!).parent.path,
                  ),
                if (item.videoCodec != null)
                  _DetailRow(label: 'Video codec', value: item.videoCodec!),
                if (item.audioCodec != null)
                  _DetailRow(label: 'Audio codec', value: item.audioCodec!),
              ],
            ),
            const SizedBox(height: 16),
            _DetailsSection(
              title: 'Source',
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(item.url),
                ),
              ],
            ),
            if (item.filePath != null ||
                item.coverPath != null ||
                item.subtitlePaths.isNotEmpty ||
                item.relatedFilePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Saved files',
                children: [
                  if (item.filePath != null)
                    _ArtifactTile(
                      icon: item.downloadType == 'audio'
                          ? Icons.audio_file_rounded
                          : Icons.video_file_rounded,
                      label: 'Main media',
                      path: item.filePath!,
                      onTap: () => _openPath(context, item.filePath!),
                    ),
                  if (item.coverPath != null)
                    _ArtifactTile(
                      icon: Icons.image_rounded,
                      label: 'Cover',
                      path: item.coverPath!,
                      onTap: () => _openPath(context, item.coverPath!),
                    ),
                  for (final subtitle in item.subtitlePaths)
                    _ArtifactTile(
                      icon: Icons.subtitles_rounded,
                      label: 'Subtitle',
                      path: subtitle,
                      onTap: () => _openPath(context, subtitle),
                    ),
                  for (final related in item.relatedFilePaths.where(
                    (path) =>
                        path != item.coverPath &&
                        !item.subtitlePaths.contains(path) &&
                        path != item.filePath,
                  ))
                    _ArtifactTile(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'Related file',
                      path: related,
                      onTap: () => _openPath(context, related),
                    ),
                  if (item.publicUris.isNotEmpty)
                    _DetailRow(
                      label: 'Published',
                      value:
                          '${item.publicUris.length} file(s) in Downloads/MBNDL',
                    ),
                ],
              ),
            ],
            if (item.errorMessage != null) ...[
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'What needs attention',
                error: true,
                children: [SelectableText(item.errorMessage!)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _message(BuildContext context, String message) {
    AppNotificationCenter.show(
      context,
      title: 'Download file',
      message: message,
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.item,
    required this.canShare,
    required this.onSelected,
  });

  final DownloadItem item;
  final bool canShare;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'details', child: Text('View details')),
        if (canShare)
          const PopupMenuItem(value: 'open', child: Text('Open file')),
        if (item.filePath != null)
          const PopupMenuItem(value: 'folder', child: Text('Open folder')),
        if (canShare)
          const PopupMenuItem(value: 'share', child: Text('Share file')),
        const PopupMenuItem(value: 'copy', child: Text('Copy source link')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Remove…')),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _statusAppearance(context, item.status);
    final detail = item.status == DownloadStatus.downloading
        ? '${item.progress.toStringAsFixed(0)}% · ${item.currentPhase ?? 'Downloading'}'
        : item.status == DownloadStatus.processing
        ? item.currentPhase ?? 'Preparing download'
        : null;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (detail != null) ...[
          Text(
            ' · $detail',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _statusAppearance(context, status);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallArtifactBadge extends StatelessWidget {
  const _SmallArtifactBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.children,
    this.error = false,
  });

  final String title;
  final List<Widget> children;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: error ? colors.onErrorContainer : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({
    required this.icon,
    required this.label,
    required this.path,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exists = File(path).existsSync();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        exists ? path : 'Missing · $path',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        exists ? Icons.open_in_new_rounded : Icons.warning_amber_rounded,
      ),
      onTap: exists ? onTap : null,
    );
  }
}

(String, IconData, Color) _statusAppearance(
  BuildContext context,
  DownloadStatus status,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    DownloadStatus.completed => (
      'Ready',
      Icons.check_circle_rounded,
      colors.primary,
    ),
    DownloadStatus.failed => ('Failed', Icons.error_rounded, colors.error),
    DownloadStatus.cancelled => (
      'Cancelled',
      Icons.cancel_rounded,
      colors.onSurfaceVariant,
    ),
    DownloadStatus.pending => (
      'Queued',
      Icons.schedule_rounded,
      colors.tertiary,
    ),
    DownloadStatus.processing => (
      'Preparing',
      Icons.auto_fix_high_rounded,
      colors.tertiary,
    ),
    DownloadStatus.downloading => (
      'Downloading',
      Icons.downloading_rounded,
      colors.secondary,
    ),
  };
}

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
