import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/cookie_provider.dart';
import '../../../shared/utils/validators.dart';
import '../../../services/storage/presets_storage_service.dart';
import '../../../services/downloader/android_ytdlp_service.dart';
import '../domain/yt_dlp_settings.dart';
import '../domain/custom_preset.dart';
import 'cookie_manager_page.dart';

class YtDlpSettingsPage extends ConsumerStatefulWidget {
  const YtDlpSettingsPage({super.key});

  @override
  ConsumerState<YtDlpSettingsPage> createState() => _YtDlpSettingsPageState();
}

class _YtDlpSettingsPageState extends ConsumerState<YtDlpSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasUnsavedChanges = false;
  YtDlpSettings? _originalSettings;
  String? _androidEngineVersion;
  bool _updatingAndroidEngine = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    PresetsStorageService.instance.initialize();
    if (Platform.isAndroid) _loadAndroidEngineVersion();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(ytDlpSettingsProvider);

    if (_originalSettings == null) {
      _originalSettings = settings;
    } else if (_originalSettings != settings) {
      _hasUnsavedChanges = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('yt-dlp Settings'),
        actions: [
          if (_hasUnsavedChanges && !_isBuiltInPreset(settings.preset))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Save as Custom Preset',
              onPressed: _showSavePresetDialog,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Presets'),
            Tab(text: 'Download'),
            Tab(text: 'Network'),
            Tab(text: 'Files'),
            Tab(text: 'Subtitles'),
            Tab(text: 'Post-Processing'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPresetsTab(settings),
              _buildDownloadTab(settings),
              _buildNetworkTab(settings),
              _buildFilesTab(settings),
              _buildSubtitlesTab(settings),
              _buildPostProcessingTab(settings),
              _buildAdvancedTab(settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Presets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a preset configuration optimized for different scenarios',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _PresetButton(
                  title: 'Default',
                  description: 'Standard settings with metadata',
                  icon: Icons.settings,
                  isSelected: settings.preset == 'default',
                  onTap: () => _applyPreset('default'),
                ),
                const SizedBox(height: 12),
                _PresetButton(
                  title: 'Fast Download',
                  description: 'Accelerated download using aria2c',
                  icon: Icons.speed,
                  isSelected: settings.preset == 'speed',
                  onTap: () => _applyPreset('speed'),
                ),
                const SizedBox(height: 12),
                _PresetButton(
                  title: 'SLOW CONNECTION',
                  description: 'Optimized for slow/restricted connections',
                  icon: Icons.security,
                  isSelected: settings.preset == 'ip_limited',
                  onTap: () => _applyPreset('ip_limited'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CustomPreset>>(
          future: Future.value(
            PresetsStorageService.instance.getCustomPresets(),
          ),
          builder: (context, snapshot) {
            final customPresets = snapshot.data ?? [];
            if (customPresets.isEmpty) {
              return const SizedBox.shrink();
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Presets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...customPresets.map(
                      (preset) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PresetButton(
                          title: preset.name,
                          description: 'Custom configuration',
                          icon: Icons.star,
                          isSelected: settings.preset == preset.id,
                          onTap: () {
                            ref
                                .read(ytDlpSettingsProvider.notifier)
                                .updateSettings(preset.settings);
                            setState(() {
                              _hasUnsavedChanges = false;
                              _originalSettings = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Preset',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(settings.preset.toUpperCase()),
                  avatar: Icon(_getPresetIcon(settings.preset), size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isBuiltInPreset(String preset) {
    return ['default', 'speed', 'ip_limited'].contains(preset);
  }

  void _applyPreset(String presetName) {
    ref.read(ytDlpSettingsProvider.notifier).loadPreset(presetName);
    setState(() {
      _hasUnsavedChanges = false;
      _originalSettings = null;
    });
  }

  IconData _getPresetIcon(String preset) {
    switch (preset) {
      case 'speed':
        return Icons.speed;
      case 'ip_limited':
        return Icons.security;
      case 'default':
        return Icons.settings;
      default:
        return Icons.star;
    }
  }

  Widget _buildDownloadTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Performance', [
          _buildSliderTile(
            'Concurrent Fragments',
            settings.concurrentFragments.toDouble(),
            1,
            16,
            (value) => _updateSettings(
              settings.copyWith(concurrentFragments: value.toInt()),
            ),
          ),
          _buildSliderTile(
            'Retries',
            settings.retries.toDouble(),
            1,
            50,
            (value) =>
                _updateSettings(settings.copyWith(retries: value.toInt())),
          ),
          _buildSwitchTile(
            'Use aria2c',
            'Accelerate downloads with aria2c',
            settings.useAria2c,
            (value) => _updateSettings(settings.copyWith(useAria2c: value)),
          ),
        ]),
        _buildSectionCard('Limits', [
          _buildTextFieldTile(
            'Rate Limit',
            'e.g., 1M, 500K (empty for unlimited)',
            settings.rateLimit,
            (value) => _updateSettings(settings.copyWith(rateLimit: value)),
            validator: Validators.validateRateLimit,
          ),
          _buildTextFieldTile(
            'Buffer Size',
            'e.g., 1024, 16K',
            settings.bufferSize,
            (value) => _updateSettings(settings.copyWith(bufferSize: value)),
            validator: Validators.validateBufferSize,
          ),
        ]),
        _buildSectionCard('Playlist', [
          _buildSwitchTile(
            'Download Playlist',
            'Download entire playlist if URL is a playlist',
            settings.downloadPlaylist,
            (value) =>
                _updateSettings(settings.copyWith(downloadPlaylist: value)),
          ),
          _buildTextFieldTile(
            'Playlist Items',
            'e.g., 1-10, 1,3,5',
            settings.playlistItems,
            (value) => _updateSettings(settings.copyWith(playlistItems: value)),
            validator: Validators.validatePlaylistItems,
          ),
          _buildSwitchTile(
            'Random Order',
            'Download playlist items in random order',
            settings.playlistRandom,
            (value) =>
                _updateSettings(settings.copyWith(playlistRandom: value)),
          ),
        ]),
      ],
    );
  }

  Widget _buildNetworkTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Authentication', [
          Consumer(
            builder: (context, ref, child) {
              final cookieState = ref.watch(cookieProvider);
              final selectedCookie = cookieState.selectedCookie;

              return ListTile(
                title: const Text('Cookies'),
                subtitle: Text(
                  selectedCookie != null
                      ? 'Selected: ${selectedCookie.name}'
                      : 'No cookie selected',
                ),
                trailing: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CookieManagerPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cookie),
                  label: const Text('Manage Cookies'),
                ),
              );
            },
          ),
        ]),
        _buildSectionCard('Proxy', [
          _buildTextFieldTile(
            'Proxy URL',
            'e.g., socks5://127.0.0.1:1080',
            settings.proxy,
            (value) => _updateSettings(settings.copyWith(proxy: value)),
            validator: Validators.validateProxy,
          ),
        ]),
        _buildSectionCard('Connection', [
          _buildSliderTile(
            'Socket Timeout (seconds)',
            settings.socketTimeout.toDouble(),
            5,
            60,
            (value) => _updateSettings(
              settings.copyWith(socketTimeout: value.toInt()),
            ),
          ),
          _buildSwitchTile(
            'Force IPv4',
            'Make all connections via IPv4',
            settings.forceIpv4,
            (value) => _updateSettings(
              settings.copyWith(forceIpv4: value, forceIpv6: false),
            ),
          ),
          _buildSwitchTile(
            'Force IPv6',
            'Make all connections via IPv6',
            settings.forceIpv6,
            (value) => _updateSettings(
              settings.copyWith(forceIpv6: value, forceIpv4: false),
            ),
          ),
        ]),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cookies File',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Use cookies for platforms that require authentication.\n'
                  'Export cookies from your browser in Netscape format.\n\n'
                  'Extensions like "Get cookies.txt LOCALLY" can help export cookies.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Output Template', [
          _buildTextFieldTile(
            'Template',
            '%(title)s.%(ext)s',
            settings.outputTemplate,
            (value) =>
                _updateSettings(settings.copyWith(outputTemplate: value)),
          ),
        ]),
        _buildSectionCard('File Options', [
          _buildSwitchTile(
            'Overwrite Files',
            'Overwrite existing files',
            settings.overwriteFiles,
            (value) =>
                _updateSettings(settings.copyWith(overwriteFiles: value)),
          ),
          _buildSwitchTile(
            'Continue Download',
            'Resume partially downloaded files',
            settings.continueDownload,
            (value) =>
                _updateSettings(settings.copyWith(continueDownload: value)),
          ),
          _buildSwitchTile(
            'Restrict Filenames',
            'Restrict filenames to ASCII characters',
            settings.restrictFilenames,
            (value) =>
                _updateSettings(settings.copyWith(restrictFilenames: value)),
          ),
          _buildSwitchTile(
            'Windows Compatible',
            'Force Windows-compatible filenames',
            settings.windowsFilenames,
            (value) =>
                _updateSettings(settings.copyWith(windowsFilenames: value)),
          ),
        ]),
        _buildSectionCard('Metadata Files', [
          _buildSwitchTile(
            'Write Thumbnail',
            'Save thumbnail image',
            settings.writeThumbnail,
            (value) =>
                _updateSettings(settings.copyWith(writeThumbnail: value)),
          ),
          _buildSwitchTile(
            'Write Description',
            'Save video description',
            settings.writeDescription,
            (value) =>
                _updateSettings(settings.copyWith(writeDescription: value)),
          ),
          _buildSwitchTile(
            'Write Info JSON',
            'Save video metadata as JSON',
            settings.writeInfoJson,
            (value) => _updateSettings(settings.copyWith(writeInfoJson: value)),
          ),
        ]),
      ],
    );
  }

  Widget _buildSubtitlesTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Subtitle Downloads', [
          _buildSwitchTile(
            'Download Subtitles',
            'Download available subtitles',
            settings.downloadSubtitles,
            (value) =>
                _updateSettings(settings.copyWith(downloadSubtitles: value)),
          ),
          _buildSwitchTile(
            'Auto-Generated Subtitles',
            'Include auto-generated subtitles',
            settings.autoSubtitles,
            (value) => _updateSettings(settings.copyWith(autoSubtitles: value)),
          ),
          _buildTextFieldTile(
            'Languages',
            'e.g., en,fa,ar (comma-separated)',
            settings.subtitleLanguages,
            (value) =>
                _updateSettings(settings.copyWith(subtitleLanguages: value)),
            validator: Validators.validateLanguageCodes,
          ),
          _buildDropdownTile(
            'Subtitle Format',
            settings.subtitleFormat,
            ['srt', 'vtt', 'ass', 'lrc'],
            (value) =>
                _updateSettings(settings.copyWith(subtitleFormat: value!)),
          ),
        ]),
        _buildSectionCard('Subtitle Processing', [
          _buildSwitchTile(
            'Embed Subtitles',
            'Embed subtitles in video file',
            settings.embedSubtitles,
            (value) =>
                _updateSettings(settings.copyWith(embedSubtitles: value)),
          ),
          _buildDropdownTile(
            'Convert Format',
            settings.convertSubtitles.isEmpty
                ? 'none'
                : settings.convertSubtitles,
            ['none', 'srt', 'vtt', 'ass', 'lrc'],
            (value) => _updateSettings(
              settings.copyWith(
                convertSubtitles: value == 'none' ? '' : value!,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildPostProcessingTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Metadata Embedding', [
          _buildSwitchTile(
            'Embed Thumbnail',
            'Embed thumbnail in video file',
            settings.embedThumbnail,
            (value) =>
                _updateSettings(settings.copyWith(embedThumbnail: value)),
          ),
          _buildSwitchTile(
            'Embed Metadata',
            'Add metadata to video file',
            settings.embedMetadata,
            (value) => _updateSettings(settings.copyWith(embedMetadata: value)),
          ),
          _buildSwitchTile(
            'Embed Chapters',
            'Add chapter markers',
            settings.embedChapters,
            (value) => _updateSettings(settings.copyWith(embedChapters: value)),
          ),
        ]),
        _buildSectionCard('Audio Extraction', [
          _buildSwitchTile(
            'Extract Audio',
            'Convert to audio-only file',
            settings.extractAudio,
            (value) => _updateSettings(settings.copyWith(extractAudio: value)),
          ),
          if (settings.extractAudio) ...[
            _buildDropdownTile(
              'Audio Format',
              settings.audioFormat.isEmpty ? 'mp3' : settings.audioFormat,
              ['mp3', 'aac', 'flac', 'm4a', 'opus', 'vorbis', 'wav'],
              (value) =>
                  _updateSettings(settings.copyWith(audioFormat: value!)),
            ),
            _buildSliderTile(
              'Audio Quality (0=best, 10=worst)',
              double.parse(settings.audioQuality),
              0,
              10,
              (value) => _updateSettings(
                settings.copyWith(audioQuality: value.toInt().toString()),
              ),
            ),
            _buildSwitchTile(
              'Keep Video',
              'Keep original video file after extraction',
              settings.keepVideo,
              (value) => _updateSettings(settings.copyWith(keepVideo: value)),
            ),
          ],
        ]),
        _buildSectionCard('Video Conversion', [
          _buildDropdownTile(
            'Remux Video',
            settings.remuxVideo.isEmpty ? 'none' : settings.remuxVideo,
            ['none', 'mp4', 'mkv', 'webm', 'avi', 'flv'],
            (value) => _updateSettings(
              settings.copyWith(remuxVideo: value == 'none' ? '' : value!),
            ),
          ),
          _buildSwitchTile(
            'Split by Chapters',
            'Split video into multiple files by chapters',
            settings.splitChapters,
            (value) => _updateSettings(settings.copyWith(splitChapters: value)),
          ),
        ]),
        _buildSectionCard('SponsorBlock', [
          _buildSwitchTile(
            'Mark Sponsor Segments',
            'Create chapters for sponsor segments',
            settings.sponsorblockMark,
            (value) =>
                _updateSettings(settings.copyWith(sponsorblockMark: value)),
          ),
          if (settings.sponsorblockMark)
            _buildTextFieldTile(
              'Mark Categories',
              'e.g., sponsor,intro,outro',
              settings.sponsorblockMarkCategories,
              (value) => _updateSettings(
                settings.copyWith(sponsorblockMarkCategories: value),
              ),
            ),
          _buildSwitchTile(
            'Remove Sponsor Segments',
            'Cut out sponsor segments from video',
            settings.sponsorblockRemove,
            (value) =>
                _updateSettings(settings.copyWith(sponsorblockRemove: value)),
          ),
          if (settings.sponsorblockRemove)
            _buildTextFieldTile(
              'Remove Categories',
              'e.g., sponsor,selfpromo',
              settings.sponsorblockRemoveCategories,
              (value) => _updateSettings(
                settings.copyWith(sponsorblockRemoveCategories: value),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildAdvancedTab(YtDlpSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard('Engine', [
          const ListTile(
            leading: Icon(Icons.system_update_alt_rounded),
            title: Text('Official release channel'),
            subtitle: Text(
              'Nightly is recommended by yt-dlp for regular users. Stable '
              'changes less often; master follows every development build.',
            ),
          ),
          _buildDropdownTile(
            'Update Channel',
            settings.updateChannel,
            const ['stable', 'nightly', 'master'],
            (value) {
              if (value != null) {
                _updateSettings(settings.copyWith(updateChannel: value));
              }
            },
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.javascript_rounded),
              title: const Text('Android engine with QuickJS'),
              subtitle: Text(
                _androidEngineVersion == null
                    ? 'QuickJS is bundled for YouTube JavaScript challenges.'
                    : 'yt-dlp $_androidEngineVersion · QuickJS bundled',
              ),
              trailing: _updatingAndroidEngine
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Update now',
                      onPressed: () =>
                          _updateAndroidEngine(settings.updateChannel),
                      icon: const Icon(Icons.system_update_alt_rounded),
                    ),
            )
          else ...[
            _buildDropdownTile(
              'JavaScript Runtime',
              settings.jsRuntime,
              const ['auto', 'deno', 'node', 'quickjs', 'bun'],
              (value) {
                if (value != null) {
                  _updateSettings(settings.copyWith(jsRuntime: value));
                }
              },
            ),
            if (settings.jsRuntime != 'auto')
              _buildTextFieldTile(
                'Runtime Path (optional)',
                'Executable path or containing directory',
                settings.jsRuntimePath,
                (value) =>
                    _updateSettings(settings.copyWith(jsRuntimePath: value)),
              ),
          ],
          _buildSwitchTile(
            'Allow remote EJS components',
            'Opt in to fetching YouTube challenge scripts from the official '
                'yt-dlp-ejs GitHub releases when required.',
            settings.allowRemoteComponents,
            (value) => _updateSettings(
              settings.copyWith(allowRemoteComponents: value),
            ),
          ),
        ]),
        _buildSectionCard('Logging', [
          _buildSwitchTile(
            'Verbose Output',
            'Print detailed debugging information',
            settings.verbose,
            (value) => _updateSettings(settings.copyWith(verbose: value)),
          ),
          _buildSwitchTile(
            'Quiet Mode',
            'Suppress output messages',
            settings.quiet,
            (value) => _updateSettings(settings.copyWith(quiet: value)),
          ),
          _buildSwitchTile(
            'Ignore Errors',
            'Continue on download errors',
            settings.ignoreErrors,
            (value) => _updateSettings(settings.copyWith(ignoreErrors: value)),
          ),
        ]),
        _buildSectionCard('Rate Limiting', [
          _buildTextFieldTile(
            'Min Sleep Interval',
            'Minimum seconds to sleep between requests',
            settings.minSleepInterval,
            (value) =>
                _updateSettings(settings.copyWith(minSleepInterval: value)),
            validator: Validators.validateSleepInterval,
          ),
          _buildTextFieldTile(
            'Max Sleep Interval',
            'Maximum seconds to sleep between requests',
            settings.maxSleepInterval,
            (value) =>
                _updateSettings(settings.copyWith(maxSleepInterval: value)),
            validator: Validators.validateSleepInterval,
          ),
          _buildTextFieldTile(
            'Retry Sleep',
            'e.g., http:linear=1::2 or fragment:exp=1:20',
            settings.retrySleep,
            (value) => _updateSettings(settings.copyWith(retrySleep: value)),
          ),
          _buildTextFieldTile(
            'Sleep Between Requests',
            'Seconds between extraction requests',
            settings.sleepRequests,
            (value) => _updateSettings(settings.copyWith(sleepRequests: value)),
            validator: Validators.validateSleepInterval,
          ),
          _buildTextFieldTile(
            'Sleep Before Subtitles',
            'Seconds before each subtitle request',
            settings.sleepSubtitles,
            (value) =>
                _updateSettings(settings.copyWith(sleepSubtitles: value)),
            validator: Validators.validateSleepInterval,
          ),
        ]),
        _buildSectionCard('Extraction & Identity', [
          _buildTextFieldTile(
            'Extractor Arguments',
            'e.g., youtube:player_client=web,android',
            settings.extractorArgs,
            (value) => _updateSettings(settings.copyWith(extractorArgs: value)),
          ),
          _buildTextFieldTile(
            'Impersonate Target',
            'e.g., chrome or chrome-136:windows-10',
            settings.impersonateTarget,
            (value) =>
                _updateSettings(settings.copyWith(impersonateTarget: value)),
          ),
          if (!Platform.isAndroid)
            _buildTextFieldTile(
              'Cookies From Browser',
              'e.g., firefox or chrome:Default',
              settings.cookiesFromBrowser,
              (value) =>
                  _updateSettings(settings.copyWith(cookiesFromBrowser: value)),
            ),
        ]),
        _buildSectionCard('Archive & Live', [
          _buildTextFieldTile(
            'Download Archive',
            'Path to the archive file of previously downloaded IDs',
            settings.downloadArchive,
            (value) =>
                _updateSettings(settings.copyWith(downloadArchive: value)),
          ),
          _buildSwitchTile(
            'Break per input URL',
            'Reset break-on-existing and max-download counters per URL',
            settings.breakPerInput,
            (value) => _updateSettings(settings.copyWith(breakPerInput: value)),
          ),
          _buildSwitchTile(
            'Live from start',
            'Download livestreams from their beginning when supported',
            settings.liveFromStart,
            (value) => _updateSettings(settings.copyWith(liveFromStart: value)),
          ),
          _buildTextFieldTile(
            'Wait for scheduled video',
            'Polling interval in seconds, e.g., 60 or 60-300',
            settings.waitForVideo,
            (value) => _updateSettings(settings.copyWith(waitForVideo: value)),
          ),
        ]),
        _buildSectionCard('Advanced Options', [
          _buildTextFieldTile(
            'User Agent',
            'Custom user agent string',
            settings.userAgent,
            (value) => _updateSettings(settings.copyWith(userAgent: value)),
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.toInt()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldTile(
    String title,
    String hint,
    String value,
    ValueChanged<String> onChanged, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        validator: validator,
        onChanged: (newValue) {
          final error = validator?.call(newValue);
          if (error == null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
        initialValue: value,
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _updateSettings(YtDlpSettings newSettings) {
    ref.read(ytDlpSettingsProvider.notifier).updateSettings(newSettings);
  }

  Future<void> _loadAndroidEngineVersion() async {
    final version = await AndroidYtDlpService.instance.getVersion();
    if (mounted) setState(() => _androidEngineVersion = version);
  }

  Future<void> _updateAndroidEngine(String channel) async {
    setState(() => _updatingAndroidEngine = true);
    final updated = await AndroidYtDlpService.instance.updateYtDlpFromChannel(
      channel,
    );
    await _loadAndroidEngineVersion();
    if (!mounted) return;
    setState(() => _updatingAndroidEngine = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? 'Android yt-dlp updated from $channel'
              : 'Could not update yt-dlp; the bundled version is still available',
        ),
      ),
    );
  }

  Future<void> _showSavePresetDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Custom Preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Preset Name',
            hintText: 'My Custom Preset',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _saveCustomPreset(result);
    }
  }

  Future<void> _saveCustomPreset(String name) async {
    if (PresetsStorageService.instance.presetNameExists(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preset "$name" already exists')),
        );
      }
      return;
    }

    final settings = ref.read(ytDlpSettingsProvider);
    final preset = CustomPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      settings: settings.copyWith(preset: 'custom'),
      createdAt: DateTime.now(),
    );

    await PresetsStorageService.instance.addPreset(preset);

    setState(() {
      _hasUnsavedChanges = false;
      _originalSettings = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preset "$name" saved!')));
    }
  }
}

class _PresetButton extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
