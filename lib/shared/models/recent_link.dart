import 'dart:convert';

class RecentLink {
  final int? id;
  final String url;
  final String title;
  final String? thumbnail;
  final String formatsJson; // JSON string of formats
  final String videoInfoJson; // JSON string of video info
  final DateTime createdAt;

  const RecentLink({
    this.id,
    required this.url,
    required this.title,
    this.thumbnail,
    required this.formatsJson,
    required this.videoInfoJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnail': thumbnail,
      'formatsJson': formatsJson,
      'videoInfoJson': videoInfoJson,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RecentLink.fromMap(Map<String, dynamic> map) {
    return RecentLink(
      id: map['id'] as int?,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnail: map['thumbnail'] as String?,
      formatsJson: map['formatsJson'] as String,
      videoInfoJson: map['videoInfoJson'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  List<Map<String, dynamic>> getFormats() {
    final decoded = jsonDecode(formatsJson);
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [];
  }

  Map<String, dynamic> getVideoInfo() {
    return jsonDecode(videoInfoJson) as Map<String, dynamic>;
  }

  RecentLink copyWith({
    int? id,
    String? url,
    String? title,
    String? thumbnail,
    String? formatsJson,
    String? videoInfoJson,
    DateTime? createdAt,
  }) {
    return RecentLink(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      formatsJson: formatsJson ?? this.formatsJson,
      videoInfoJson: videoInfoJson ?? this.videoInfoJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
