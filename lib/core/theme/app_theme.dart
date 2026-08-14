import 'package:flutter/material.dart';

enum AppThemeColor {
  materialYou,
  violet,
  blue,
  teal,
  green,
  orange,
  pink,
  red,
  indigo,
}

/// Material 3 Expressive theme shared by compact and large-screen layouts.
class AppTheme {
  const AppTheme._();

  static const primaryColor = Color(0xFF6750A4);
  static const secondaryColor = Color(0xFF625B71);
  static const tertiaryColor = Color(0xFF7D5260);

  static const _seedColors = <AppThemeColor, Color>{
    AppThemeColor.materialYou: Color(0xFF6750A4),
    AppThemeColor.violet: Color(0xFF7455C6),
    AppThemeColor.blue: Color(0xFF0067C0),
    AppThemeColor.teal: Color(0xFF006B66),
    AppThemeColor.green: Color(0xFF3C6D24),
    AppThemeColor.orange: Color(0xFF8C5000),
    AppThemeColor.pink: Color(0xFFA33E69),
    AppThemeColor.red: Color(0xFFBA1A1A),
    AppThemeColor.indigo: Color(0xFF4D5BC7),
  };

  static String getThemeColorName(AppThemeColor color) => switch (color) {
    AppThemeColor.materialYou => 'Material You',
    AppThemeColor.violet => 'Violet',
    AppThemeColor.blue => 'Ocean Blue',
    AppThemeColor.teal => 'Teal',
    AppThemeColor.green => 'Forest Green',
    AppThemeColor.orange => 'Orange',
    AppThemeColor.pink => 'Rose Pink',
    AppThemeColor.red => 'Red',
    AppThemeColor.indigo => 'Indigo',
  };

  static ThemeData lightTheme([
    AppThemeColor color = AppThemeColor.materialYou,
  ]) {
    return fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: _seedColors[color]!,
        brightness: Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      ),
    );
  }

  static ThemeData darkTheme([
    AppThemeColor color = AppThemeColor.materialYou,
  ]) {
    return fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: _seedColors[color]!,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      ),
    );
  }

  static ThemeData darkAmoledTheme([
    AppThemeColor color = AppThemeColor.materialYou,
  ]) {
    final generated = ColorScheme.fromSeed(
      seedColor: _seedColors[color]!,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    return fromColorScheme(
      generated.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF080808),
        surfaceContainer: const Color(0xFF0D0D0D),
        surfaceContainerHigh: const Color(0xFF151515),
        surfaceContainerHighest: const Color(0xFF1C1C1C),
      ),
      amoled: true,
    );
  }

  static ThemeData fromColorScheme(ColorScheme scheme, {bool amoled = false}) {
    final radius = BorderRadius.circular(24);
    final compactRadius = BorderRadius.circular(18);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        useIndicator: true,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder()),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: const StadiumBorder(),
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: ShapeDecoration(
          color: scheme.secondaryContainer,
          shape: const StadiumBorder(),
        ),
        labelColor: scheme.onSecondaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: scheme.inverseSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      extensions: const <ThemeExtension<dynamic>>[],
    ).copyWith(scaffoldBackgroundColor: amoled ? Colors.black : scheme.surface);
  }
}
