class CookieItem {
  final String id;
  final String name;

  /// Netscape cookie data is kept in memory only. It is encrypted at rest by
  /// [CookieStorageService] and is deliberately excluded from JSON metadata.
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CookieItem({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  CookieItem copyWith({
    String? id,
    String? name,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CookieItem(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Non-sensitive account metadata safe to keep in the settings index.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CookieItem.fromJson(
    Map<String, dynamic> json, {
    required String content,
  }) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return CookieItem(
      id: json['id'] as String,
      name: json['name'] as String,
      content: content,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}
