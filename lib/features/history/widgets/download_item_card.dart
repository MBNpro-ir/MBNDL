import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/logger/app_logger.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../shared/models/download_item.dart';

class DownloadItemCard extends StatelessWidget {
  const DownloadItemCard({
    super.key,
    required this.item,
    required this.grid,
    this.onDelete,
    this.onRetry,
    this.onCancel,
  });

  final DownloadItem item;
  final bool grid;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  bool get _active =>
      item.status == DownloadStatus.pending ||
      item.status == DownloadStatus.processing ||
      item.status == DownloadStatus.downloading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: grid
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 132, child: _thumbnail(context)),
                  Expanded(child: _body(context, compact: true)),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final imageWidth = constraints.maxWidth < 520 ? 116.0 : 178.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: imageWidth, child: _thumbnail(context)),
                      Expanded(child: _body(context, compact: false)),
                    ],
                  );
                },
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
          size: 44,
          color: colors.onSecondaryContainer,
        ),
      ),
    );

    final cover = item.coverPath;
    final image = cover != null && File(cover).existsSync()
        ? Image.file(
            File(cover),
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
        Positioned(top: 10, left: 10, child: _StatusBadge(status: item.status)),
        if (item.coverPath != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: Tooltip(
              message: 'Downloaded cover',
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colors.surface.withValues(alpha: 0.9),
                child: const Icon(Icons.image_rounded, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _body(BuildContext context, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (value) => _handleMenu(context, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                  if (item.filePath != null)
                    const PopupMenuItem(
                      value: 'folder',
                      child: Text('Open folder'),
                    ),
                  if (item.filePath != null)
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                  if (onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (item.formatLabel != null) ...[
            const SizedBox(height: 3),
            Text(
              item.formatLabel!,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (item.quality != null)
                _MetaChip(
                  icon: Icons.high_quality_rounded,
                  label: item.quality!,
                ),
              if (item.downloadType != null)
                _MetaChip(
                  icon: item.downloadType == 'audio'
                      ? Icons.graphic_eq_rounded
                      : item.downloadType == 'combined'
                      ? Icons.merge_type_rounded
                      : Icons.videocam_outlined,
                  label: item.downloadType!,
                ),
              if (item.subtitlePaths.isNotEmpty)
                _MetaChip(
                  icon: Icons.subtitles_rounded,
                  label: '${item.subtitlePaths.length} subtitle',
                ),
              if (item.coverPath != null)
                const _MetaChip(icon: Icons.image_rounded, label: 'cover'),
            ],
          ),
          if (_active) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: item.progress / 100),
            const SizedBox(height: 5),
            Text(
              '${item.progress.toStringAsFixed(0)}% • ${item.currentPhase ?? 'Downloading'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (item.errorMessage != null && !_active) ...[
            const SizedBox(height: 8),
            Text(
              item.errorMessage!,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!compact) const Spacer(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  DateFormat('MMM d, y • HH:mm').format(item.createdAt),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (item.status == DownloadStatus.completed &&
                  item.filePath != null)
                IconButton.filledTonal(
                  tooltip: 'Open file',
                  onPressed: () => _openPath(context, item.filePath!),
                  icon: const Icon(Icons.play_arrow_rounded),
                )
              else if (_active && onCancel != null)
                IconButton.filledTonal(
                  tooltip: 'Cancel download',
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop_rounded),
                )
              else if (onRetry != null)
                IconButton.filledTonal(
                  tooltip: 'Retry download',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'details':
        _showDetails(context);
      case 'folder':
        await _openFolder(context);
      case 'share':
        await _share(context);
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
      AppLogger.error('Could not open file', error, stackTrace);
      if (context.mounted) _message(context, 'The file could not be opened.');
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
        _message(context, 'The file is no longer available.');
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Status', value: item.status.name),
            if (item.formatLabel != null)
              _DetailRow(label: 'Format', value: item.formatLabel!),
            if (item.fileSize != null)
              _DetailRow(label: 'Size', value: _fileSize(item.fileSize!)),
            _DetailRow(
              label: 'Added',
              value: DateFormat('yyyy-MM-dd HH:mm:ss').format(item.createdAt),
            ),
            if (item.completedAt != null)
              _DetailRow(
                label: 'Completed',
                value: DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format(item.completedAt!),
              ),
            const SizedBox(height: 18),
            Text('Source URL', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(item.url),
            if (item.filePath != null) ...[
              const SizedBox(height: 18),
              _ArtifactTile(
                icon: Icons.movie_rounded,
                label: 'Downloaded file',
                path: item.filePath!,
                onTap: () => _openPath(context, item.filePath!),
              ),
            ],
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
            if (item.publicUris.isNotEmpty)
              _DetailRow(
                label: 'Published copies',
                value: '${item.publicUris.length} in Downloads/MBNDL',
              ),
            if (item.errorMessage != null) ...[
              const SizedBox(height: 18),
              Text(
                'What went wrong',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              SelectableText(item.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (status) {
      DownloadStatus.completed => (
        'Completed',
        Icons.check_circle_rounded,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      DownloadStatus.failed => (
        'Failed',
        Icons.error_rounded,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      DownloadStatus.cancelled => (
        'Cancelled',
        Icons.cancel_rounded,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      DownloadStatus.pending => (
        'Queued',
        Icons.schedule_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      DownloadStatus.processing => (
        'Processing',
        Icons.auto_fix_high_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      DownloadStatus.downloading => (
        'Downloading',
        Icons.downloading_rounded,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 15),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
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
            width: 110,
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: onTap,
    );
  }
}
