import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/floating_navigation_insets.dart';

enum AppNotificationKind { info, success, warning, error, download, update }

class AppNotificationCenter {
  AppNotificationCenter._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    AppNotificationKind kind = AppNotificationKind.info,
    String? actionLabel,
    VoidCallback? onTap,
    Duration? duration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _currentEntry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppNotificationOverlay(
        title: title,
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onTap: onTap,
        duration:
            duration ??
            (kind == AppNotificationKind.update
                ? const Duration(seconds: 12)
                : const Duration(seconds: 5)),
        onRemoved: () {
          if (entry.mounted) entry.remove();
          if (identical(_currentEntry, entry)) _currentEntry = null;
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppNotificationOverlay extends StatefulWidget {
  const _AppNotificationOverlay({
    required this.title,
    required this.message,
    required this.kind,
    required this.duration,
    required this.onRemoved,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String message;
  final AppNotificationKind kind;
  final String? actionLabel;
  final VoidCallback? onTap;
  final Duration duration;
  final VoidCallback onRemoved;

  @override
  State<_AppNotificationOverlay> createState() =>
      _AppNotificationOverlayState();
}

class _AppNotificationOverlayState extends State<_AppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _started = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.duration = Duration.zero;
      _controller.reverseDuration = Duration.zero;
    }
    unawaited(_controller.forward());
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onRemoved();
  }

  Future<void> _activate() async {
    final callback = widget.onTap;
    await _dismiss();
    callback?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, accent) = switch (widget.kind) {
      AppNotificationKind.success => (
        Icons.check_circle_rounded,
        colors.tertiary,
      ),
      AppNotificationKind.warning => (
        Icons.warning_amber_rounded,
        colors.tertiary,
      ),
      AppNotificationKind.error => (Icons.error_rounded, colors.error),
      AppNotificationKind.download => (
        Icons.download_rounded,
        colors.secondary,
      ),
      AppNotificationKind.update => (
        Icons.system_update_alt_rounded,
        colors.primary,
      ),
      AppNotificationKind.info => (Icons.info_rounded, colors.primary),
    };
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final bottom = 12 + floatingNavigationScrollClearance(context);

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.32),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    key: const ValueKey('app-notification-surface'),
                    color: colors.surfaceContainerHighest,
                    elevation: 8,
                    shadowColor: colors.shadow.withValues(alpha: 0.28),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: accent.withValues(alpha: 0.42)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onTap == null ? null : _activate,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(icon, color: accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          height: 1.3,
                                        ),
                                  ),
                                  if (widget.actionLabel != null) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      widget.actionLabel!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _dismiss,
                              tooltip: 'Dismiss',
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
