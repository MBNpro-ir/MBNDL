import 'yt_dlp_settings.dart';

class CustomPreset {
  final String id;
  final String name;
  final YtDlpSettings settings;
  final DateTime createdAt;
  final bool isBuiltIn;

  const CustomPreset({
    required this.id,
    required this.name,
    required this.settings,
    required this.createdAt,
    this.isBuiltIn = false,
  });

  CustomPreset copyWith({
    String? id,
    String? name,
    YtDlpSettings? settings,
    DateTime? createdAt,
    bool? isBuiltIn,
  }) {
    return CustomPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isBuiltIn': isBuiltIn,
  };

  factory CustomPreset.fromJson(Map<String, dynamic> json) => CustomPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    settings: YtDlpSettings.fromJson(json['settings'] as Map<String, dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  );

  // Built-in presets
  static CustomPreset defaultPreset() => CustomPreset(
    id: 'default',
    name: 'Default',
    settings: YtDlpSettings.defaultPreset(),
    createdAt: DateTime.now(),
    isBuiltIn: true,
  );

  static CustomPreset speedPreset() => CustomPreset(
    id: 'speed',
    name: 'Fast Download',
    settings: YtDlpSettings.speedPreset(),
    createdAt: DateTime.now(),
    isBuiltIn: true,
  );

  static CustomPreset resilientPreset() => CustomPreset(
    id: 'resilient',
    name: 'Unstable Connection',
    settings: YtDlpSettings.resilientPreset(),
    createdAt: DateTime.now(),
    isBuiltIn: true,
  );

  static CustomPreset gentleYouTubePreset() => CustomPreset(
    id: 'gentle_youtube',
    name: 'Gentle YouTube',
    settings: YtDlpSettings.gentleYouTubePreset(),
    createdAt: DateTime.now(),
    isBuiltIn: true,
  );

  static CustomPreset limitedBandwidthPreset() => CustomPreset(
    id: 'limited_bandwidth',
    name: 'Limited Bandwidth',
    settings: YtDlpSettings.limitedBandwidthPreset(),
    createdAt: DateTime.now(),
    isBuiltIn: true,
  );

  static List<CustomPreset> builtInPresets() => [
    defaultPreset(),
    speedPreset(),
    resilientPreset(),
    gentleYouTubePreset(),
    limitedBandwidthPreset(),
  ];
}
