import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/providers/cookie_provider.dart';
import '../../../shared/models/cookie_item.dart';

class CookieManagerPage extends ConsumerStatefulWidget {
  const CookieManagerPage({super.key});

  @override
  ConsumerState<CookieManagerPage> createState() => _CookieManagerPageState();
}

class _CookieManagerPageState extends ConsumerState<CookieManagerPage> {
  void _showAddCookieDialog() {
    final existingCookies = ref.read(cookieProvider).cookies;

    showDialog(
      context: context,
      builder: (context) => _AddCookieDialog(
        existingCookies: existingCookies,
        onAdd: (cookie) {
          ref.read(cookieProvider.notifier).addCookie(cookie);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cookie "${cookie.name}" added successfully'),
            ),
          );
        },
      ),
    );
  }

  void _showEditCookieDialog(CookieItem cookie) {
    final existingCookies = ref.read(cookieProvider).cookies;

    showDialog(
      context: context,
      builder: (context) => _EditCookieDialog(
        cookie: cookie,
        existingCookies: existingCookies,
        onUpdate: (updatedCookie) {
          ref.read(cookieProvider.notifier).updateCookie(updatedCookie);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cookie updated successfully')),
          );
        },
      ),
    );
  }

  void _deleteCookie(CookieItem cookie) {
    // Save parent context before showing dialog
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Cookie'),
        content: Text('Are you sure you want to delete "${cookie.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Close dialog first
              Navigator.of(dialogContext).pop();

              // Then delete and show snackbar using parent context
              ref.read(cookieProvider.notifier).deleteCookie(cookie.id);
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(content: Text('Cookie "${cookie.name}" deleted')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cookieState = ref.watch(cookieProvider);
    final cookies = cookieState.cookies;
    final selectedId = cookieState.selectedCookieId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookie Manager'),
        actions: [
          if (selectedId != null)
            TextButton.icon(
              onPressed: () {
                ref.read(cookieProvider.notifier).clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cookie selection cleared')),
                );
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Selection'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: cookies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cookie_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cookies added yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add cookies to access restricted content',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (value) {
                if (value != null) {
                  ref.read(cookieProvider.notifier).selectCookie(value);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cookies.length,
                itemBuilder: (context, index) {
                  final cookie = cookies[index];
                  final isSelected = cookie.id == selectedId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Radio<String>(
                        value: cookie.id,
                        toggleable: true,
                      ),
                      title: Text(
                        cookie.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Added: ${_formatDate(cookie.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditCookieDialog(cookie),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteCookie(cookie),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      onTap: () {
                        ref
                            .read(cookieProvider.notifier)
                            .selectCookie(cookie.id);
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCookieDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Cookie'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Add Cookie Dialog with File Picker and Verification
class _AddCookieDialog extends StatefulWidget {
  final List<CookieItem> existingCookies;
  final Function(CookieItem) onAdd;

  const _AddCookieDialog({required this.existingCookies, required this.onAdd});

  @override
  State<_AddCookieDialog> createState() => _AddCookieDialogState();
}

class _AddCookieDialogState extends State<_AddCookieDialog> {
  final _nameController = TextEditingController();
  String? _selectedFilePath;
  String? _fileContent;
  bool _isVerified = false;
  bool _isVerifying = false;
  String? _verificationMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickCookieFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        dialogTitle: 'Select Cookie File',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _isVerified = false;
          _verificationMessage = null;
          _fileContent = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _verifyCookieFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isVerifying = true;
      _verificationMessage = null;
    });

    try {
      final file = File(_selectedFilePath!);

      if (!await file.exists()) {
        setState(() {
          _isVerifying = false;
          _isVerified = false;
          _verificationMessage = '❌ File does not exist';
        });
        return;
      }

      final content = await file.readAsString();

      // Verify Netscape cookie format
      if (content.isEmpty) {
        setState(() {
          _isVerifying = false;
          _isVerified = false;
          _verificationMessage = '❌ File is empty';
        });
        return;
      }

      // Check for Netscape format header or valid cookie lines
      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      // Common patterns in cookie files
      final hasNetscapeHeader =
          content.contains('# Netscape HTTP Cookie File') ||
          content.contains('# HTTP Cookie File');
      final hasValidCookies = lines.any(
        (line) => !line.startsWith('#') && line.split('\t').length >= 6,
      );

      if (hasNetscapeHeader || hasValidCookies || lines.isNotEmpty) {
        setState(() {
          _isVerifying = false;
          _isVerified = true;
          _fileContent = content;
          _verificationMessage = '✅ Valid cookie file (${lines.length} lines)';
        });
      } else {
        setState(() {
          _isVerifying = false;
          _isVerified = false;
          _verificationMessage = '⚠️ File format may not be valid';
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _isVerified = false;
        _verificationMessage = '❌ Error reading file: $e';
      });
    }
  }

  void _addCookie() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter cookie name')));
      return;
    }

    // Check for duplicate name
    final isDuplicate = widget.existingCookies.any(
      (cookie) => cookie.name.toLowerCase() == name.toLowerCase(),
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cookie name "$name" already exists')),
      );
      return;
    }

    if (!_isVerified || _fileContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify the cookie file first')),
      );
      return;
    }

    final cookie = CookieItem(
      id: const Uuid().v4(),
      name: name,
      content: _fileContent!,
      createdAt: DateTime.now(),
    );

    // Close dialog first, then call callback
    Navigator.of(context).pop();
    widget.onAdd(cookie);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Cookie'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cookie Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Cookie Name',
                hintText: 'e.g., YouTube Login',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // File Selection
            const Text(
              'Cookie File',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickCookieFile,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _selectedFilePath == null
                    ? 'Select Cookie File (.txt)'
                    : 'File Selected',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFilePath!.split(Platform.pathSeparator).last,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Verify Button
              FilledButton.icon(
                onPressed: _isVerifying ? null : _verifyCookieFile,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(
                  _isVerifying ? 'Verifying...' : 'Verify Cookie File',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),

              // Verification Status
              if (_verificationMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isVerified
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isVerified ? Icons.check_circle : Icons.error,
                        size: 20,
                        color: _isVerified
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _verificationMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _isVerified
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerified ? _addCookie : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Edit Cookie Dialog
class _EditCookieDialog extends StatefulWidget {
  final CookieItem cookie;
  final List<CookieItem> existingCookies;
  final Function(CookieItem) onUpdate;

  const _EditCookieDialog({
    required this.cookie,
    required this.existingCookies,
    required this.onUpdate,
  });

  @override
  State<_EditCookieDialog> createState() => _EditCookieDialogState();
}

class _EditCookieDialogState extends State<_EditCookieDialog> {
  late final TextEditingController _nameController;
  String? _selectedFilePath;
  String? _newFileContent;
  bool _replaceFile = false;
  bool _isVerified = false;
  bool _isVerifying = false;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cookie.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickCookieFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        dialogTitle: 'Select Cookie File',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _replaceFile = true;
          _isVerified = false;
          _verificationMessage = null;
          _newFileContent = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _verifyCookieFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isVerifying = true;
      _verificationMessage = null;
    });

    try {
      final file = File(_selectedFilePath!);
      final content = await file.readAsString();

      if (content.isEmpty) {
        setState(() {
          _isVerifying = false;
          _isVerified = false;
          _verificationMessage = '❌ File is empty';
        });
        return;
      }

      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      setState(() {
        _isVerifying = false;
        _isVerified = true;
        _newFileContent = content;
        _verificationMessage = '✅ Valid cookie file (${lines.length} lines)';
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _isVerified = false;
        _verificationMessage = '❌ Error reading file: $e';
      });
    }
  }

  void _updateCookie() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter cookie name')));
      return;
    }

    // Check for duplicate name (excluding current cookie)
    if (name.toLowerCase() != widget.cookie.name.toLowerCase()) {
      final isDuplicate = widget.existingCookies.any(
        (cookie) =>
            cookie.id != widget.cookie.id &&
            cookie.name.toLowerCase() == name.toLowerCase(),
      );

      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cookie name "$name" already exists')),
        );
        return;
      }
    }

    if (_replaceFile && (!_isVerified || _newFileContent == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify the new cookie file')),
      );
      return;
    }

    final updatedCookie = widget.cookie.copyWith(
      name: name,
      content: _replaceFile ? _newFileContent! : widget.cookie.content,
    );

    // Close dialog first, then call callback
    Navigator.of(context).pop();
    widget.onUpdate(updatedCookie);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Cookie'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cookie Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Cookie Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Replace File Option
            CheckboxListTile(
              value: _replaceFile,
              onChanged: (value) {
                setState(() {
                  _replaceFile = value ?? false;
                  if (!_replaceFile) {
                    _selectedFilePath = null;
                    _newFileContent = null;
                    _isVerified = false;
                    _verificationMessage = null;
                  }
                });
              },
              title: const Text('Replace cookie file'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            if (_replaceFile) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickCookieFile,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedFilePath == null
                      ? 'Select New Cookie File (.txt)'
                      : 'File Selected',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

              if (_selectedFilePath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFilePath!.split(Platform.pathSeparator).last,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isVerifying ? null : _verifyCookieFile,
                  icon: _isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user),
                  label: Text(
                    _isVerifying ? 'Verifying...' : 'Verify Cookie File',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),

                if (_verificationMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isVerified
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isVerified ? Icons.check_circle : Icons.error,
                          size: 20,
                          color: _isVerified
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _verificationMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _isVerified
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_replaceFile && !_isVerified) ? null : _updateCookie,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
