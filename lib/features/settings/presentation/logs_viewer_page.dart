import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/logger/app_logger.dart';

class LogsViewerPage extends StatefulWidget {
  const LogsViewerPage({super.key});

  @override
  State<LogsViewerPage> createState() => _LogsViewerPageState();
}

class _LogsViewerPageState extends State<LogsViewerPage> {
  String _logContent = '';
  bool _isLoading = true;
  String _filter = 'all';
  final TextEditingController _searchController = TextEditingController();
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
    setState(() {
      _isLoading = true;
    });

    try {
      final content = await AppLogger.getLogContent();
      setState(() {
        _logContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _logContent = 'Failed to load logs: $e';
        _isLoading = false;
      });
    }
  }

  List<String> _getFilteredLines() {
    if (_logContent.isEmpty) return [];

    var lines = _logContent.split('\n');

    // Apply level filter
    if (_filter != 'all') {
      lines = lines.where((line) {
        final lowerLine = line.toLowerCase();
        switch (_filter) {
          case 'error':
            return lowerLine.contains('[error]');
          case 'warning':
            return lowerLine.contains('[warning]');
          case 'info':
            return lowerLine.contains('[info]');
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      lines = lines
          .where(
            (line) => line.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return lines;
  }

  Color _getLineColor(String line) {
    if (line.toLowerCase().contains('[error]')) {
      return Colors.red.shade300;
    } else if (line.toLowerCase().contains('[warning]')) {
      return Colors.orange.shade300;
    } else if (line.toLowerCase().contains('[info]')) {
      return Colors.blue.shade300;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final filteredLines = _getFilteredLines();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          // Copy all logs
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy All',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _logContent));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // Refresh logs
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Search Section
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search logs...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Errors', 'error', Colors.red),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Warnings',
                            'warning',
                            Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip('Info', 'info', Colors.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: -0.2, end: 0, duration: 300.ms),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${filteredLines.length} lines',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_searchQuery.isNotEmpty || _filter != 'all') ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.filter_alt,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filtered',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Logs content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _logContent.isEmpty
                              ? 'No logs available'
                              : 'No matching logs found',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLines.length,
                    itemBuilder: (context, index) {
                      final line = filteredLines[index];
                      if (line.trim().isEmpty) return const SizedBox.shrink();

                      return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: _getLineColor(line),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: SelectableText(
                              line,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: (index * 10).ms, duration: 200.ms)
                          .slideX(
                            begin: -0.1,
                            end: 0,
                            delay: (index * 10).ms,
                            duration: 200.ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, [Color? color]) {
    final isSelected = _filter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = selected ? value : 'all';
        });
      },
      backgroundColor: color?.withValues(alpha: 0.1),
      selectedColor:
          color?.withValues(alpha: 0.3) ??
          Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: color ?? Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? (color ?? Theme.of(context).colorScheme.primary)
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? (color ?? Theme.of(context).colorScheme.primary)
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
