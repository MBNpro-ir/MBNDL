import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/app_notification.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/utils/validators.dart';
import '../../../services/storage/presets_storage_service.dart';
import '../../../services/downloader/android_ytdlp_service.dart';
import '../domain/yt_dlp_settings.dart';
import '../domain/custom_preset.dart';
import '../widgets/quick_preset_selector.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
          if (_hasUnsavedChanges)
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
            Tab(text: 'Connection'),
            Tab(text: 'Captions'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPresetsTab(settings),
              _buildDownloadTab(settings),
              _buildSubtitlesTab(settings),
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
        QuickPresetSelector(
          onPresetApplied: () {
            setState(() {
              _hasUnsavedChanges = false;
              _originalSettings = null;
            });
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CustomPreset>>(
          future: Future.value(
            PresetsStorageService.instance.getCustomPresets(),
          ),
          builder: (context, snapshot) {
            final customPresets = snapshot.data ?? [];
            if (customPresets.isEmpty) return const SizedBox.shrink();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom presets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final preset in customPresets)
                          SizedBox(
                            width: 340,
                            child: _PresetButton(
                              title: preset.name,
                              description: 'Your saved transport configuration',
                              icon: Icons.star_rounded,
                              isSelected: settings.preset == preset.id,
                              onTap: () {
                                ref
                                    .read(ytDlpSettingsProvider.notifier)
                                    .applyTransportPreset(
                                      name: preset.id,
                                      preset: preset.settings,
                                    );
                                setState(() {
                                  _hasUnsavedChanges = false;
                                  _originalSettings = null;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Card.filled(
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Presets tune connection and retry behavior only. Gentle '
                    'YouTube reduces request frequency, but it cannot prevent '
                    'rate limits or account restrictions.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadTab(YtDlpSettings settings) {
    return _buildResponsiveTab([
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
          (value) => _updateSettings(settings.copyWith(retries: value.toInt())),
        ),
        _buildSliderTile(
          'Extractor Retries',
          settings.extractorRetries.toDouble(),
          0,
          20,
          (value) => _updateSettings(
            settings.copyWith(extractorRetries: value.toInt()),
          ),
        ),
        _buildSwitchTile(
          'Verify selected formats',
          'Ask yt-dlp to check that selected media URLs are downloadable',
          settings.checkFormats,
          (value) => _updateSettings(settings.copyWith(checkFormats: value)),
        ),
        if (Platform.isAndroid)
          _buildSwitchTile(
            'Use Android aria2c engine',
            'Optional external downloader bundled in the Android app',
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
          (value) =>
              _updateSettings(settings.copyWith(socketTimeout: value.toInt())),
        ),
        _buildSwitchTile(
          'Force IPv4',
          'Use IPv4 for all requests',
          settings.forceIpv4,
          (value) => _updateSettings(
            settings.copyWith(forceIpv4: value, forceIpv6: false),
          ),
        ),
        _buildSwitchTile(
          'Force IPv6',
          'Use IPv6 for all requests',
          settings.forceIpv6,
          (value) => _updateSettings(
            settings.copyWith(forceIpv6: value, forceIpv4: false),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildSubtitlesTab(YtDlpSettings settings) {
    return _buildResponsiveTab([
      _buildSectionCard('Caption preferences', [
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
          (value) => _updateSettings(settings.copyWith(subtitleFormat: value!)),
        ),
      ]),
    ]);
  }

  Widget _buildAdvancedTab(YtDlpSettings settings) {
    return _buildResponsiveTab([
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
          (value) =>
              _updateSettings(settings.copyWith(allowRemoteComponents: value)),
        ),
      ]),
      _buildSectionCard('Logging', [
        _buildSwitchTile(
          'Verbose Output',
          'Print detailed debugging information',
          settings.verbose,
          (value) => _updateSettings(settings.copyWith(verbose: value)),
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
          (value) => _updateSettings(settings.copyWith(sleepSubtitles: value)),
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
        if (settings.impersonateTarget.isNotEmpty)
          const ListTile(
            leading: Icon(Icons.warning_amber_rounded),
            title: Text('Use impersonation only when a site requires it'),
            subtitle: Text(
              'yt-dlp warns that forcing a target may reduce download speed '
              'or stability. Clear the field to return to automatic behavior.',
            ),
          ),
      ]),
      _buildSectionCard('Live streams & scheduled media', [
        _buildSwitchTile(
          'Download live stream from the start',
          'Experimental yt-dlp mode for supported live sites',
          settings.liveFromStart,
          (value) => _updateSettings(settings.copyWith(liveFromStart: value)),
        ),
        _buildSwitchTile(
          'Use MPEG-TS for HLS',
          'Allows interrupted live downloads to keep playable fragments',
          settings.hlsUseMpegTs,
          (value) => _updateSettings(settings.copyWith(hlsUseMpegTs: value)),
        ),
        _buildTextFieldTile(
          'Wait for scheduled video',
          'Seconds or range, for example 60 or 30-120',
          settings.waitForVideo,
          (value) => _updateSettings(settings.copyWith(waitForVideo: value)),
          validator: Validators.validateSleepInterval,
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
    ]);
  }

  Widget _buildResponsiveTab(List<Widget> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 920;
        const gap = 16.0;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 32 - gap) / 2
            : constraints.maxWidth - 32;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final section in sections)
                  SizedBox(width: itemWidth, child: section),
              ],
            ),
          ],
        );
      },
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
    AppNotificationCenter.show(
      context,
      kind: updated ? AppNotificationKind.success : AppNotificationKind.warning,
      title: 'Android yt-dlp',
      message: updated
          ? 'Updated from the $channel channel.'
          : 'The update failed; the bundled version is still available.',
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
        AppNotificationCenter.show(
          context,
          kind: AppNotificationKind.warning,
          title: 'Preset already exists',
          message: 'Preset "$name" already exists.',
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
      AppNotificationCenter.show(
        context,
        kind: AppNotificationKind.success,
        title: 'Preset saved',
        message: 'Preset "$name" is ready to use.',
      );
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
