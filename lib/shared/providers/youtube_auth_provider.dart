import 'package:flutter_riverpod/flutter_riverpod.dart';

class YouTubeAuthIssue {
  const YouTubeAuthIssue({
    required this.url,
    required this.message,
    required this.raisedAt,
  });

  final String url;
  final String message;
  final DateTime raisedAt;
}

final youtubeAuthIssueProvider =
    NotifierProvider<YouTubeAuthIssueNotifier, YouTubeAuthIssue?>(
      YouTubeAuthIssueNotifier.new,
    );

class YouTubeAuthIssueNotifier extends Notifier<YouTubeAuthIssue?> {
  @override
  YouTubeAuthIssue? build() => null;

  void report({required String url, required String message}) {
    state = YouTubeAuthIssue(
      url: url,
      message: message,
      raisedAt: DateTime.now(),
    );
  }

  void clear() => state = null;
}
