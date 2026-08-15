import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../services/logger/app_log_entry.dart';
import '../../../services/logger/app_logger.dart';

class LogsViewerPage extends StatefulWidget {
  const LogsViewerPage({super.key});

  @override
  State<LogsViewerPage> createState() => _LogsViewerPageState();
}

class _LogsViewerPageState extends State<LogsViewerPage> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  List<AppLogEntry> _entries = const [];
  bool _isLoading = true;
  LogLevel? _filter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final entries = await AppLogger.getLogEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries.reversed.toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _entries = [
          AppLogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.error,
            message: 'Failed to load logs',
            error: error.toString(),
          ),
        ];
        _isLoading = false;
      });
    }
  }

  List<AppLogEntry> get _filteredEntries {
    final query = _searchQuery.trim().toLowerCase();
    return _entries
        .where((entry) {
          if (_filter != null && entry.level != _filter) return false;
          if (query.isEmpty) return true;
          return entry.searchableText.toLowerCase().contains(query) ||
              entry.level?.name.contains(query) == true;
        })
        .toList(growable: false);
  }

  Future<void> _copyEntries(List<AppLogEntry> entries) async {
    final text = entries.reversed.map(_humanReadable).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visible log events copied')));
  }

  String _humanReadable(AppLogEntry entry) => [
    '[${_timestampFormat.format(entry.timestamp.toLocal())}] '
        '[${entry.level?.name.toUpperCase() ?? 'SESSION'}] ${entry.message}',
    if (entry.error?.isNotEmpty == true) 'Error: ${entry.error}',
    if (entry.stackTrace?.isNotEmpty == true) entry.stackTrace!,
  ].join('\n');

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('Clear application logs?'),
        content: const Text(
          'This removes the current diagnostic log. New events will continue '
          'to be recorded at the selected detail level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLogger.clear();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy visible events',
            onPressed: filtered.isEmpty ? null : () => _copyEntries(filtered),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search message, error, or stack trace…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(label: 'All', level: null),
                          for (final level in LogLevel.values) ...[
                            const SizedBox(width: 8),
                            _filterChip(
                              label:
                                  level.name[0].toUpperCase() +
                                  level.name.substring(1),
                              level: level,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 17, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recording ${AppLogger.currentLevel.name.toUpperCase()} '
                          'and more severe events • ${filtered.length} visible',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 220.ms),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _EmptyLogs(hasLogs: _entries.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _LogEventCard(
                              entry: filtered[index],
                              timestamp: _timestampFormat.format(
                                filtered[index].timestamp.toLocal(),
                              ),
                            )
                            .animate()
                            .fadeIn(
                              delay: Duration(
                                milliseconds: (index * 8).clamp(0, 120).toInt(),
                              ),
                              duration: 180.ms,
                            )
                            .slideY(begin: 0.05, end: 0),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required LogLevel? level}) {
    final selected = _filter == level;
    final color = level == null ? null : _levelColor(level, context);
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: level == null
          ? const Icon(Icons.all_inclusive_rounded, size: 18)
          : Icon(_levelIcon(level), size: 18, color: color),
      onSelected: (_) => setState(() => _filter = level),
      selectedColor: color?.withValues(alpha: 0.18),
      checkmarkColor: color,
    );
  }
}

class _LogEventCard extends StatelessWidget {
  const _LogEventCard({required this.entry, required this.timestamp});

  final AppLogEntry entry;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = entry.level == null
        ? colors.outline
        : _levelColor(entry.level!, context);
    final hasDetails =
        entry.error?.isNotEmpty == true || entry.stackTrace?.isNotEmpty == true;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              entry.level == null
                  ? Icons.power_settings_new_rounded
                  : _levelIcon(entry.level!),
              size: 19,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                entry.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (hasDetails) ...[
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            dense: true,
            title: const Text('Technical details'),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  [
                    if (entry.error?.isNotEmpty == true) entry.error!,
                    if (entry.stackTrace?.isNotEmpty == true) entry.stackTrace!,
                  ].join('\n\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: content,
    );
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs({required this.hasLogs});

  final bool hasLogs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.manage_search_rounded, size: 56),
          const SizedBox(height: 14),
          Text(hasLogs ? 'No matching log events' : 'No logs recorded yet'),
        ],
      ),
    );
  }
}

Color _levelColor(LogLevel level, BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return switch (level) {
    LogLevel.trace => colors.outline,
    LogLevel.debug => colors.tertiary,
    LogLevel.info => colors.primary,
    LogLevel.warning => Colors.orange.shade700,
    LogLevel.error => colors.error,
    LogLevel.fatal => Colors.purple.shade400,
  };
}

IconData _levelIcon(LogLevel level) => switch (level) {
  LogLevel.trace => Icons.route_outlined,
  LogLevel.debug => Icons.bug_report_outlined,
  LogLevel.info => Icons.info_outline_rounded,
  LogLevel.warning => Icons.warning_amber_rounded,
  LogLevel.error => Icons.error_outline_rounded,
  LogLevel.fatal => Icons.dangerous_outlined,
};
