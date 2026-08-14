import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_update_provider.dart';

class AppUpdateSettings extends ConsumerWidget {
  const AppUpdateSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final supported = Platform.isAndroid || Platform.isWindows;

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.update_rounded),
          title: const Text('Automatic update checks'),
          subtitle: const Text('Check GitHub Releases when MBNDL starts'),
          value: update.automaticChecks,
          onChanged: supported ? notifier.setAutomaticChecks : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.download_for_offline_outlined),
          title: const Text('Download updates in background'),
          subtitle: const Text(
            'Prepare the correct Windows or Android package while you work',
          ),
          value: update.backgroundDownloads,
          onChanged: supported && update.automaticChecks
              ? notifier.setBackgroundDownloads
              : null,
        ),
        const Divider(height: 1),
        ListTile(
          leading: _StatusIcon(stage: update.stage),
          title: Text(_title(update)),
          subtitle: Text(_subtitle(update, supported)),
          trailing: _ActionButton(state: update),
        ),
        if (update.stage == AppUpdateStage.downloading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LinearProgressIndicator(value: update.progress),
          ),
      ],
    );
  }

  String _title(AppUpdateState state) => switch (state.stage) {
    AppUpdateStage.checking => 'Checking for updates…',
    AppUpdateStage.upToDate => 'MBNDL is up to date',
    AppUpdateStage.available =>
      'Version ${state.release?.version} is available',
    AppUpdateStage.downloading =>
      'Downloading version ${state.release?.version}…',
    AppUpdateStage.ready => 'Version ${state.release?.version} is ready',
    AppUpdateStage.installing => 'Opening the installer…',
    AppUpdateStage.error => 'Update needs attention',
    AppUpdateStage.idle => 'Application updates',
  };

  String _subtitle(AppUpdateState state, bool supported) {
    if (!supported) {
      return 'Updates are currently available on Android and Windows.';
    }
    if (state.message != null) return state.message!;
    if (state.stage == AppUpdateStage.downloading) {
      return '${(state.progress * 100).round()}% downloaded';
    }
    final current = state.currentVersion.isEmpty
        ? 'detecting…'
        : state.currentVersion;
    return 'Installed version: $current';
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appUpdateProvider.notifier);
    return switch (state.stage) {
      AppUpdateStage.available => FilledButton.tonal(
        onPressed: notifier.downloadUpdate,
        child: const Text('Download'),
      ),
      AppUpdateStage.ready => FilledButton(
        onPressed: notifier.installUpdate,
        child: const Text('Install'),
      ),
      AppUpdateStage.checking ||
      AppUpdateStage.downloading ||
      AppUpdateStage.installing => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      _ => TextButton(
        onPressed: () => notifier.checkForUpdates(),
        child: const Text('Check now'),
      ),
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.stage});

  final AppUpdateStage stage;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (stage) {
      AppUpdateStage.upToDate => (
        Icons.check_circle_outline_rounded,
        Colors.green,
      ),
      AppUpdateStage.available || AppUpdateStage.ready => (
        Icons.new_releases_outlined,
        Theme.of(context).colorScheme.primary,
      ),
      AppUpdateStage.error => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
      ),
      _ => (
        Icons.system_update_alt_rounded,
        Theme.of(context).colorScheme.primary,
      ),
    };
    return Icon(icon, color: color);
  }
}
