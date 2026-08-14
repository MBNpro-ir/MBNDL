import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/downloader/download_error_mapper.dart';
import '../../../services/downloader/download_service.dart';
import '../../../services/logger/app_logger.dart';
import '../../../shared/models/download_item.dart';
import '../../../shared/models/recent_link.dart';
import '../../../shared/models/video_format.dart';
import '../../../shared/providers/downloads_provider.dart';
import '../../../shared/providers/recent_links_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import 'format_selection_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  bool _isValidUrl = false;
  String _recentQuery = '';

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _validateUrl(String raw) {
    final normalized = _normalizeUrl(raw);
    final uri = Uri.tryParse(normalized);
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (valid != _isValidUrl) setState(() => _isValidUrl = valid);
  }

  String _normalizeUrl(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '');

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text == null ? null : _normalizeUrl(data!.text!);
    if (value == null || value.isEmpty || !mounted) return;
    _urlController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _validateUrl(value);
  }

  Future<void> _inspectLink() async {
    if (!_isValidUrl) {
      _showMessage('Paste a complete HTTP or HTTPS link.', isError: true);
      _urlFocus.requestFocus();
      return;
    }

    final url = _normalizeUrl(_urlController.text);
    final status = ValueNotifier<String>('Checking the built-in tools…');
    var cancelled = false;
    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => _InspectionProgress(
          status: status,
          onCancel: () {
            cancelled = true;
            _closeRootDialog();
          },
        ),
      ),
    );

    try {
      final settings = ref.read(ytDlpSettingsProvider);
      final ytDlpReady = await DownloadService.instance.ensureYtDlpReady(
        updateChannel: settings.updateChannel,
        onProgress: (progress) =>
            status.value = 'Preparing yt-dlp • ${progress.toStringAsFixed(0)}%',
        onStatus: (message) => status.value = message,
      );
      if (!ytDlpReady) {
        throw StateError('yt-dlp is not available');
      }

      if (Platform.isWindows) {
        status.value = 'Checking FFmpeg and FFprobe…';
        final ffmpegReady = await DownloadService.instance.ensureFFmpegReady(
          onProgress: (progress) => status.value =
              'Preparing FFmpeg • ${progress.toStringAsFixed(0)}%',
          onStatus: (message) => status.value = message,
        );
        if (!ffmpegReady) throw StateError('FFmpeg not found');
      }

      if (cancelled) return;
      status.value = 'Reading title, cover, and stream information…';
      final info = await DownloadService.instance.extractVideoInfo(
        url,
        settings: settings,
      );
      if (cancelled) return;
      status.value = 'Organizing available qualities…';
      final formats = await DownloadService.instance.getAvailableFormats(
        url,
        settings: settings,
      );
      if (cancelled) return;

      if (mounted) _closeRootDialog();
      if (formats.isEmpty) {
        _showMessage('No downloadable formats were found.', isError: true);
        return;
      }

      final title = info['title']?.toString() ?? 'Untitled media';
      final thumbnail = info['thumbnail']?.toString();
      await _rememberLink(
        url: url,
        title: title,
        thumbnail: thumbnail,
        formats: formats,
        videoInfo: info,
      );
      if (!mounted) return;
      await _openFormatPage(
        url: url,
        title: title,
        thumbnail: thumbnail,
        formats: formats,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Could not inspect URL', error, stackTrace);
      if (!mounted || cancelled) return;
      _closeRootDialog();
      _showFriendlyError(error);
    } finally {
      status.dispose();
    }
  }

  Future<void> _rememberLink({
    required String url,
    required String title,
    required String? thumbnail,
    required List<VideoFormat> formats,
    required Map<String, dynamic> videoInfo,
  }) async {
    try {
      final link = RecentLink(
        url: url,
        title: title,
        thumbnail: thumbnail,
        formatsJson: jsonEncode(
          formats
              .map(
                (format) => {
                  'format_id': format.formatId,
                  'resolution': format.resolution,
                  'ext': format.ext,
                  'width': format.width,
                  'height': format.height,
                  'fps': format.fps,
                  'vcodec': format.vcodec,
                  'acodec': format.acodec,
                  'filesize': format.filesize,
                  'filesize_approx': format.filesizeApprox,
                  'tbr': format.tbr,
                  'vbr': format.vbr,
                  'abr': format.abr,
                  'format_note': format.formatNote,
                },
              )
              .toList(),
        ),
        videoInfoJson: jsonEncode(videoInfo),
        createdAt: DateTime.now(),
      );
      await ref.read(recentLinksProvider.notifier).addRecentLink(link);
    } catch (error, stackTrace) {
      AppLogger.warning('Could not save recent link', error, stackTrace);
    }
  }

  Future<void> _openRecent(RecentLink link) async {
    try {
      final formats = link
          .getFormats()
          .map(VideoFormat.fromJson)
          .toList(growable: false);
      await _openFormatPage(
        url: link.url,
        title: link.title,
        thumbnail: link.thumbnail,
        formats: formats,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Could not open cached formats', error, stackTrace);
      _showFriendlyError(error);
    }
  }

  Future<void> _openFormatPage({
    required String url,
    required String title,
    required String? thumbnail,
    required List<VideoFormat> formats,
  }) async {
    final selection = await Navigator.of(context, rootNavigator: true)
        .push<FormatSelectionResult>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                FormatSelectionPage(formats: formats, videoTitle: title),
          ),
        );
    if (selection == null || selection.jobs.isEmpty || !mounted) return;
    await _queueDownloads(
      url: url,
      title: title,
      thumbnail: thumbnail,
      selection: selection,
    );
  }

  Future<void> _queueDownloads({
    required String url,
    required String title,
    required String? thumbnail,
    required FormatSelectionResult selection,
  }) async {
    final baseSettings = ref.read(ytDlpSettingsProvider);
    final notifier = ref.read(downloadsProvider.notifier);

    try {
      for (final job in selection.jobs) {
        final format = job.primaryFormat;
        final item = DownloadItem(
          url: url,
          title: title,
          thumbnail: thumbnail,
          status: DownloadStatus.pending,
          createdAt: DateTime.now(),
          formatId: job.formatSelector,
          formatLabel: job.label,
          videoCodec: job.videoCodec,
          audioCodec: job.audioCodec,
          fileExtension: format.ext,
          quality: job.quality,
          downloadType: job.downloadType,
        );
        final saved = await notifier.addDownload(item);
        final settings = baseSettings.copyWith(
          selectedFormatId: job.formatSelector,
          downloadType: job.downloadType,
          downloadSubtitlesEnabled: selection.downloadSubtitles,
          downloadThumbnailEnabled: selection.downloadThumbnail,
          extractAudio: job.downloadType == 'audio'
              ? baseSettings.extractAudio
              : false,
        );
        unawaited(
          DownloadService.instance
              .startDownload(
                item: saved,
                settings: settings,
                onUpdate: notifier.updateDownload,
              )
              .catchError((Object error, StackTrace stackTrace) {
                AppLogger.error(
                  'Background download failed',
                  error,
                  stackTrace,
                );
              }),
        );
      }

      if (!mounted) return;
      final count = selection.jobs.length;
      _urlController.clear();
      setState(() => _isValidUrl = false);
      _showMessage('$count download${count == 1 ? '' : 's'} added.');
      context.go('/history');
    } catch (error, stackTrace) {
      AppLogger.error('Could not queue downloads', error, stackTrace);
      if (mounted) _showFriendlyError(error);
    }
  }

  void _closeRootDialog() {
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    } catch (_) {
      // The progress dialog may already have been dismissed.
    }
  }

  void _showFriendlyError(Object error) {
    final friendly = DownloadErrorMapper.from(error);
    _showMessage(friendly.displayText, isError: true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.inverseSurface,
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('New download'),
            actions: [
              IconButton(
                tooltip: 'Download history',
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.history_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDownloadWorkspace(context),
                      const SizedBox(height: 16),
                      _buildQueueSnapshot(context),
                      const SizedBox(height: 28),
                      _buildRecentLinks(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadWorkspace(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final intro = Padding(
          padding: EdgeInsets.all(wide ? 30 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.download_for_offline_rounded,
                  color: colors.onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Paste. Pick. Download.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'MBNDL inspects the link first, then lets you choose several '
                'ready-to-play, video-only, or audio-only formats.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              const _StepRow(number: '1', label: 'Paste a supported link'),
              const SizedBox(height: 10),
              const _StepRow(number: '2', label: 'Choose one or more formats'),
              const SizedBox(height: 10),
              const _StepRow(number: '3', label: 'Track everything in History'),
            ],
          ),
        );

        final form = Padding(
          padding: EdgeInsets.all(wide ? 30 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Media link',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Long links wrap across multiple lines so the full address '
                'remains visible.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlController,
                focusNode: _urlFocus,
                minLines: 3,
                maxLines: 6,
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: _validateUrl,
                decoration: InputDecoration(
                  hintText: 'https://example.com/watch?...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 62),
                    child: Icon(Icons.link_rounded),
                  ),
                  suffixIcon: _urlController.text.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 62),
                          child: IconButton(
                            tooltip: 'Clear link',
                            onPressed: () {
                              _urlController.clear();
                              setState(() => _isValidUrl = false);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _urlController.text.isEmpty
                        ? Icons.info_outline_rounded
                        : _isValidUrl
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: _urlController.text.isEmpty
                        ? colors.onSurfaceVariant
                        : _isValidUrl
                        ? colors.primary
                        : colors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _urlController.text.isEmpty
                          ? 'HTTP and HTTPS links supported by yt-dlp are accepted.'
                          : _isValidUrl
                          ? 'Link is ready to inspect.'
                          : 'Paste a complete web address.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Paste'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isValidUrl ? _inspectLink : null,
                      icon: const Icon(Icons.manage_search_rounded),
                      label: const Text('Inspect formats'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          color: colors.surfaceContainerLow,
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: colors.primaryContainer.withValues(alpha: 0.6),
                          child: intro,
                        ),
                      ),
                      Expanded(child: form),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: colors.primaryContainer.withValues(alpha: 0.6),
                      child: intro,
                    ),
                    form,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildQueueSnapshot(BuildContext context) {
    final downloads = ref.watch(downloadsProvider).asData?.value ?? const [];
    final active = downloads
        .where(
          (item) =>
              item.status == DownloadStatus.pending ||
              item.status == DownloadStatus.processing ||
              item.status == DownloadStatus.downloading,
        )
        .length;
    final completed = downloads
        .where((item) => item.status == DownloadStatus.completed)
        .length;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.downloading_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                active == 0
                    ? '$completed completed download${completed == 1 ? '' : 's'}'
                    : '$active active • $completed completed',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/history'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View history'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLinks(BuildContext context) {
    final recent = ref.watch(recentLinksProvider);
    return recent.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded),
          title: const Text('Recent links are unavailable'),
          trailing: IconButton(
            tooltip: 'Retry',
            onPressed: () =>
                ref.read(recentLinksProvider.notifier).loadRecentLinks(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ),
      data: (links) {
        if (links.isEmpty) return const SizedBox.shrink();
        final query = _recentQuery.toLowerCase();
        final filtered = links
            .where((link) {
              return query.isEmpty ||
                  link.title.toLowerCase().contains(query) ||
                  link.url.toLowerCase().contains(query);
            })
            .take(12)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent links',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear recent links',
                  onPressed: () => ref
                      .read(recentLinksProvider.notifier)
                      .clearAllRecentLinks(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _recentQuery = value.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search title or URL',
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No recent link matches this search.'),
                ),
              )
            else
              for (final link in filtered) ...[
                _RecentLinkCard(
                  link: link,
                  onOpen: () => _openRecent(link),
                  onDelete: link.id == null
                      ? null
                      : () => ref
                            .read(recentLinksProvider.notifier)
                            .deleteRecentLink(link.id!),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _InspectionProgress extends StatelessWidget {
  const _InspectionProgress({required this.status, required this.onCancel});

  final ValueListenable<String> status;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.travel_explore_rounded),
      title: const Text('Inspecting link'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 18),
            ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (context, value, _) =>
                  Text(value, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _RecentLinkCard extends StatelessWidget {
  const _RecentLinkCard({
    required this.link,
    required this.onOpen,
    required this.onDelete,
  });

  final RecentLink link;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 112,
                  height: 76,
                  child: link.thumbnail == null
                      ? ColoredBox(
                          color: colors.secondaryContainer,
                          child: const Icon(Icons.movie_outlined),
                        )
                      : Image.network(
                          link.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: colors.secondaryContainer,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      link.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from recent links',
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
