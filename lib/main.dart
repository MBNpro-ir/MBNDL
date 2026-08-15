import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'core/notifications/app_notification.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/app_appearance.dart';
import 'features/permissions/permission_request_page.dart';
import 'features/settings/presentation/cookie_manager_page.dart';
import 'services/database/database_service.dart';
import 'services/downloader/download_service.dart';
import 'services/logger/app_logger.dart';
import 'services/permissions/permission_service.dart';
import 'services/storage/cookie_storage_service.dart';
import 'services/storage/settings_storage_service.dart';
import 'services/storage/presets_storage_service.dart';
import 'services/storage/storage_service.dart';
import 'shared/models/windows_close_behavior.dart';
import 'shared/models/download_item.dart';
import 'shared/providers/settings_provider.dart';
import 'shared/providers/app_update_provider.dart';
import 'shared/providers/cookie_provider.dart';
import 'shared/providers/downloads_provider.dart';
import 'shared/providers/youtube_auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1120, 760),
      minimumSize: Size(360, 600),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'MBNDL',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await AppLogger.initialize();
  await StorageService.initialize();
  await SettingsStorageService.initialize();
  await PresetsStorageService.instance.initialize();
  await CookieStorageService.instance.initialize();
  await DatabaseService.initialize();
  await DatabaseService.instance.database;

  runApp(const ProviderScope(child: MBNDownloaderApp()));

  // Tool extraction can take a couple of seconds on first Android launch.
  // Keep it off the critical path so the startup surface renders immediately.
  // Windows initialization installs the packaged tools and is owned by the
  // startup surface below. Other platforms keep their native initialization
  // off the first-render path.
  if (!Platform.isWindows) {
    unawaited(
      DownloadService.instance.initialize().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.error(
          'Download service initialization was deferred',
          error,
          stackTrace,
        );
      }),
    );
  }
}

enum _StartupPhase { checking, permissions, ready }

class MBNDownloaderApp extends ConsumerStatefulWidget {
  const MBNDownloaderApp({super.key, this.skipStartupChecks = false});

  /// Allows focused widget tests to render the router without touching native
  /// channels or the desktop tool installation flow.
  final bool skipStartupChecks;

  @override
  ConsumerState<MBNDownloaderApp> createState() => _MBNDownloaderAppState();
}

