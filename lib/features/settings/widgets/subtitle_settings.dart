// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/settings_provider.dart';

class SubtitleSettings extends ConsumerWidget {
  const SubtitleSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ytDlpSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subtitles & Thumbnails')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thumbnail Settings
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Thumbnail'),
                  subtitle: const Text('Download and embed thumbnail'),
                  secondary: const Icon(Icons.image_outlined),
                  value: settings.embedThumbnail,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(embedThumbnail: value),
                        );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle Settings
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Download Subtitles'),
                  subtitle: const Text('Download available subtitles'),
                  secondary: const Icon(Icons.subtitles_outlined),
                  value: settings.downloadSubtitles,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(downloadSubtitles: value),
                        );
                  },
                ),
                if (settings.downloadSubtitles) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Auto-generated Subtitles'),
                    subtitle: const Text('Include auto-generated subtitles'),
                    value: settings.autoSubtitles,
                    onChanged: (value) {
                      ref
                          .read(ytDlpSettingsProvider.notifier)
                          .updateSettings(
                            settings.copyWith(autoSubtitles: value),
                          );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Subtitle Languages'),
                    subtitle: Text(settings.subtitleLanguages),
                    onTap: () => _showLanguagesDialog(
                      context,
                      ref,
                      settings.subtitleLanguages,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Subtitle Format'),
                    subtitle: Text(settings.subtitleFormat.toUpperCase()),
                    onTap: () => _showFormatDialog(
                      context,
                      ref,
                      settings.subtitleFormat,
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Embed Subtitles'),
                    subtitle: const Text('Embed subtitles in video file'),
                    value: settings.embedSubtitles,
                    onChanged: (value) {
                      ref
                          .read(ytDlpSettingsProvider.notifier)
                          .updateSettings(
                            settings.copyWith(embedSubtitles: value),
                          );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (settings.downloadSubtitles) ...[
            const SizedBox(height: 16),
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
                          'Language Codes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use comma-separated language codes:\n'
                      '• en - English\n'
                      '• fa - Persian\n'
                      '• ar - Arabic\n'
                      '• es - Spanish\n'
                      'Example: en,fa,ar',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLanguagesDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subtitle Languages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Language Codes',
                hintText: 'en,fa,ar',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter comma-separated language codes\nExample: en,fa,ar',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final settings = ref.read(ytDlpSettingsProvider);
              ref
                  .read(ytDlpSettingsProvider.notifier)
                  .updateSettings(
                    settings.copyWith(
                      subtitleLanguages: controller.text.trim(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFormatDialog(BuildContext context, WidgetRef ref, String current) {
    final formats = ['srt', 'vtt', 'ass'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subtitle Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formats.map((format) {
            return RadioListTile<String>(
              title: Text(format.toUpperCase()),
              value: format,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  final settings = ref.read(ytDlpSettingsProvider);
                  ref
                      .read(ytDlpSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(subtitleFormat: value));
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
