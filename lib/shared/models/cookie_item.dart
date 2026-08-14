class CookieItem {
  final String id;
  final String name;
  final String content; // Cookie file content or path
  final DateTime createdAt;

  const CookieItem({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
  });

  CookieItem copyWith({
    String? id,
    String? name,
    String? content,
    DateTime? createdAt,
  }) {
    return CookieItem(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CookieItem.fromJson(Map<String, dynamic> json) {
    return CookieItem(
      id: json['id'] as String,
      name: json['name'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
