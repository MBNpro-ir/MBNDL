import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/floating_navigation_insets.dart';
import '../../../services/logger/app_logger.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../shared/providers/settings_provider.dart';

class DownloadPathSettings extends ConsumerStatefulWidget {
  const DownloadPathSettings({super.key});

  @override
  ConsumerState<DownloadPathSettings> createState() =>
      _DownloadPathSettingsState();
}

class _DownloadPathSettingsState extends ConsumerState<DownloadPathSettings> {
  String? _defaultPath;
  AndroidDownloadStorageStatus? _androidStatus;

  @override
  void initState() {
    super.initState();
    _loadDefaultPath();
  }

  Future<void> _loadDefaultPath() async {
    final value = await DownloadPathService.instance.getDefaultDownloadPath();
    final status = Platform.isAndroid
        ? await DownloadPathService.instance.verifyAndroidDownloadStorage()
        : null;
    if (mounted) {
      setState(() {
        _defaultPath = value.isEmpty ? status?.workingPath ?? '' : value;
        _androidStatus = status;
      });
    }
  }

  Future<void> _selectDownloadPath() async {
    if (Platform.isAndroid) return;
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select download folder',
        lockParentWindow: true,
      );
      if (result == null) return;

      await Directory(result).create(recursive: true);
      final current = ref.read(ytDlpSettingsProvider);
      await ref
          .read(ytDlpSettingsProvider.notifier)
          .updateSettings(current.copyWith(downloadPath: result));
      _showMessage('Download folder updated');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to select download folder', error, stackTrace);
      _showMessage('Could not change the download folder', isError: true);
    }
  }

  Future<void> _resetToDefault() async {
    final current = ref.read(ytDlpSettingsProvider);
    await ref
        .read(ytDlpSettingsProvider.notifier)
        .updateSettings(current.copyWith(downloadPath: ''));
    _showMessage('Default download location restored');
  }

  Future<void> _openDownloadFolder(String path) async {
    final target = path.isEmpty ? _defaultPath ?? '' : path;
    if (target.isEmpty) return;
    final opened = await DownloadPathService.instance.openDownloadLocation(
      target,
    );
    if (!opened) {
      _showMessage('Could not open the download location', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(ytDlpSettingsProvider);
    final actualPath = settings.downloadPath.isEmpty
        ? (_defaultPath?.isNotEmpty == true
              ? _defaultPath!
              : 'Working folder unavailable')
        : settings.downloadPath;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Download location')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + floatingNavigationScrollClearance(context),
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Platform.isAndroid
                        ? Icons.download_for_offline_rounded
                        : Icons.folder_rounded,
                    size: 42,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Platform.isAndroid ? 'Downloads / MBNDL' : 'Current folder',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'Completed files are published through Android '
                              'MediaStore, so they remain visible in your Files '
                              'app without broad storage access.'
                        : actualPath,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _androidStatus?.ready == true
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _androidStatus?.ready == true
                              ? colorScheme.primary
                              : colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _androidStatus?.message ??
                                'Checking Android storage…',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Check again',
                          onPressed: _loadDefaultPath,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Private working folder'),
                      subtitle: const Text(
                        'Temporary and resumable download data',
                      ),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: SelectableText(
                            actualPath,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          trailing: IconButton(
                            tooltip: 'Copy path',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: actualPath),
                              );
                              _showMessage('Path copied');
                            },
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (!Platform.isAndroid) ...[
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('Choose another folder'),
                    subtitle: const Text('Use a custom desktop location'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _selectDownloadPath,
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Open downloads'),
                  subtitle: Text(
                    Platform.isAndroid
                        ? 'Downloads/MBNDL · verified by MediaStore'
                        : actualPath,
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _openDownloadFolder(settings.downloadPath),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore default'),
                  subtitle: Text(_defaultPath ?? 'Loading…'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _defaultPath == null ? null : _resetToDefault,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Platform.isAndroid
                          ? 'Android keeps an app-owned working copy for '
                                'resume/history and publishes completed media to '
                                'Downloads/MBNDL. The published copy '
                                'remains after uninstalling the app.'
                          : 'Partial files are kept in a Temp folder inside '
                                'this location. Changing the folder does not move '
                                'existing downloads.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
