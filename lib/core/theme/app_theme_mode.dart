import 'package:flutter/material.dart';

enum AppThemeMode {
  light,
  dark,
  darkAmoled,
  system;

  static AppThemeMode fromString(String value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'darkAmoled':
        return AppThemeMode.darkAmoled;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}

extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.darkAmoled:
        return 'Dark AMOLED';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  String get description {
    switch (this) {
      case AppThemeMode.light:
        return 'Bright theme with light colors';
      case AppThemeMode.dark:
        return 'Dark theme with gray background';
      case AppThemeMode.darkAmoled:
        return 'Pure black for AMOLED screens';
      case AppThemeMode.system:
        return 'Follow system theme';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.wb_sunny;
      case AppThemeMode.dark:
        return Icons.nights_stay;
      case AppThemeMode.darkAmoled:
        return Icons.brightness_2;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  Color getPreviewColor(BuildContext context) {
    switch (this) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.dark:
        return const Color(0xFF1C1B1F);
      case AppThemeMode.darkAmoled:
        return Colors.black;
      case AppThemeMode.system:
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1B1F)
            : Colors.white;
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.darkAmoled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String toStorageString() {
    return toString().split('.').last;
  }
}
