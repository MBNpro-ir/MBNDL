import 'package:flutter/material.dart';

import '../../services/logger/app_logger.dart';
import '../../services/permissions/permission_service.dart';
import '../../services/storage/storage_service.dart';

class PermissionRequestPage extends StatefulWidget {
  const PermissionRequestPage({super.key, required this.onPermissionGranted});

  final VoidCallback onPermissionGranted;

  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage>
    with WidgetsBindingObserver {
  RequiredPermissionState? _permissions;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final value = await PermissionService.instance
          .getRequiredPermissionState();
      if (mounted) setState(() => _permissions = value);
    } catch (error, stackTrace) {
      AppLogger.error('Could not read permission state', error, stackTrace);
      if (mounted) setState(() => _message = 'Could not check app access.');
    }
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final granted = await PermissionService.instance
          .requestAllRequiredPermissions();
      final state = await PermissionService.instance
          .getRequiredPermissionState();
      if (!mounted) return;
      setState(() => _permissions = state);
      if (!granted || !state.allGranted) {
        setState(() {
          _message =
              'Grant the required access to continue. You can also enable it '
              'from Android app settings.';
        });
        return;
      }
      await StorageService.instance.setBool(
        'permission_onboarding_complete',
        true,
      );
      if (mounted) widget.onPermissionGranted();
    } catch (error, stackTrace) {
      AppLogger.error('Permission onboarding failed', error, stackTrace);
      if (mounted) {
        setState(() => _message = 'Access could not be granted. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final permissions = _permissions;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 40,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Set up MBNDL',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Before the first download, confirm the access MBNDL needs. '
                    'Completed files are saved in Downloads/MBNDL.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (permissions == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else ...[
                    _PermissionTile(
                      icon: Icons.folder_copy_rounded,
                      title: 'Downloads / MBNDL',
                      description:
                          'Android secure storage publishes completed media so '
                          'it remains visible in your file manager.',
                      granted: permissions.downloadFolderReady,
                      required: true,
                    ),
                    if (permissions.storageRequired) ...[
                      const SizedBox(height: 10),
                      _PermissionTile(
                        icon: Icons.sd_storage_rounded,
                        title: 'Legacy storage access',
                        description:
                            'Required only because this device runs Android 9 '
                            'or older.',
                        granted: permissions.storageGranted,
                        required: true,
                      ),
                    ],
                    if (permissions.notificationRequired) ...[
                      const SizedBox(height: 10),
                      _PermissionTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Download notifications',
                        description:
                            'Shows progress while a download continues in the '
                            'background.',
                        granted: permissions.notificationGranted,
                        required: true,
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: colors.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'MBNDL does not request broad “all files” access. '
                              'It uses Android MediaStore for files created by '
                              'the app.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy || permissions == null ? null : _continue,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            permissions?.allGranted == true
                                ? Icons.arrow_forward_rounded
                                : Icons.lock_open_rounded,
                          ),
                    label: Text(
                      permissions?.allGranted == true
                          ? 'Continue to MBNDL'
                          : 'Grant required access',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : PermissionService.instance.openApplicationSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open Android settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.required,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        trailing: Chip(
          avatar: Icon(
            granted ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 18,
          ),
          label: Text(
            granted
                ? 'Ready'
                : required
                ? 'Required'
                : 'Optional',
          ),
          backgroundColor: granted
              ? colors.primaryContainer
              : colors.errorContainer,
          labelStyle: TextStyle(
            color: granted
                ? colors.onPrimaryContainer
                : colors.onErrorContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
