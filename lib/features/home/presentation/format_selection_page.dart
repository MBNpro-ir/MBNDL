import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/video_format.dart';

class FormatDownloadJob {
  const FormatDownloadJob({
    required this.formatSelector,
    required this.downloadType,
    required this.label,
    required this.primaryFormat,
    this.secondaryFormat,
    this.previousDownloadCount = 0,
  });

  final String formatSelector;
  final String downloadType;
  final String label;
  final VideoFormat primaryFormat;
  final VideoFormat? secondaryFormat;
  final int previousDownloadCount;

  bool get wasDownloadedBefore => previousDownloadCount > 0;
  bool get isSmartMerge =>
      secondaryFormat != null && formatSelector.contains('+');

  String get quality {
    if (downloadType == 'audio') {
      final bitrate = primaryFormat.abr ?? primaryFormat.tbr;
      return bitrate == null ? 'Audio' : '${bitrate.round()} kbps';
    }
    if (primaryFormat.height != null && primaryFormat.height! > 0) {
      return '${primaryFormat.height}p';
    }
    return _simpleResolution(primaryFormat);
  }

  String? get videoCodec =>
      downloadType == 'audio' ? null : primaryFormat.vcodec;

  String? get audioCodec => secondaryFormat?.acodec ?? primaryFormat.acodec;
}

class FormatSelectionResult {
  const FormatSelectionResult({
    required this.jobs,
    required this.downloadSubtitles,
    required this.downloadThumbnail,
  });

  final List<FormatDownloadJob> jobs;
  final bool downloadSubtitles;
  final bool downloadThumbnail;
}

class FormatSelectionPage extends StatefulWidget {
  const FormatSelectionPage({
    super.key,
    required this.formats,
    required this.videoTitle,
    this.previousDownloads = const {},
    this.sourceNotice,
    this.batchItemCount = 1,
  });

  final List<VideoFormat> formats;
  final String videoTitle;
  final Map<String, int> previousDownloads;
  final String? sourceNotice;
  final int batchItemCount;

  @override
  State<FormatSelectionPage> createState() => _FormatSelectionPageState();
}

