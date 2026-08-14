import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mbn_downloader/core/theme/app_theme.dart';

void main() {
  testWidgets('app theme uses Material 3 components', (tester) async {
    final theme = AppTheme.lightTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(child: SearchBar(hintText: 'Paste a video link')),
        ),
      ),
    );

    expect(theme.useMaterial3, isTrue);
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Paste a video link'), findsOneWidget);
  });
}
