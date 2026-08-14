import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/settings_provider.dart';

class AdvancedSettings extends ConsumerWidget {
  const AdvancedSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ytDlpSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Embed Thumbnail'),
                  subtitle: const Text('Add thumbnail to video metadata'),
                  value: settings.embedThumbnail,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(embedThumbnail: value),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Embed Metadata'),
                  subtitle: const Text('Add title, artist, etc. to file'),
                  value: settings.embedMetadata,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(embedMetadata: value),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Keep Fragments'),
                  subtitle: const Text('Keep downloaded fragments'),
                  value: settings.keepFragments,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(keepFragments: value),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Overwrite Files'),
                  subtitle: const Text('Overwrite existing files'),
                  value: settings.overwriteFiles,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(overwriteFiles: value),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Verbose Logging'),
                  subtitle: const Text('Enable detailed logs'),
                  value: settings.verbose,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(settings.copyWith(verbose: value));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Output Template'),
                  subtitle: Text(settings.outputTemplate),
                  onTap: () => _showOutputTemplateDialog(
                    context,
                    ref,
                    settings.outputTemplate,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('User Agent'),
                  subtitle: Text(
                    settings.userAgent.isEmpty ? 'Default' : settings.userAgent,
                  ),
                  onTap: () =>
                      _showUserAgentDialog(context, ref, settings.userAgent),
                ),
              ],
            ),
          ),
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
                        'Output Template',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Available fields:\n'
                    '• %(title)s - Video title\n'
                    '• %(ext)s - File extension\n'
                    '• %(id)s - Video ID\n'
                    '• %(uploader)s - Uploader name\n'
                    '• %(upload_date)s - Upload date\n\n'
                    'Default: %(title)s.%(ext)s',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOutputTemplateDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Output Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Template',
                hintText: '%(title)s.%(ext)s',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Use yt-dlp output template syntax\nExample: %(title)s.%(ext)s',
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
                    settings.copyWith(outputTemplate: controller.text.trim()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUserAgentDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'User Agent',
                hintText: 'Leave empty for default',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Custom User-Agent string\nLeave empty to use default',
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
                    settings.copyWith(userAgent: controller.text.trim()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