class _FormatSelectionPageState extends State<FormatSelectionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _combined = {};
  final Set<String> _video = {};
  final Set<String> _audio = {};
  bool _smartMerge = false;
  bool _downloadSubtitles = false;
  bool _downloadThumbnail = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final bestCombined = _combinedFormats
        .where((format) => !_wasFormatUsed(format.formatId))
        .firstOrNull;
    if (bestCombined != null) _combined.add(bestCombined.formatId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<VideoFormat> get _combinedFormats =>
      widget.formats
          .where((format) => format.hasVideo && format.hasAudio)
          .toList()
        ..sort(_sortVideo);

  List<VideoFormat> get _videoFormats =>
      widget.formats
          .where((format) => format.hasVideo && !format.hasAudio)
          .toList()
        ..sort(_sortVideo);

  List<VideoFormat> get _audioFormats =>
      widget.formats
          .where((format) => !format.hasVideo && format.hasAudio)
          .toList()
        ..sort((a, b) => (b.abr ?? b.tbr ?? 0).compareTo(a.abr ?? a.tbr ?? 0));

  static int _sortVideo(VideoFormat a, VideoFormat b) {
    final height = (b.height ?? 0).compareTo(a.height ?? 0);
    return height != 0 ? height : (b.tbr ?? 0).compareTo(a.tbr ?? 0);
  }

  int get _outputCount =>
      _combined.length + (_smartMerge ? 1 : _video.length + _audio.length);

  bool get _canSmartMerge => _video.length == 1 && _audio.length == 1;

  bool _wasFormatUsed(String formatId) => widget.previousDownloads.entries.any(
    (entry) => entry.value > 0 && entry.key.split('+').contains(formatId),
  );

  int _previousCount(String selector) =>
      widget.previousDownloads[selector] ?? 0;

  Future<void> _toggle(
    Set<String> selection,
    String formatId,
    bool selected,
  ) async {
    if (selected && _wasFormatUsed(formatId)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.download_done_rounded),
          title: const Text('This quality was downloaded before'),
          content: const Text(
            'History shows an existing download that used this stream. You '
            'can continue; MBNDL will create a clearly named copy and will '
            'not overwrite the earlier file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Download another copy'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() {
      selected ? selection.add(formatId) : selection.remove(formatId);
      if (!_canSmartMerge) _smartMerge = false;
    });
  }

  FormatSelectionResult _result() {
    VideoFormat find(List<VideoFormat> formats, String id) =>
        formats.firstWhere((format) => format.formatId == id);

    final jobs = <FormatDownloadJob>[
      for (final id in _combined)
        () {
          final format = find(_combinedFormats, id);
          return FormatDownloadJob(
            formatSelector: format.formatId,
            downloadType: 'combined',
            label: format.displayName,
            primaryFormat: format,
            previousDownloadCount: _previousCount(format.formatId),
          );
        }(),
    ];

    if (_smartMerge) {
      final video = find(_videoFormats, _video.single);
      final audio = find(_audioFormats, _audio.single);
      final selector = '${video.formatId}+${audio.formatId}';
      jobs.add(
        FormatDownloadJob(
          formatSelector: selector,
          downloadType: 'combined',
          label:
              'One merged file • ${_simpleResolution(video)} • ${_codecName(video.vcodec)} + ${_codecName(audio.acodec)}',
          primaryFormat: video,
          secondaryFormat: audio,
          previousDownloadCount: _previousCount(selector),
        ),
      );
    } else {
      for (final id in _video) {
        final format = find(_videoFormats, id);
        jobs.add(
          FormatDownloadJob(
            formatSelector: format.formatId,
            downloadType: 'video',
            label: 'Video only • ${format.displayName}',
            primaryFormat: format,
            previousDownloadCount: _previousCount(format.formatId),
          ),
        );
      }
      for (final id in _audio) {
        final format = find(_audioFormats, id);
        jobs.add(
          FormatDownloadJob(
            formatSelector: format.formatId,
            downloadType: 'audio',
            label: 'Audio only • ${format.displayName}',
            primaryFormat: format,
            previousDownloadCount: _previousCount(format.formatId),
          ),
        );
      }
    }

    return FormatSelectionResult(
      jobs: jobs,
      downloadSubtitles: _downloadSubtitles,
      downloadThumbnail: _downloadThumbnail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Choose formats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Ready (${_combined.length})'),
            Tab(text: 'Video (${_video.length})'),
            Tab(text: 'Audio (${_audio.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _FormatHeader(
            title: widget.videoTitle,
            sourceNotice: widget.sourceNotice,
            batchItemCount: widget.batchItemCount,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GroupedFormatList(
                  formats: _combinedFormats,
                  selectedIds: _combined,
                  emptyTitle: 'No ready-to-play formats',
                  emptyDescription:
                      'Choose one video stream and one audio stream, then enable Smart merge.',
                  groupingHint: 'Grouped by resolution • each row is a codec',
                  onChanged: (format, selected) =>
                      unawaited(_toggle(_combined, format.formatId, selected)),
                  wasDownloaded: _wasFormatUsed,
                ),
                _GroupedFormatList(
                  formats: _videoFormats,
                  selectedIds: _video,
                  emptyTitle: 'No separate video streams',
                  emptyDescription:
                      'This source only exposes ready-to-play formats.',
                  groupingHint: 'Choose a resolution, then compare its codecs',
                  onChanged: (format, selected) =>
                      unawaited(_toggle(_video, format.formatId, selected)),
                  wasDownloaded: _wasFormatUsed,
                ),
                _GroupedFormatList(
                  formats: _audioFormats,
                  selectedIds: _audio,
                  emptyTitle: 'No separate audio streams',
                  emptyDescription:
                      'This source only exposes ready-to-play formats.',
                  groupingHint:
                      'Grouped by bitrate • each row is an audio codec',
                  audio: true,
                  onChanged: (format, selected) =>
                      unawaited(_toggle(_audio, format.formatId, selected)),
                  wasDownloaded: _wasFormatUsed,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SelectionFooter(
        colors: colors,
        outputCount: _outputCount,
        smartMerge: _smartMerge,
        canSmartMerge: _canSmartMerge,
        downloadThumbnail: _downloadThumbnail,
        downloadSubtitles: _downloadSubtitles,
        onSmartMergeChanged: (value) => setState(() => _smartMerge = value),
        onThumbnailChanged: (value) =>
            setState(() => _downloadThumbnail = value),
        onSubtitlesChanged: (value) =>
            setState(() => _downloadSubtitles = value),
        onSubmit: _outputCount == 0
            ? null
            : () => Navigator.pop(context, _result()),
      ),
    );
  }
}

class _FormatHeader extends StatelessWidget {
  const _FormatHeader({
    required this.title,
    required this.sourceNotice,
    required this.batchItemCount,
  });

  final String title;
  final String? sourceNotice;
  final int batchItemCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Select several outputs, or pair exactly one video and one audio stream.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (sourceNotice?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.manage_search_rounded,
                            size: 20,
                            color: colors.onTertiaryContainer,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${sourceNotice!}${batchItemCount > 1 ? ' This choice applies to all $batchItemCount items.' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.onTertiaryContainer,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionFooter extends StatelessWidget {
  const _SelectionFooter({
    required this.colors,
    required this.outputCount,
    required this.smartMerge,
    required this.canSmartMerge,
    required this.downloadThumbnail,
    required this.downloadSubtitles,
    required this.onSmartMergeChanged,
    required this.onThumbnailChanged,
    required this.onSubtitlesChanged,
    required this.onSubmit,
  });

  final ColorScheme colors;
  final int outputCount;
  final bool smartMerge;
  final bool canSmartMerge;
  final bool downloadThumbnail;
  final bool downloadSubtitles;
  final ValueChanged<bool> onSmartMergeChanged;
  final ValueChanged<bool> onThumbnailChanged;
  final ValueChanged<bool> onSubtitlesChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 520;
                  final actionLabel = outputCount == 0
                      ? 'Choose an output'
                      : outputCount == 1
                      ? 'Add 1 output'
                      : 'Add $outputCount outputs';
                  final action = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: Size(narrow ? double.infinity : 170, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: onSubmit,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(actionLabel),
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: canSmartMerge
                            ? () => onSmartMergeChanged(!smartMerge)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: canSmartMerge
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 20,
                                  color: canSmartMerge
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart merge into one file',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      canSmartMerge
                                          ? 'One video + one audio → one playable file; source streams are removed.'
                                          : 'Select exactly one video and one audio stream.',
                                      maxLines: narrow ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Switch.adaptive(
                                value: smartMerge,
                                onChanged: canSmartMerge
                                    ? onSmartMergeChanged
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          FilterChip(
                            selected: downloadThumbnail,
                            avatar: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('Cover'),
                            onSelected: onThumbnailChanged,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: downloadSubtitles,
                            avatar: const Icon(
                              Icons.subtitles_outlined,
                              size: 18,
                            ),
                            label: const Text('Subtitles'),
                            onSelected: onSubtitlesChanged,
                          ),
                          if (!narrow) ...[
                            const Spacer(),
                            Text(
                              outputCount == 0
                                  ? 'Nothing selected'
                                  : '$outputCount final file${outputCount == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(width: 12),
                            action,
                          ],
                        ],
                      ),
                      if (narrow) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            outputCount == 0
                                ? 'Nothing selected'
                                : '$outputCount final file${outputCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(height: 6),
                        action,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedFormatList extends StatelessWidget {
  const _GroupedFormatList({
    required this.formats,
    required this.selectedIds,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.groupingHint,
    required this.onChanged,
    required this.wasDownloaded,
    this.audio = false,
  });

  final List<VideoFormat> formats;
  final Set<String> selectedIds;
  final String emptyTitle;
  final String emptyDescription;
  final String groupingHint;
  final void Function(VideoFormat format, bool selected) onChanged;
  final bool Function(String formatId) wasDownloaded;
  final bool audio;

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_none_rounded, size: 48),
              const SizedBox(height: 14),
              Text(emptyTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(emptyDescription, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final buckets = audio
        ? _groupAudioFormats(formats)
        : _groupVideoFormats(formats);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      itemCount: buckets.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    Icon(
                      audio ? Icons.graphic_eq_rounded : Icons.hd_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        groupingHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final bucket = buckets[index - 1];
        final selectedCount = bucket.formats
            .where((format) => selectedIds.contains(format.formatId))
            .length;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _FormatBucketCard(
                bucket: bucket,
                selectedCount: selectedCount,
                selectedIds: selectedIds,
                wasDownloaded: wasDownloaded,
                onChanged: onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormatBucketCard extends StatelessWidget {
  const _FormatBucketCard({
    required this.bucket,
    required this.selectedCount,
    required this.selectedIds,
    required this.wasDownloaded,
    required this.onChanged,
  });

  final _FormatBucket bucket;
  final int selectedCount;
  final Set<String> selectedIds;
  final bool Function(String formatId) wasDownloaded;
  final void Function(VideoFormat format, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: selectedCount > 0
          ? colors.secondaryContainer.withValues(alpha: 0.46)
          : colors.surfaceContainerLow,
      child: ExpansionTile(
        key: PageStorageKey('format-bucket-${bucket.key}'),
        initiallyExpanded: bucket.initiallyExpanded || selectedCount > 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        leading: Container(
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: selectedCount > 0
                ? colors.primary
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            bucket.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selectedCount > 0 ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          bucket.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${bucket.formats.length} ${bucket.formats.length == 1 ? 'codec option' : 'codec options'}'
          '${selectedCount == 0 ? '' : ' • $selectedCount selected'}',
        ),
        children: [
          for (final format in bucket.formats)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _CompactFormatTile(
                format: format,
                selected: selectedIds.contains(format.formatId),
                downloaded: wasDownloaded(format.formatId),
                onChanged: (value) => onChanged(format, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactFormatTile extends StatelessWidget {
  const _CompactFormatTile({
    required this.format,
    required this.selected,
    required this.downloaded,
    required this.onChanged,
  });

  final VideoFormat format;
  final bool selected;
  final bool downloaded;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <String>[
      if (format.width != null && format.height != null)
        '${format.width}×${format.height}',
      if (format.hasValidFilesize) format.filesizeDisplay,
      if (format.hasValidBitrate) format.bitrateDisplay,
      if (format.hasValidFps) '${format.fps!.round()} fps',
      'ID ${format.formatId}',
    ];
    final technicalDetails = <String>[
      if (format.formatNote?.trim().isNotEmpty == true) format.formatNote!,
      if (format.dynamicRange?.trim().isNotEmpty == true)
        format.dynamicRange!.toUpperCase(),
      if (format.channelDisplay != null) format.channelDisplay!,
      if (format.sampleRateDisplay != null) format.sampleRateDisplay!,
      if (format.protocol?.trim().isNotEmpty == true)
        format.protocol!.toUpperCase(),
      if (format.vcodec?.trim().isNotEmpty == true && format.vcodec != 'none')
        'V: ${format.vcodec}',
      if (format.acodec?.trim().isNotEmpty == true && format.acodec != 'none')
        'A: ${format.acodec}',
    ];
    final title = _codecVariantLabel(format);
    return Material(
      color: downloaded
          ? colors.tertiaryContainer
          : selected
          ? colors.secondaryContainer
          : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 11, 8),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (value) => onChanged(value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (downloaded)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.tertiary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Downloaded',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onTertiary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        if (format.languageBadge != null)
                          _FormatMetadataChip(
                            label: format.languageBadge!,
                            emphasized: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.join('  •  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: downloaded
                            ? colors.onTertiaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    if (technicalDetails.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final detail in technicalDetails)
                            _FormatMetadataChip(label: detail),
                        ],
                      ),
                    ],
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

class _FormatMetadataChip extends StatelessWidget {
  const _FormatMetadataChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: ShapeDecoration(
        color: emphasized
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasized
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _FormatBucket {
  const _FormatBucket({
    required this.key,
    required this.label,
    required this.title,
    required this.formats,
    required this.sortValue,
    this.initiallyExpanded = false,
  });

  final String key;
  final String label;
  final String title;
  final List<VideoFormat> formats;
  final double sortValue;
  final bool initiallyExpanded;
}

List<_FormatBucket> _groupVideoFormats(List<VideoFormat> formats) {
  final groups = <String, List<VideoFormat>>{};
  for (final format in formats) {
    final key = format.height?.toString() ?? _simpleResolution(format);
    groups.putIfAbsent(key, () => []).add(format);
  }

  final buckets = <_FormatBucket>[];
  for (final entry in groups.entries) {
    final values = entry.value
      ..sort((a, b) => (b.tbr ?? 0).compareTo(a.tbr ?? 0));
    final first = values.first;
    final label = _simpleResolution(first);
    buckets.add(
      _FormatBucket(
        key: 'video-${entry.key}',
        label: label,
        title: '$label resolution',
        formats: values,
        sortValue: (first.height ?? 0).toDouble(),
      ),
    );
  }
  buckets.sort((a, b) => b.sortValue.compareTo(a.sortValue));
  if (buckets.isNotEmpty) {
    final first = buckets.first;
    buckets[0] = _FormatBucket(
      key: first.key,
      label: first.label,
      title: first.title,
      formats: first.formats,
      sortValue: first.sortValue,
      initiallyExpanded: true,
    );
  }
  return buckets;
}

List<_FormatBucket> _groupAudioFormats(List<VideoFormat> formats) {
  final groups = <String, List<VideoFormat>>{};
  for (final format in formats) {
    final bitrate = format.abr ?? format.tbr;
    final key = bitrate == null ? 'unknown' : bitrate.round().toString();
    groups.putIfAbsent(key, () => []).add(format);
  }

  final buckets = <_FormatBucket>[];
  for (final entry in groups.entries) {
    final values = entry.value
      ..sort((a, b) => (b.abr ?? b.tbr ?? 0).compareTo(a.abr ?? a.tbr ?? 0));
    final bitrate = values.first.abr ?? values.first.tbr;
    final label = bitrate == null ? 'Audio' : '${bitrate.round()} kbps';
    buckets.add(
      _FormatBucket(
        key: 'audio-${entry.key}',
        label: label,
        title: bitrate == null ? 'Other audio' : '$label audio',
        formats: values,
        sortValue: bitrate ?? 0,
      ),
    );
  }
  buckets.sort((a, b) => b.sortValue.compareTo(a.sortValue));
  if (buckets.isNotEmpty) {
    final first = buckets.first;
    buckets[0] = _FormatBucket(
      key: first.key,
      label: first.label,
      title: first.title,
      formats: first.formats,
      sortValue: first.sortValue,
      initiallyExpanded: true,
    );
  }
  return buckets;
}

String _simpleResolution(VideoFormat format) {
  if (format.height != null && format.height! > 0) {
    return '${format.height}p';
  }
  final resolution = format.resolution?.trim() ?? '';
  final dimensions = RegExp(r'\d+[xX](\d+)').firstMatch(resolution);
  if (dimensions != null) return '${dimensions.group(1)}p';
  final simple = RegExp(
    r'(\d{3,4})p',
    caseSensitive: false,
  ).firstMatch(resolution);
  if (simple != null) return '${simple.group(1)}p';
  return format.hasVideo ? 'Unknown' : 'Audio';
}

String _codecVariantLabel(VideoFormat format) {
  final codec = format.hasVideo
      ? _codecName(format.vcodec)
      : _codecName(format.acodec);
  final container = format.ext?.toUpperCase();
  final audio = format.hasVideo && format.hasAudio ? ' + audio' : '';
  return [codec, if (container?.isNotEmpty == true) container!].join(' • ') +
      audio;
}

String _codecName(String? codec) {
  final value = codec?.toLowerCase().trim() ?? '';
  if (value.isEmpty || value == 'none') return 'Unknown codec';
  if (value.startsWith('av01') || value == 'av1') return 'AV1';
  if (value.startsWith('vp09') || value.startsWith('vp9')) return 'VP9';
  if (value.startsWith('vp8')) return 'VP8';
  if (value.startsWith('avc1') || value.contains('h264')) return 'H.264';
  if (value.startsWith('hev1') ||
      value.startsWith('hvc1') ||
      value.contains('hevc') ||
      value.contains('h265')) {
    return 'H.265';
  }
  if (value.startsWith('mp4a') || value.contains('aac')) return 'AAC';
  if (value.contains('opus')) return 'Opus';
  if (value.contains('vorbis')) return 'Vorbis';
  if (value.contains('mp3')) return 'MP3';
  return codec!.split('.').first.toUpperCase();
}
