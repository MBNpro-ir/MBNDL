// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/settings_provider.dart';

class DownloadSettings extends ConsumerWidget {
  const DownloadSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ytDlpSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Download Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Concurrent Fragments'),
                  subtitle: Text('${settings.concurrentFragments} thread(s)'),
                  onTap: () => _showFragmentsDialog(
                    context,
                    ref,
                    settings.concurrentFragments,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Retries'),
                  subtitle: Text('${settings.retries} attempts'),
                  onTap: () =>
                      _showRetriesDialog(context, ref, settings.retries),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Rate Limit'),
                  subtitle: Text(
                    settings.rateLimit.isEmpty
                        ? 'Unlimited'
                        : settings.rateLimit,
                  ),
                  onTap: () =>
                      _showRateLimitDialog(context, ref, settings.rateLimit),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Use aria2c'),
                  subtitle: const Text(
                    'Download with aria2c (faster with 16 connections)',
                  ),
                  value: settings.useAria2c,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(settings.copyWith(useAria2c: value));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Download Playlist'),
                  subtitle: const Text('Download all videos in playlist'),
                  value: settings.downloadPlaylist,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(downloadPlaylist: value),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Force IPv4'),
                  value: settings.forceIpv4,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(forceIpv4: value, forceIpv6: false),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Force IPv6'),
                  value: settings.forceIpv6,
                  onChanged: (value) {
                    ref
                        .read(ytDlpSettingsProvider.notifier)
                        .updateSettings(
                          settings.copyWith(forceIpv6: value, forceIpv4: false),
                        );
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
                  title: const Text('Proxy'),
                  subtitle: Text(
                    settings.proxy.isEmpty ? 'No proxy' : settings.proxy,
                  ),
                  onTap: () => _showProxyDialog(context, ref, settings.proxy),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Socket Timeout'),
                  subtitle: Text('${settings.socketTimeout} seconds'),
                  onTap: () =>
                      _showTimeoutDialog(context, ref, settings.socketTimeout),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFragmentsDialog(BuildContext context, WidgetRef ref, int current) {
    final fragments = [1, 2, 4, 8, 16];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concurrent Fragments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fragments.map((n) {
            return RadioListTile<int>(
              title: Text('$n thread${n > 1 ? 's' : ''}'),
              value: n,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  final settings = ref.read(ytDlpSettingsProvider);
                  ref
                      .read(ytDlpSettingsProvider.notifier)
                      .updateSettings(
                        settings.copyWith(concurrentFragments: value),
                      );
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showRetriesDialog(BuildContext context, WidgetRef ref, int current) {
    final retries = [3, 5, 10, 20, 50];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry Attempts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: retries.map((n) {
            return RadioListTile<int>(
              title: Text('$n attempts'),
              value: n,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  final settings = ref.read(ytDlpSettingsProvider);
                  ref
                      .read(ytDlpSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(retries: value));
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showRateLimitDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rate Limit',
                hintText: 'e.g., 1M, 500K (empty for unlimited)',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Examples: 1M (1 MB/s), 500K (500 KB/s)\nLeave empty for unlimited',
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
                    settings.copyWith(rateLimit: controller.text.trim()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProxyDialog(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proxy Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Proxy URL',
                hintText: 'http://proxy.example.com:8080',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Example: http://proxy.example.com:8080\nLeave empty to disable',
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
                    settings.copyWith(proxy: controller.text.trim()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog(BuildContext context, WidgetRef ref, int current) {
    final timeouts = [10, 20, 30, 60, 120];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Socket Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timeouts.map((n) {
            return RadioListTile<int>(
              title: Text('$n seconds'),
              value: n,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  final settings = ref.read(ytDlpSettingsProvider);
                  ref
                      .read(ytDlpSettingsProvider.notifier)
                      .updateSettings(settings.copyWith(socketTimeout: value));
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
