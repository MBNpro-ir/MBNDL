import 'package:flutter/material.dart';
import '../../../services/downloader/ffmpeg_manager.dart';
import '../../../services/logger/app_logger.dart';
import '../../../services/downloader/download_error_mapper.dart';

class FFmpegSettings extends StatefulWidget {
  const FFmpegSettings({super.key});

  @override
  State<FFmpegSettings> createState() => _FFmpegSettingsState();
}

class _FFmpegSettingsState extends State<FFmpegSettings>
    with AutomaticKeepAliveClientMixin {
  String? _currentVersion;
  String? _latestVersion;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final current = await FFmpegManager.instance.getCurrentVersion();
      final latest = await FFmpegManager.instance.getLatestVersion();

      if (mounted) {
        setState(() {
          _currentVersion = current;
          _latestVersion = latest;
          _isChecking = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load FFmpeg version info', e);
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final latest = await FFmpegManager.instance.getLatestVersion(
        forceCheck: true,
      );
      final current = await FFmpegManager.instance.getCurrentVersion();

      if (mounted) {
        setState(() {
          _currentVersion = current;
          _latestVersion = latest;
          _isChecking = false;
        });

        if (current != null && latest != null && current == latest) {
          _showSnackBar('FFmpeg is up to date!');
        } else if (latest != null) {
          _showSnackBar('Update available: $latest');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        _showSnackBar('Failed to check for updates', isError: true);
      }
    }
  }

  Future<void> _downloadUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
    });

    try {
      final success = await FFmpegManager.instance.downloadAndInstall(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _statusMessage = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        if (success) {
          _showSnackBar('FFmpeg updated successfully!');
          await _loadVersionInfo();
        } else {
          _showSnackBar('Failed to update FFmpeg', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        _showSnackBar(DownloadErrorMapper.from(e).displayText, isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final bool isInstalled = _currentVersion != null;
    final bool hasUpdate =
        isInstalled &&
        _latestVersion != null &&
        _currentVersion != _latestVersion;

    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.video_library_outlined,
            color: isInstalled ? Colors.green : Colors.orange,
          ),
          title: const Text('FFmpeg'),
          subtitle: Text(
            isInstalled ? 'Installed: $_currentVersion' : 'Not installed',
          ),
        ),

        if (_latestVersion != null)
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: const Text('Latest Version'),
            subtitle: Text(_latestVersion!),
            trailing: hasUpdate
                ? Chip(
                    label: const Text('Update Available'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),

        const Divider(),

        if (_isDownloading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloading required FFmpeg tools',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_downloadProgress.toStringAsFixed(0)}%',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress / 100,
                            minHeight: 6,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Check for Updates'),
            enabled: !_isChecking,
            onTap: _checkForUpdates,
            trailing: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
          ),

          if (hasUpdate || !isInstalled)
            ListTile(
              leading: Icon(hasUpdate ? Icons.system_update : Icons.download),
              title: Text(hasUpdate ? 'Download Update' : 'Download FFmpeg'),
              subtitle: Text(
                hasUpdate
                    ? 'Update to $_latestVersion (FFmpeg + FFprobe only)'
                    : 'Download FFmpeg + FFprobe only',
              ),
              onTap: _downloadUpdate,
              trailing: const Icon(Icons.chevron_right),
            ),

          // Re-download option for installed FFmpeg
          if (isInstalled && !hasUpdate)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Re-download FFmpeg'),
              subtitle: const Text('Re-download FFmpeg + FFprobe only'),
              onTap: _downloadUpdate,
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
      ],
    );
  }
}