class _MBNDownloaderAppState extends ConsumerState<MBNDownloaderApp>
    with WindowListener, TrayListener {
  late _StartupPhase _phase;
  bool _closePromptVisible = false;
  bool _isQuitting = false;
  bool _appUpdaterStarted = false;
  String? _promptedUpdateVersion;
  bool _youtubeAuthPromptVisible = false;

  @override
  void initState() {
    super.initState();
    _phase = widget.skipStartupChecks
        ? _StartupPhase.ready
        : _StartupPhase.checking;
    if (!widget.skipStartupChecks) _checkSetup();
    if (!widget.skipStartupChecks && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeWindowsShell());
      });
    }
  }

  Future<void> _initializeWindowsShell() async {
    try {
      windowManager.addListener(this);
      trayManager.addListener(this);
      await windowManager.setPreventClose(true);
      await trayManager.setIcon(_resolveTrayIconPath());
      await trayManager.setToolTip('MBNDL');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Open'),
            MenuItem.separator(),
            MenuItem(key: 'close', label: 'Close'),
          ],
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Windows tray initialization failed', error, stackTrace);
    }
  }

  String _resolveTrayIconPath() {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final packaged =
        '$executableDirectory${Platform.pathSeparator}data${Platform.pathSeparator}tools${Platform.pathSeparator}icon.ico';
    if (File(packaged).existsSync()) return packaged;
    return '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}icon.ico';
  }

  Future<void> _restoreWindowsWindow() async {
    await windowManager.setSkipTaskbar(false);
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindowsWindow() async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
  }

  Future<void> _quitWindowsApp() async {
    if (_isQuitting) return;
    _isQuitting = true;
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowClose() async {
    if (!Platform.isWindows || _isQuitting || _closePromptVisible) return;
    final closeBehavior = ref.read(windowsCloseBehaviorProvider);
    if (closeBehavior == WindowsCloseBehavior.minimizeToTray) {
      await _hideWindowsWindow();
      return;
    }
    if (closeBehavior == WindowsCloseBehavior.exit) {
      await _quitWindowsApp();
      return;
    }

    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) {
      await _hideWindowsWindow();
      return;
    }

    _closePromptVisible = true;
    final decision = await showDialog<_WindowsCloseDecision>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) {
        var rememberSelection = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: const Icon(Icons.power_settings_new_rounded),
            title: const Text('Close MBNDL?'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keep downloads running in the system tray, exit the app '
                    'completely, or cancel and return to MBNDL.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: rememberSelection,
                    title: const Text('Remember this selection'),
                    subtitle: const Text(
                      'You can change it later in Settings → App behavior.',
                    ),
                    onChanged: (value) => setDialogState(
                      () => rememberSelection = value ?? false,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const _WindowsCloseDecision(_WindowsCloseAction.cancel),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(
                  context,
                  _WindowsCloseDecision(
                    _WindowsCloseAction.minimizeToTray,
                    remember: rememberSelection,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: const Text('Minimize to tray'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _WindowsCloseDecision(
                    _WindowsCloseAction.exit,
                    remember: rememberSelection,
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Exit'),
              ),
            ],
          ),
        );
      },
    );
    _closePromptVisible = false;

    if (decision?.remember == true) {
      final behavior = switch (decision!.action) {
        _WindowsCloseAction.minimizeToTray =>
          WindowsCloseBehavior.minimizeToTray,
        _WindowsCloseAction.exit => WindowsCloseBehavior.exit,
        _WindowsCloseAction.cancel => WindowsCloseBehavior.ask,
      };
      if (decision.action != _WindowsCloseAction.cancel) {
        await ref
            .read(windowsCloseBehaviorProvider.notifier)
            .setBehavior(behavior);
      }
    }

    switch (decision?.action) {
      case _WindowsCloseAction.minimizeToTray:
        await _hideWindowsWindow();
      case _WindowsCloseAction.exit:
        await _quitWindowsApp();
      case _WindowsCloseAction.cancel:
      case null:
        await _restoreWindowsWindow();
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreWindowsWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(_restoreWindowsWindow());
      case 'close':
        unawaited(_quitWindowsApp());
    }
  }

  @override
  void dispose() {
    if (!widget.skipStartupChecks && Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkSetup() async {
    if (Platform.isWindows) {
      try {
        await DownloadService.instance.initialize();
      } catch (error, stackTrace) {
        AppLogger.error('Bundled Windows tool setup failed', error, stackTrace);
      }
    }
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) {
      _enterReady();
      return;
    }

    final permissions = await PermissionService.instance
        .hasRequiredPermissions();
    final onboardingComplete =
        StorageService.instance.getBool(
          'permission_onboarding_complete',
          defaultValue: false,
        ) ??
        false;
    if (!mounted) return;
    if (permissions && onboardingComplete) {
      _enterReady();
    } else {
      setState(() => _phase = _StartupPhase.permissions);
    }
  }

  void _enterReady() {
    if (!mounted) return;
    setState(() => _phase = _StartupPhase.ready);
    _startApplicationUpdater();
  }

  void _startApplicationUpdater() {
    if (widget.skipStartupChecks || _appUpdaterStarted) return;
    _appUpdaterStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(appUpdateProvider.notifier).startAutomaticCheck());
    });
  }

  void _showApplicationUpdate(AppUpdateState update) {
    final release = update.release;
    if (release == null || _promptedUpdateVersion == release.version) return;
    final notificationContext = rootNavigatorKey.currentContext;
    if (notificationContext == null) return;
    _promptedUpdateVersion = release.version;
    AppNotificationCenter.show(
      notificationContext,
      kind: AppNotificationKind.update,
      title: 'MBNDL ${release.version} is ready',
      message: Platform.isWindows
          ? 'The update is downloaded and ready to install.'
          : 'The Android package is downloaded and ready for confirmation.',
      actionLabel: 'Open update settings',
      onTap: () => unawaited(openAppUpdateSettings()),
    );
  }

  void _showUpdateEvent(AppUpdateState previous, AppUpdateState next) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (next.stage == AppUpdateStage.downloading &&
        previous.stage != AppUpdateStage.downloading) {
      AppNotificationCenter.show(
        context,
        kind: AppNotificationKind.download,
        title: 'Downloading MBNDL update',
        message: 'The update continues safely in the background.',
        actionLabel: 'View progress',
        onTap: () => unawaited(openAppUpdateSettings()),
      );
    } else if (next.stage == AppUpdateStage.available &&
        !next.backgroundDownloads &&
        previous.stage != AppUpdateStage.available) {
      AppNotificationCenter.show(
        context,
        kind: AppNotificationKind.update,
        title: 'MBNDL ${next.release?.version ?? ''} is available',
        message: 'Review the release and choose when to download it.',
        actionLabel: 'Open update settings',
        onTap: () => unawaited(openAppUpdateSettings()),
      );
    } else if (next.stage == AppUpdateStage.error &&
        previous.message != next.message) {
      AppNotificationCenter.show(
        context,
        kind: AppNotificationKind.error,
        title: 'Update needs attention',
        message: next.message ?? 'The update could not be prepared.',
        actionLabel: 'Open update settings',
        onTap: () => unawaited(openAppUpdateSettings()),
      );
    }
  }

  void _showDownloadEvent(
    AsyncValue<List<DownloadItem>>? previous,
    AsyncValue<List<DownloadItem>> next,
  ) {
    if (_phase != _StartupPhase.ready) return;
    final before = previous?.asData?.value;
    final after = next.asData?.value;
    if (before == null || after == null) return;
    final oldById = {for (final item in before) item.id: item};
    final changed = after
        .where((item) {
          final old = oldById[item.id];
          return old != null && old.status != item.status;
        })
        .toList(growable: false);
    if (changed.isEmpty) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final failed = changed
        .where((item) => item.status == DownloadStatus.failed)
        .toList();
    final completed = changed
        .where((item) => item.status == DownloadStatus.completed)
        .toList();
    final started = changed
        .where((item) => item.status == DownloadStatus.downloading)
        .toList();
    final cancelled = changed
        .where((item) => item.status == DownloadStatus.cancelled)
        .toList();

    void show({
      required AppNotificationKind kind,
      required String title,
      required String message,
    }) {
      AppNotificationCenter.show(
        context,
        kind: kind,
        title: title,
        message: message,
        actionLabel: 'View downloads',
        onTap: () => appRouter.go('/history'),
      );
    }

    if (failed.isNotEmpty) {
      show(
        kind: AppNotificationKind.error,
        title: failed.length == 1
            ? 'Download failed'
            : '${failed.length} downloads failed',
        message: failed.length == 1
            ? failed.single.errorMessage ?? failed.single.title
            : 'Open Downloads to review what needs attention.',
      );
    } else if (completed.isNotEmpty) {
      show(
        kind: AppNotificationKind.success,
        title: completed.length == 1
            ? 'Download ready'
            : '${completed.length} downloads are ready',
        message: completed.length == 1
            ? completed.single.title
            : 'All completed files are available in Downloads/MBNDL.',
      );
    } else if (started.isNotEmpty) {
      show(
        kind: AppNotificationKind.download,
        title: started.length == 1
            ? 'Download started'
            : '${started.length} downloads started',
        message: started.length == 1
            ? started.single.title
            : 'Progress continues in the background.',
      );
    } else if (cancelled.isNotEmpty) {
      show(
        kind: AppNotificationKind.warning,
        title: 'Download cancelled',
        message: cancelled.length == 1
            ? cancelled.single.title
            : '${cancelled.length} downloads were cancelled.',
      );
    }
  }

  Future<void> _showYouTubeAuthIssue(YouTubeAuthIssue issue) async {
    if (_youtubeAuthPromptVisible) return;
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;
    _youtubeAuthPromptVisible = true;
    ref.read(youtubeAuthIssueProvider.notifier).clear();

    try {
      final action = await showDialog<_YouTubeAuthAction>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.account_circle_outlined),
          title: const Text('YouTube needs an account'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.message),
                const SizedBox(height: 16),
                Card.filled(
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Using account cookies with automated downloads can '
                            'cause temporary or permanent YouTube restrictions. '
                            'Use them only when necessary.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MBNDL opens the official sign-in page in your browser and '
                  'accepts only an exported Netscape cookies.txt file. It never '
                  'asks for your Google password.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _YouTubeAuthAction.later),
              child: const Text('Not now'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _YouTubeAuthAction.manageAccounts),
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Fix YouTube sign-in'),
            ),
          ],
        ),
      );

      if (action != _YouTubeAuthAction.manageAccounts ||
          !mounted ||
          !dialogContext.mounted) {
        return;
      }
      await Navigator.of(dialogContext, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => const CookieManagerPage()),
      );
      if (!mounted) return;
      final selected = ref.read(cookieProvider).selectedCookie;
      if (selected != null) {
        final messengerContext = rootNavigatorKey.currentContext;
        if (messengerContext != null && messengerContext.mounted) {
          AppNotificationCenter.show(
            messengerContext,
            kind: AppNotificationKind.success,
            title: 'YouTube account connected',
            message: '${selected.name} is active. Retry the YouTube link.',
          );
        }
      }
    } finally {
      _youtubeAuthPromptVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final color = ref.watch(themeColorProvider);
    final appearance = ref.watch(appearanceSettingsProvider);
    ref.listen<AppUpdateState>(appUpdateProvider, (previous, next) {
      if (_phase == _StartupPhase.ready && previous != null) {
        _showUpdateEvent(previous, next);
      }
      if (_phase == _StartupPhase.ready &&
          next.stage == AppUpdateStage.ready &&
          previous?.packagePath != next.packagePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showApplicationUpdate(next);
        });
      }
    });
    ref.listen<YouTubeAuthIssue?>(youtubeAuthIssueProvider, (previous, next) {
      if (_phase == _StartupPhase.ready && next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showYouTubeAuthIssue(next));
        });
      }
    });
    ref.listen<AsyncValue<List<DownloadItem>>>(downloadsProvider, (
      previous,
      next,
    ) {
      _showDownloadEvent(previous, next);
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = color == AppThemeColor.materialYou;
        final systemDisablesAnimations = WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
        final disableAnimations = switch (appearance.motionMode) {
          AppMotionMode.system => systemDisablesAnimations,
          AppMotionMode.full => false,
          AppMotionMode.reduced => true,
        };
        final lightTheme = useDynamic && lightDynamic != null
            ? AppTheme.fromColorScheme(lightDynamic, appearance: appearance)
            : AppTheme.lightTheme(color, appearance);
        final darkTheme = mode == AppThemeMode.darkAmoled
            ? AppTheme.darkAmoledTheme(color, appearance)
            : useDynamic && darkDynamic != null
            ? AppTheme.fromColorScheme(darkDynamic, appearance: appearance)
            : AppTheme.darkTheme(color, appearance);

        return MaterialApp.router(
          title: 'MBNDL',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode.toThemeMode(),
          themeAnimationDuration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 420),
          themeAnimationCurve: Curves.easeOutCubic,
          routerConfig: appRouter,
          builder: (context, routerChild) {
            Widget content = switch (_phase) {
              _StartupPhase.checking => const _StartupSurface(),
              _StartupPhase.permissions => PermissionRequestPage(
                onPermissionGranted: () {
                  _enterReady();
                },
              ),
              _StartupPhase.ready => routerChild ?? const SizedBox.shrink(),
            };
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations: switch (appearance.motionMode) {
                  AppMotionMode.system => media.disableAnimations,
                  AppMotionMode.full => false,
                  AppMotionMode.reduced => true,
                },
              ),
              child: content,
            );
          },
        );
      },
    );
  }
}

enum _WindowsCloseAction { minimizeToTray, exit, cancel }

class _WindowsCloseDecision {
  const _WindowsCloseDecision(this.action, {this.remember = false});

  final _WindowsCloseAction action;
  final bool remember;
}

enum _YouTubeAuthAction { later, manageAccounts }

class _StartupSurface extends StatelessWidget {
  const _StartupSurface();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 46,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing built-in download tools…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
