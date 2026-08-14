// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_mode.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/cookie_provider.dart';
import '../../../shared/models/delete_preference.dart';
import '../../../services/logger/app_logger.dart';
import '../../../services/storage/settings_storage_service.dart';
import '../../../services/storage/presets_storage_service.dart';
import '../../../services/database/database_service.dart';
import '../domain/custom_preset.dart';
import '../widgets/settings_section.dart';
import '../widgets/download_path_settings.dart';
import '../widgets/ytdlp_settings.dart';
import '../widgets/ffmpeg_settings.dart';
import '../widgets/app_update_settings.dart';
import '../../../services/storage/settings_export_service.dart';
import '../../../services/storage/download_path_service.dart';
import '../../../services/storage/cookie_storage_service.dart';
import '../../../services/permissions/permission_service.dart';
import 'logs_viewer_page.dart';
import 'cookie_manager_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final logLevel = ref.watch(logLevelProvider);
    final deletePreference = ref.watch(deletePreferenceProvider);
    final youtubeAccount = ref.watch(cookieProvider).selectedCookie;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: const Text('Settings')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 600;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 28 : 16,
                  vertical: 16,
                ),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 42,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Make MBNDL yours',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Appearance, download engine, storage, '
                                  'presets, diagnostics, and backups.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Settings Section
                  SettingsSection(
                        title: 'App Settings',
                        icon: Icons.settings_outlined,
                        children: [
                          ListTile(
                            leading: Icon(
                              themeMode.icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Theme Mode'),
                            subtitle: Text(themeMode.displayName),
                            onTap: () =>
                                _showThemeDialog(context, ref, themeMode),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.palette_outlined,
                              color: _getThemeColorPreview(themeColor),
                            ),
                            title: const Text('Theme Color'),
                            subtitle: Text(
                              AppTheme.getThemeColorName(themeColor),
                            ),
                            onTap: () =>
                                _showThemeColorDialog(context, ref, themeColor),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.bug_report_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Log Level'),
                            subtitle: Text(_getLogLevelLabel(logLevel)),
                            onTap: () =>
                                _showLogLevelDialog(context, ref, logLevel),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Delete Behavior'),
                            subtitle: Text(deletePreference.displayName),
                            onTap: () => _showDeletePreferenceDialog(
                              context,
                              ref,
                              deletePreference,
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.description_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('View Logs'),
                            subtitle: const Text('View application logs'),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LogsViewerPage(),
                              ),
                            ),
                          ),
                          if (!Platform.isAndroid)
                            ListTile(
                              leading: Icon(
                                Icons.folder_open_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: const Text('Open Log Folder'),
                              subtitle: const Text(
                                'Open logs folder in explorer',
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              onTap: () => _openLogFolder(context),
                            ),
                          if (!Platform.isAndroid)
                            ListTile(
                              leading: Icon(
                                Icons.file_copy_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: const Text('Settings File Location'),
                              subtitle: Text(
                                SettingsStorageService.instance
                                        .getSettingsFilePath() ??
                                    'Not initialized',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                tooltip: 'Copy path',
                                onPressed: () => _copySettingsPath(context),
                              ),
                              onTap: () => _openSettingsFolder(context),
                            ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -0.1, end: 0, duration: 300.ms),

                  const SizedBox(height: 24),

                  SettingsSection(
                        title: 'App Updates',
                        icon: Icons.system_update_alt_rounded,
                        children: const [AppUpdateSettings()],
                      )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 300.ms)
                      .slideY(
                        begin: -0.1,
                        end: 0,
                        delay: 80.ms,
                        duration: 300.ms,
                      ),

                  const SizedBox(height: 24),

                  // Download Settings Section
                  SettingsSection(
                        title: 'Download Settings',
                        icon: Icons.download_rounded,
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.folder_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Download Folder'),
                            subtitle: const Text(
                              'Choose where downloads are saved',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => _navigateToSubPage(
                              context,
                              const DownloadPathSettings(),
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.settings_suggest_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('yt-dlp Settings'),
                            subtitle: const Text(
                              'Comprehensive yt-dlp flag configuration',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => context.push('/ytdlp-settings'),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.account_circle_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('YouTube Accounts'),
                            subtitle: Text(
                              youtubeAccount == null
                                  ? 'Anonymous mode · safest default'
                                  : '${youtubeAccount.name} is active',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => _navigateToSubPage(
                              context,
                              const CookieManagerPage(),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 300.ms)
                      .slideY(
                        begin: -0.1,
                        end: 0,
                        delay: 100.ms,
                        duration: 300.ms,
                      ),

                  // yt-dlp & FFmpeg - Desktop Only
                  if (!Platform.isAndroid && !Platform.isIOS) ...[
                    const SizedBox(height: 24),
                    // yt-dlp Section
                    SettingsSection(
                          key: const ValueKey('ytdlp_settings_section'),
                          title: 'yt-dlp Engine',
                          icon: Icons.dynamic_feed_outlined,
                          children: const [
                            YtDlpSettings(
                              key: ValueKey('ytdlp_settings_widget'),
                            ),
                          ],
                        )
                        .animate(key: const ValueKey('ytdlp_animation'))
                        .fadeIn(delay: 150.ms, duration: 300.ms)
                        .slideY(
                          begin: -0.1,
                          end: 0,
                          delay: 150.ms,
                          duration: 300.ms,
                        ),
                    const SizedBox(height: 24),
                    // FFmpeg Section
                    SettingsSection(
                          key: const ValueKey('ffmpeg_settings_section'),
                          title: 'FFmpeg',
                          icon: Icons.video_settings_outlined,
                          children: const [
                            FFmpegSettings(
                              key: ValueKey('ffmpeg_settings_widget'),
                            ),
                          ],
                        )
                        .animate(key: const ValueKey('ffmpeg_animation'))
                        .fadeIn(delay: 200.ms, duration: 300.ms)
                        .slideY(
                          begin: -0.1,
                          end: 0,
                          delay: 200.ms,
                          duration: 300.ms,
                        ),
                  ],

                  const SizedBox(height: 24),

                  // Backup & Export Section
                  SettingsSection(
                        title: 'Backup & Export',
                        icon: Icons.backup_outlined,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.save_alt_outlined),
                            title: const Text('Backup Presets'),
                            subtitle: const Text(
                              'Backup custom presets to file',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _backupPresets(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.restore_outlined),
                            title: const Text('Restore Presets'),
                            subtitle: const Text('Restore presets from backup'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _restorePresets(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.file_download_outlined),
                            title: const Text('Export Settings'),
                            subtitle: const Text('Save all settings to file'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _exportSettings(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: const Text('Export Logs'),
                            subtitle: const Text('Save app logs to file'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _exportLogs(context),
                          ),
                          ListTile(
                            leading: const Icon(Icons.upload_outlined),
                            title: const Text('Import Settings'),
                            subtitle: const Text('Restore settings from file'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _importSettings(context),
                          ),
                          if (!Platform.isAndroid)
                            ListTile(
                              leading: const Icon(Icons.folder_outlined),
                              title: const Text('Open Config Folder'),
                              subtitle: const Text('View MBNDL folder'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openConfigFolder(context),
                            ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 300.ms)
                      .slideY(
                        begin: -0.1,
                        end: 0,
                        delay: 250.ms,
                        duration: 300.ms,
                      ),

                  const SizedBox(height: 24),

                  // About Section
                  SettingsSection(
                        title: 'About',
                        icon: Icons.info_outlined,
                        children: [
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) => ListTile(
                              leading: const Icon(
                                Icons.app_settings_alt_outlined,
                              ),
                              title: const Text('Version'),
                              subtitle: Text(
                                snapshot.hasData
                                    ? '${snapshot.data!.version} '
                                          '(${snapshot.data!.buildNumber})'
                                    : 'Loading…',
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.code_outlined),
                            title: const Text('Open Source'),
                            subtitle: const Text('Built with Flutter & yt-dlp'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openGitHub(context),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 300.ms)
                      .slideY(
                        begin: -0.1,
                        end: 0,
                        delay: 200.ms,
                        duration: 300.ms,
                      ),

                  const SizedBox(height: 24),

                  // Reset App Section
                  SettingsSection(
                        title: 'Danger Zone',
                        icon: Icons.warning_amber_rounded,
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.restart_alt,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            title: Text(
                              'Reset App',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            subtitle: const Text(
                              'Clear all app data and restart',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onTap: () => _showResetAppDialog(context, ref),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 300.ms)
                      .slideY(
                        begin: -0.1,
                        end: 0,
                        delay: 250.ms,
                        duration: 300.ms,
                      ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getLogLevelLabel(LogLevel level) {
    return level.name.toUpperCase();
  }

  Color _getThemeColorPreview(AppThemeColor color) {
    const colorMap = {
      AppThemeColor.materialYou:
          Colors.blue, // Placeholder - will use system colors
      AppThemeColor.violet: Color(0xFF6750A4),
      AppThemeColor.blue: Color(0xFF0061A4),
      AppThemeColor.teal: Color(0xFF006A6A),
      AppThemeColor.green: Color(0xFF386A20),
      AppThemeColor.orange: Color(0xFF825500),
      AppThemeColor.pink: Color(0xFF984061),
      AppThemeColor.red: Color(0xFFBA1A1A),
      AppThemeColor.indigo: Color(0xFF3F51B5),
    };
    return colorMap[color]!;
  }

  void _showThemeColorDialog(
    BuildContext context,
    WidgetRef ref,
    AppThemeColor currentColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme Color'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SizedBox(
          width: 400,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: AppThemeColor.values.map((color) {
              final isSelected = color == currentColor;
              return Material(
                color: _getThemeColorPreview(color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    ref.read(themeColorProvider.notifier).setThemeColor(color);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _getThemeColorPreview(color)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color == AppThemeColor.materialYou
                                ? null
                                : _getThemeColorPreview(color),
                            gradient: color == AppThemeColor.materialYou
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6750A4),
                                      Color(0xFF0061A4),
                                      Color(0xFF006A6A),
                                      Color(0xFF386A20),
                                    ],
                                  )
                                : null,
                            shape: BoxShape.circle,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : (color == AppThemeColor.materialYou
                                    ? const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            AppTheme.getThemeColorName(color),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: AppThemeMode.values.map((mode) {
              final isSelected = mode == currentMode;
              final previewColor = mode.getPreviewColor(context);
              final previewIsDark =
                  ThemeData.estimateBrightnessForColor(previewColor) ==
                  Brightness.dark;
              final previewForeground = previewIsDark
                  ? Colors.white
                  : Colors.black87;

              return InkWell(
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Preview Content
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode.icon,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mode.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: previewForeground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                mode.description,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: previewForeground.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Selected Indicator
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogLevelDialog(
    BuildContext context,
    WidgetRef ref,
    LogLevel currentLevel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LogLevel.values.map((level) {
            return RadioListTile<LogLevel>(
              title: Text(level.name.toUpperCase()),
              value: level,
              groupValue: currentLevel,
              onChanged: (value) {
                if (value != null) {
                  ref.read(logLevelProvider.notifier).setLogLevel(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeletePreferenceDialog(
    BuildContext context,
    WidgetRef ref,
    DeletePreference currentPreference,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Behavior'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how downloads are deleted:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...DeletePreference.values.map((pref) {
              return RadioListTile<DeletePreference>(
                title: Text(pref.displayName),
                subtitle: Text(
                  pref.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: pref,
                groupValue: currentPreference,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(deletePreferenceProvider.notifier)
                        .setPreference(value);
                    Navigator.pop(context);
                  }
                },
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToSubPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _exportSettings(BuildContext context) async {
    try {
      // Check permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.instance
            .checkAndRequestPermission(context);
        if (!hasPermission) {
          return;
        }
      }

      final path = await SettingsExportService.instance.exportSettings();
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings exported successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      // Check permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.instance
            .checkAndRequestPermission(context);
        if (!hasPermission) {
          return;
        }
      }

      final path = await SettingsExportService.instance.exportLogs();
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs exported successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export logs: $e')));
      }
    }
  }

  Future<void> _importSettings(BuildContext context) async {
    try {
      // Check permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.instance
            .checkAndRequestPermission(context);
        if (!hasPermission) {
          return;
        }
      }

      final success = await SettingsExportService.instance.importSettings();
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings imported! Please restart app.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
      }
    }
  }

  Future<void> _openConfigFolder(BuildContext context) async {
    try {
      await SettingsExportService.instance.openConfigFolder();
    } catch (e) {
      if (context.mounted) {
        // On Android/iOS, show the path in a dialog instead of trying to open
        if (Platform.isAndroid || Platform.isIOS) {
          String? appData;
          try {
            if (Platform.isAndroid || Platform.isIOS) {
              final dir = await getApplicationDocumentsDirectory();
              appData = '${dir.path}${Platform.pathSeparator}MBNDownloader';
            }
          } catch (_) {}

          if (appData != null) {
            final pathStr = appData; // Create non-nullable copy
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Config Folder Location'),
                content: SelectableText(
                  pathStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: pathStr));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Path copied to clipboard'),
                          ),
                        );
                      }
                    },
                    child: const Text('Copy Path'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          } else {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to get folder path: $e')),
            );
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to open folder: $e')));
        }
      }
    }
  }

  Future<void> _openGitHub(BuildContext context) async {
    final url = Uri.parse('https://github.com/MBNpro-ir');
    try {
      final launched = await launchUrl(
        url,
        mode: Platform.isAndroid
            ? LaunchMode.externalNonBrowserApplication
            : LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback: try with platformDefault mode
        final fallbackLaunched = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );

        if (!fallbackLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open GitHub repository'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to open GitHub URL', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openLogFolder(BuildContext context) async {
    try {
      final logPath = await AppLogger.getLogFilePath();
      if (logPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log file not found'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final logFile = File(logPath);
      final logDir = logFile.parent;

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, show path in dialog instead of opening folder
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Log Folder Location'),
              content: SelectableText(
                logDir.path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: logDir.path));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Path copied to clipboard'),
                        ),
                      );
                    }
                  },
                  child: const Text('Copy Path'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        // On desktop, open the folder
        if (Platform.isWindows) {
          await Process.run('explorer', [logDir.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [logDir.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [logDir.path]);
        }
        AppLogger.info('Opened log folder: ${logDir.path}');
      }
    } catch (e) {
      AppLogger.error('Failed to open log folder', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open folder: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showResetAppDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('Reset App?'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All download history\n'
          '• All settings and preferences\n'
          '• All logs and cache\n'
          '• All saved data\n\n'
          'Downloaded files will NOT be deleted.\n\n'
          'The app will close automatically after reset.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetApp(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset App'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Resetting app...'),
            ],
          ),
        ),
      );

      AppLogger.info('Starting app reset...');

      // Close database connections
      try {
        await DatabaseService.instance.close();
        AppLogger.info('Database connections closed');
      } catch (e) {
        AppLogger.warning('Failed to close database', e);
      }

      // Secure storage is outside the ordinary settings directory on both
      // Android and Windows, so remove account secrets before deleting files.
      try {
        await CookieStorageService.instance.clearAll();
      } catch (e) {
        AppLogger.error('Failed to clear encrypted YouTube accounts', e);
      }

      if (Platform.isWindows) {
        // ========== Windows Reset ==========
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          final mbnDir = Directory(
            '$appData${Platform.pathSeparator}MBNDownloader',
          );

          if (await mbnDir.exists()) {
            try {
              // Delete entire MBNDownloader directory in APPDATA
              // This includes: settings.json, presets.json, yt-dlp.exe, ffmpeg/, logs/, mbn_downloader.db
              await mbnDir.delete(recursive: true);
              AppLogger.info('Deleted entire APPDATA\\MBNDownloader directory');
            } catch (e) {
              AppLogger.error('Failed to delete APPDATA directory', e);
            }
          }
        }

        // Delete Temp folder inside download directory (if exists)
        try {
          final settings = ref.read(ytDlpSettingsProvider);
          String downloadPath = settings.downloadPath;

          if (downloadPath.isEmpty) {
            downloadPath = await DownloadPathService.instance
                .getDefaultDownloadPath();
          }

          final tempDir = Directory(
            '$downloadPath${Platform.pathSeparator}Temp',
          );
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
            AppLogger.info('Deleted download Temp directory');
          }
        } catch (e) {
          AppLogger.error('Failed to delete Temp directory', e);
        }
      } else if (Platform.isAndroid) {
        // ========== Android Reset ==========

        // 1. Delete Application Documents Directory (settings, logs)
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final mbnDir = Directory(
            '${appDir.path}${Platform.pathSeparator}MBNDownloader',
          );
          if (await mbnDir.exists()) {
            await mbnDir.delete(recursive: true);
            AppLogger.info('Deleted app documents directory');
          }

          // Delete settings.json and presets.json in root
          final settingsFile = File(
            '${appDir.path}${Platform.pathSeparator}settings.json',
          );
          if (await settingsFile.exists()) {
            await settingsFile.delete();
            AppLogger.info('Deleted settings.json');
          }

          final presetsFile = File(
            '${appDir.path}${Platform.pathSeparator}presets.json',
          );
          if (await presetsFile.exists()) {
            await presetsFile.delete();
            AppLogger.info('Deleted presets.json');
          }
        } catch (e) {
          AppLogger.error('Failed to delete app documents', e);
        }

        // 2. Delete cookie metadata (encrypted secrets were cleared above).
        try {
          final appSupportDir = await getApplicationSupportDirectory();
          final cookiesDir = Directory(
            '${appSupportDir.path}${Platform.pathSeparator}cookies',
          );
          if (await cookiesDir.exists()) {
            await cookiesDir.delete(recursive: true);
            AppLogger.info('Deleted cookies directory');
          }
        } catch (e) {
          AppLogger.error('Failed to delete cookies', e);
        }

        // 3. Delete Database
        try {
          final dbPath = await getDatabasesPath();
          final dbFile = File(join(dbPath, 'mbn_downloader.db'));
          final dbShmFile = File(join(dbPath, 'mbn_downloader.db-shm'));
          final dbWalFile = File(join(dbPath, 'mbn_downloader.db-wal'));

          if (await dbFile.exists()) await dbFile.delete();
          if (await dbShmFile.exists()) await dbShmFile.delete();
          if (await dbWalFile.exists()) await dbWalFile.delete();

          AppLogger.info('Deleted database files');
        } catch (e) {
          AppLogger.error('Failed to delete database', e);
        }

        // 4. Delete Application Cache
        try {
          final cacheDir = await getApplicationCacheDirectory();
          if (await cacheDir.exists()) {
            await cacheDir.delete(recursive: true);
            await cacheDir.create();
            AppLogger.info('Cache cleared');
          }
        } catch (e) {
          AppLogger.error('Failed to delete cache', e);
        }

        // 5. Delete Temp folder inside download directory
        try {
          final settings = ref.read(ytDlpSettingsProvider);
          String downloadPath = settings.downloadPath;

          if (downloadPath.isEmpty) {
            downloadPath = await DownloadPathService.instance
                .getDefaultDownloadPath();
          }

          final tempDir = Directory(
            '$downloadPath${Platform.pathSeparator}Temp',
          );
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
            AppLogger.info('Deleted download Temp directory');
          }
        } catch (e) {
          AppLogger.error('Failed to delete Temp directory', e);
        }

        // 6. Clear SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          AppLogger.info('SharedPreferences cleared');
        } catch (e) {
          AppLogger.error('Failed to clear SharedPreferences', e);
        }
      }

      AppLogger.info('App reset completed successfully');

      // Close the app
      if (Platform.isAndroid || Platform.isIOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        exit(0);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reset app', e, stackTrace);
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset app: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copySettingsPath(BuildContext context) async {
    try {
      final settingsPath = SettingsStorageService.instance
          .getSettingsFilePath();
      if (settingsPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings file not initialized'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: settingsPath));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings path copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      AppLogger.debug('Settings path copied: $settingsPath');
    } catch (e) {
      AppLogger.error('Failed to copy settings path', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openSettingsFolder(BuildContext context) async {
    try {
      final settingsPath = SettingsStorageService.instance
          .getSettingsFilePath();
      if (settingsPath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings file not initialized'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final settingsFile = File(settingsPath);
      final settingsDir = settingsFile.parent;

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, show path in dialog instead of opening folder
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Settings Folder Location'),
              content: SelectableText(
                settingsDir.path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: settingsDir.path),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Path copied to clipboard'),
                        ),
                      );
                    }
                  },
                  child: const Text('Copy Path'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        // On desktop, open the folder
        if (Platform.isWindows) {
          // Open folder in Windows Explorer and select the file
          await Process.run('explorer', ['/select,', settingsPath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', ['-R', settingsPath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [settingsDir.path]);
        }
        AppLogger.info('Opened settings folder: ${settingsDir.path}');
      }
    } catch (e) {
      AppLogger.error('Failed to open settings folder', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open folder: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _backupPresets(BuildContext context) async {
    try {
      // Check permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.instance
            .checkAndRequestPermission(context);
        if (!hasPermission) {
          return;
        }
      }

      // Import file_picker at the top of file
      final customPresets = PresetsStorageService.instance.getCustomPresets();

      if (customPresets.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No custom presets to backup')),
          );
        }
        return;
      }

      // Show selection dialog
      if (!context.mounted) return;
      final selectedIds = await showDialog<List<String>>(
        context: context,
        builder: (context) => _PresetSelectionDialog(presets: customPresets),
      );

      if (selectedIds == null || selectedIds.isEmpty) {
        return;
      }

      // Get save location
      final backupJson = PresetsStorageService.instance.createBackupJson(
        selectedIds,
      );
      if (backupJson == null) return;
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Preset Backup',
        fileName:
            'mbn_presets_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(backupJson)),
      );

      if (savePath == null) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backed up ${selectedIds.length} presets successfully',
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to backup presets', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to backup: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _restorePresets(BuildContext context) async {
    try {
      // Check permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.instance
            .checkAndRequestPermission(context);
        if (!hasPermission) {
          return;
        }
      }

      // Pick backup file
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Preset Backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;

      // Ask if replace existing
      if (!context.mounted) return;
      final replaceExisting = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Presets'),
          content: const Text('Replace existing presets with the same ID?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Both'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (replaceExisting == null) {
        return;
      }

      final restoredCount = await PresetsStorageService.instance.restorePresets(
        filePath,
        replaceExisting: replaceExisting,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $restoredCount presets successfully'),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to restore presets', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: ${e.toString()}')),
        );
      }
    }
  }
}

class _PresetSelectionDialog extends StatefulWidget {
  final List<CustomPreset> presets;

  const _PresetSelectionDialog({required this.presets});

  @override
  State<_PresetSelectionDialog> createState() => _PresetSelectionDialogState();
}

class _PresetSelectionDialogState extends State<_PresetSelectionDialog> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Presets to Backup'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Select All'),
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  if (_selectAll) {
                    _selectedIds.addAll(widget.presets.map((p) => p.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.presets.length,
                itemBuilder: (context, index) {
                  final preset = widget.presets[index];
                  return CheckboxListTile(
                    title: Text(preset.name),
                    value: _selectedIds.contains(preset.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(preset.id);
                        } else {
                          _selectedIds.remove(preset.id);
                        }
                        _selectAll =
                            _selectedIds.length == widget.presets.length;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds.toList()),
          child: Text('Backup (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
