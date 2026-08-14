import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/settings_provider.dart';

class QuickPresetSelector extends ConsumerWidget {
  const QuickPresetSelector({
    super.key,
    this.showAdvancedButton = false,
    this.onPresetApplied,
  });

  final bool showAdvancedButton;
  final VoidCallback? onPresetApplied;

  static const _presets = <_QuickPreset>[
    _QuickPreset(
      id: 'default',
      label: 'Balanced',
      description: '4 fragments · 10 retries',
      icon: Icons.balance_rounded,
    ),
    _QuickPreset(
      id: 'speed',
      label: 'Fast',
      description: '8 fragments · strong connection',
      icon: Icons.speed_rounded,
    ),
    _QuickPreset(
      id: 'resilient',
      label: 'Unstable network',
      description: 'Single stream · longer retries',
      icon: Icons.network_check_rounded,
    ),
    _QuickPreset(
      id: 'gentle_youtube',
      label: 'Gentle YouTube',
      description: 'Slower request pace',
      icon: Icons.health_and_safety_outlined,
    ),
    _QuickPreset(
      id: 'limited_bandwidth',
      label: 'Limited data',
      description: 'Single stream · 2 MiB/s cap',
      icon: Icons.data_saver_on_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ytDlpSettingsProvider);
    final colors = Theme.of(context).colorScheme;
    _QuickPreset? current;
    for (final preset in _presets) {
      if (preset.id == settings.preset) {
        current = preset;
        break;
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick preset',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose connection and retry behavior before inspecting '
                        'the link. Format selection and merging stay automatic.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAdvancedButton)
                  IconButton.filledTonal(
                    tooltip: 'Detailed yt-dlp settings',
                    onPressed: () => context.push('/ytdlp-settings'),
                    icon: const Icon(Icons.tune_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    avatar: Icon(preset.icon, size: 18),
                    label: Text(preset.label),
                    selected: settings.preset == preset.id,
                    onSelected: (_) async {
                      await ref
                          .read(ytDlpSettingsProvider.notifier)
                          .loadPreset(preset.id);
                      onPresetApplied?.call();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current == null
                        ? 'Custom preset is active'
                        : '${current.label}: ${current.description}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showAdvancedButton)
                  TextButton.icon(
                    onPressed: () => context.push('/ytdlp-settings'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Detailed settings'),
                  ),
              ],
            ),
            if (showAdvancedButton)
              Text(
                'More controls are always available in Settings → Downloads & '
                'accounts → Quick presets & yt-dlp.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickPreset {
  const _QuickPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}
