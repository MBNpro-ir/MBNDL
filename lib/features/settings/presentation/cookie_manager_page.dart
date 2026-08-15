import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/floating_navigation_insets.dart';
import '../../../services/storage/cookie_storage_service.dart';
import '../../../shared/models/cookie_item.dart';
import '../../../shared/providers/cookie_provider.dart';

class CookieManagerPage extends ConsumerStatefulWidget {
  const CookieManagerPage({super.key});

  @override
  ConsumerState<CookieManagerPage> createState() => _CookieManagerPageState();
}

class _CookieManagerPageState extends ConsumerState<CookieManagerPage> {
  static final _signInUri = Uri.parse(
    'https://accounts.google.com/ServiceLogin?service=youtube',
  );
  static final _guideUri = Uri.parse(
    'https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies',
  );

  Future<void> _openExternal(Uri uri) async {
    var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (!opened && mounted) {
      _message('Could not open the browser.', error: true);
    }
  }

  Future<void> _import({CookieItem? replacing}) async {
    final state = ref.read(cookieProvider);
    if (replacing == null &&
        state.cookies.length >= CookieStorageService.maxAccounts) {
      _message(
        'Sign out of an account before adding another one.',
        error: true,
      );
      return;
    }

    final account = await showDialog<CookieItem>(
      context: context,
      builder: (_) => _ImportYouTubeAccountDialog(
        existing: state.cookies,
        replacing: replacing,
      ),
    );
    if (account == null || !mounted) return;

    try {
      if (replacing == null) {
        await ref.read(cookieProvider.notifier).addCookie(account);
      } else {
        await ref.read(cookieProvider.notifier).updateCookie(account);
        await ref.read(cookieProvider.notifier).selectCookie(account.id);
      }
      _message(
        replacing == null
            ? '${account.name} is now the active YouTube account.'
            : '${account.name} was refreshed and activated.',
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
    }
  }

  Future<void> _signOut(CookieItem account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: Text('Sign out ${account.name}?'),
        content: const Text(
          'The encrypted cookie data for this account will be removed from '
          'this device. This does not sign you out in your browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cookieProvider.notifier).deleteCookie(account.id);
    if (mounted) _message('${account.name} was removed from MBNDL.');
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cookieProvider);
    final colors = Theme.of(context).colorScheme;
    final canAdd = state.cookies.length < CookieStorageService.maxAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube accounts'),
        actions: [
          if (state.selectedCookieId != null)
            TextButton.icon(
              onPressed: ref.read(cookieProvider.notifier).clearSelection,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Disable'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              18 + floatingNavigationScrollClearance(context),
            ),
            children: [
              Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colors.onErrorContainer,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your YouTube account can be restricted or banned',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'yt-dlp recommends using account cookies only '
                              'when content truly requires them. Automated '
                              'downloads can trigger temporary or permanent '
                              'account restrictions. A separate account is '
                              'safer, but still not risk-free.',
                              style: TextStyle(
                                color: colors.onErrorContainer,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe sign-in flow',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Android and Windows isolate browser cookies from '
                        'other apps, and YouTube OAuth is not supported by '
                        'yt-dlp. MBNDL therefore never asks for your email or '
                        'password.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _InstructionStep(
                        number: '1',
                        text:
                            'Open a private/incognito browser window and sign in to YouTube.',
                      ),
                      const _InstructionStep(
                        number: '2',
                        text:
                            'In the same tab open youtube.com/robots.txt, then export only YouTube cookies in Netscape format.',
                      ),
                      const _InstructionStep(
                        number: '3',
                        text:
                            'Close that private window and import the cookies.txt file here.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openExternal(_signInUri),
                            icon: const Icon(Icons.open_in_browser_rounded),
                            label: const Text('Open YouTube sign-in'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openExternal(_guideUri),
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text('Official yt-dlp guide'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved accounts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${state.cookies.length}/${CookieStorageService.maxAccounts}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.cookies.isEmpty)
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 52,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No YouTube account is connected',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Anonymous downloads remain the default and safest option.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final account in state.cookies) ...[
                  _AccountCard(
                    account: account,
                    active: state.selectedCookieId == account.id,
                    onActivate: () => ref
                        .read(cookieProvider.notifier)
                        .selectCookie(account.id),
                    onRefresh: () => _import(replacing: account),
                    onSignOut: () => _signOut(account),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAdd ? _import : null,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(canAdd ? 'Import account' : '3 accounts saved'),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 14, child: Text(number)),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.active,
    required this.onActivate,
    required this.onRefresh,
    required this.onSignOut,
  });

  final CookieItem account;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = account.updatedAt.toLocal();
    final updated =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Card(
      color: active ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  active
                      ? Icons.verified_user_rounded
                      : Icons.person_outline_rounded,
                ),
              ),
              title: Text(
                account.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Cookies refreshed $updated'),
              trailing: active
                  ? const Chip(
                      avatar: Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('Active'),
                    )
                  : FilledButton.tonal(
                      onPressed: onActivate,
                      child: const Text('Switch'),
                    ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Sign in again'),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportYouTubeAccountDialog extends StatefulWidget {
  const _ImportYouTubeAccountDialog({required this.existing, this.replacing});

  final List<CookieItem> existing;
  final CookieItem? replacing;

  @override
  State<_ImportYouTubeAccountDialog> createState() =>
      _ImportYouTubeAccountDialogState();
}

class _ImportYouTubeAccountDialogState
    extends State<_ImportYouTubeAccountDialog> {
  late final TextEditingController _nameController;
  String? _content;
  String? _fileName;
  String? _error;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.replacing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        dialogTitle: 'Choose YouTube cookies.txt',
      );
      if (result == null) return;
      final picked = result.files.single;
      final bytes = await picked.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: false);
      final validation = CookieStorageService.validateYouTubeCookieFile(
        content,
      );
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      setState(() {
        _content = content;
        _fileName = picked.name;
      });
    } on FormatException {
      setState(() => _error = 'The cookie file must be valid UTF-8 text.');
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a short name for this account.');
      return;
    }
    if (widget.existing.any(
      (item) =>
          item.id != widget.replacing?.id &&
          item.name.toLowerCase() == name.toLowerCase(),
    )) {
      setState(() => _error = 'An account with this name already exists.');
      return;
    }
    if (_content == null) {
      setState(() => _error = 'Choose and verify a Netscape cookies.txt file.');
      return;
    }
    final now = DateTime.now();
    Navigator.pop(
      context,
      CookieItem(
        id: widget.replacing?.id ?? const Uuid().v4(),
        name: name,
        content: _content!,
        createdAt: widget.replacing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.cookie_rounded),
    title: Text(
      widget.replacing == null ? 'Import YouTube account' : 'Refresh account',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Only a Netscape-format export containing YouTube/Google cookie '
              'rows is accepted. MBNDL encrypts the content at rest. Delete '
              'the unencrypted export after it has been imported.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Account label',
                hintText: 'Example: Personal or Music',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _picking ? null : _pick,
              icon: _picking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _content == null
                          ? Icons.file_open_rounded
                          : Icons.verified_rounded,
                    ),
              label: Text(_fileName ?? 'Choose cookies.txt'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _content == null ? null : _submit,
        child: const Text('Save securely'),
      ),
    ],
  );
}
