import 'package:flutter/material.dart';

/// Brand colors shared by both themes.
class Brand {
  Brand._();
  static const amber = Color(0xFFF5A524);
  static const onAmber = Color(0xFF1A1206);
  static const teal = Color(0xFF5CD6C0);
  static const ink = Color(0xFF0E141B);
  static const male = Color(0xFF7FB2FF);
  static const female = Color(0xFFFF9EC4);
  static const recording = Color(0xFFE5484D);
}

/// Extra semantic colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface1,
    required this.surface2,
    required this.line,
    required this.muted,
    required this.accentText,
    required this.logoBackground,
  });

  final Color surface1;
  final Color surface2;
  final Color line;
  final Color muted;
  final Color accentText;
  final Color logoBackground;

  static const dark = AppColors(
    surface1: Color(0xFF17202A),
    surface2: Color(0xFF1F2A36),
    line: Color(0xFF2A3644),
    muted: Color(0xFF9AA8B6),
    accentText: Brand.amber,
    logoBackground: Color(0xFF1F2A36),
  );

  static const light = AppColors(
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1F5),
    line: Color(0xFFDCE2EA),
    muted: Color(0xFF5B6673),
    accentText: Color(0xFF9A5B00),
    logoBackground: Brand.ink,
  );

  @override
  AppColors copyWith({
    Color? surface1,
    Color? surface2,
    Color? line,
    Color? muted,
    Color? accentText,
    Color? logoBackground,
  }) =>
      AppColors(
        surface1: surface1 ?? this.surface1,
        surface2: surface2 ?? this.surface2,
        line: line ?? this.line,
        muted: muted ?? this.muted,
        accentText: accentText ?? this.accentText,
        logoBackground: logoBackground ?? this.logoBackground,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      logoBackground: Color.lerp(logoBackground, other.logoBackground, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ext = dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.amber,
    brightness: brightness,
  ).copyWith(
    primary: Brand.amber,
    onPrimary: Brand.onAmber,
    secondary: Brand.teal,
    surface: dark ? Brand.ink : const Color(0xFFF6F7F9),
    onSurface: dark ? const Color(0xFFEEF2F6) : const Color(0xFF141A21),
    surfaceContainer: ext.surface1,
    surfaceContainerHigh: ext.surface2,
    outlineVariant: ext.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'BeVietnamPro',
    scaffoldBackgroundColor: scheme.surface,
    extensions: [ext],
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: ext.surface1,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: ext.line, space: 1, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
