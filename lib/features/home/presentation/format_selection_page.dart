import 'package:flutter/material.dart';

import '../../../shared/models/video_format.dart';

class FormatDownloadJob {
  const FormatDownloadJob({
    required this.formatSelector,
    required this.downloadType,
    required this.label,
    required this.primaryFormat,
    this.secondaryFormat,
  });

  final String formatSelector;
  final String downloadType;
  final String label;
  final VideoFormat primaryFormat;
  final VideoFormat? secondaryFormat;

  String get quality {
    if (downloadType == 'audio') {
      final bitrate = primaryFormat.abr ?? primaryFormat.tbr;
      return bitrate == null ? 'Audio' : '${bitrate.round()} kbps';
    }
    return primaryFormat.resolution ??
        (primaryFormat.height == null
            ? primaryFormat.qualityScore
            : '${primaryFormat.height}p');
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
  });

  final List<VideoFormat> formats;
  final String videoTitle;

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
    final bestCombined = _combinedFormats.firstOrNull;
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

  void _toggle(Set<String> selection, String formatId, bool selected) {
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
          );
        }(),
    ];

    if (_smartMerge) {
      final video = find(_videoFormats, _video.single);
      final audio = find(_audioFormats, _audio.single);
      jobs.add(
        FormatDownloadJob(
          formatSelector: '${video.formatId}+${audio.formatId}',
          downloadType: 'combined',
          label: 'Smart merge • ${video.displayName} + ${audio.displayName}',
          primaryFormat: video,
          secondaryFormat: audio,
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
            Tab(text: 'Ready to play (${_combined.length})'),
            Tab(text: 'Video (${_video.length})'),
            Tab(text: 'Audio (${_audio.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.videoTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select one or several outputs. Your choices stay selected '
                      'when you move between tabs.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FormatList(
                  formats: _combinedFormats,
                  selectedIds: _combined,
                  emptyTitle: 'No ready-to-play formats',
                  emptyDescription:
                      'Choose a video stream and an audio stream instead.',
                  onChanged: (format, selected) =>
                      _toggle(_combined, format.formatId, selected),
                ),
                _FormatList(
                  formats: _videoFormats,
                  selectedIds: _video,
                  emptyTitle: 'No separate video streams',
                  emptyDescription:
                      'This source only exposes combined formats.',
                  onChanged: (format, selected) =>
                      _toggle(_video, format.formatId, selected),
                ),
                _FormatList(
                  formats: _audioFormats,
                  selectedIds: _audio,
                  emptyTitle: 'No separate audio streams',
                  emptyDescription:
                      'This source only exposes ready-to-play formats.',
                  onChanged: (format, selected) =>
                      _toggle(_audio, format.formatId, selected),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: _smartMerge,
                      onChanged: _canSmartMerge
                          ? (value) => setState(() => _smartMerge = value)
                          : null,
                      secondary: const Icon(Icons.auto_fix_high_rounded),
                      title: const Text('Smart merge separate streams'),
                      subtitle: Text(
                        _canSmartMerge
                            ? 'The selected video and audio become one playable file.'
                            : 'Select exactly one video and one audio stream to enable.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final options = [
                          CheckboxListTile(
                            value: _downloadThumbnail,
                            onChanged: (value) => setState(
                              () => _downloadThumbnail = value ?? false,
                            ),
                            title: const Text('Save cover'),
                            secondary: const Icon(Icons.image_outlined),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            value: _downloadSubtitles,
                            onChanged: (value) => setState(
                              () => _downloadSubtitles = value ?? false,
                            ),
                            title: const Text('Save subtitles'),
                            secondary: const Icon(Icons.subtitles_outlined),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ];
                        if (constraints.maxWidth < 620) {
                          return Column(children: options);
                        }
                        return Row(
                          children: [
                            for (final option in options)
                              Expanded(child: option),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _outputCount == 0
                                ? 'No output selected'
                                : '$_outputCount output${_outputCount == 1 ? '' : 's'} selected',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _outputCount == 0
                              ? null
                              : () => Navigator.pop(context, _result()),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Add to downloads'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatList extends StatelessWidget {
  const _FormatList({
    required this.formats,
    required this.selectedIds,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onChanged,
  });

  final List<VideoFormat> formats;
  final Set<String> selectedIds;
  final String emptyTitle;
  final String emptyDescription;
  final void Function(VideoFormat format, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_none_rounded, size: 52),
              const SizedBox(height: 16),
              Text(emptyTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(emptyDescription, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 112,
          ),
          itemCount: formats.length,
          itemBuilder: (context, index) {
            final format = formats[index];
            final selected = selectedIds.contains(format.formatId);
            return _FormatCard(
              format: format,
              selected: selected,
              onChanged: (value) => onChanged(format, value),
            );
          },
        );
      },
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.selected,
    required this.onChanged,
  });

  final VideoFormat format;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <String>[
      if (format.hasValidFilesize) format.filesizeDisplay,
      if (format.hasValidBitrate) format.bitrateDisplay,
      if (format.hasValidFps) '${format.fps!.round()} fps',
      'ID ${format.formatId}',
    ];
    return Card(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details.join('  •  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                format.hasVideo
                    ? format.hasAudio
                          ? Icons.movie_filter_rounded
                          : Icons.videocam_outlined
                    : Icons.graphic_eq_rounded,
                color: selected ? colors.onSecondaryContainer : colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
