import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color surfaceElevated;
  final Color chip;
  final Color chipSelected;
  final Color panelStroke;
  final Color ambientPrimary;
  final Color ambientSecondary;
  final Color ambientSuccess;
  final Color text;
  final Color mutedText;
  final Color divider;
  final Color connected;
  final Color disconnected;

  const AppPalette({
    required this.background,
    required this.card,
    required this.surfaceElevated,
    required this.chip,
    required this.chipSelected,
    required this.panelStroke,
    required this.ambientPrimary,
    required this.ambientSecondary,
    required this.ambientSuccess,
    required this.text,
    required this.mutedText,
    required this.divider,
    required this.connected,
    required this.disconnected,
  });

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? surfaceElevated,
    Color? chip,
    Color? chipSelected,
    Color? panelStroke,
    Color? ambientPrimary,
    Color? ambientSecondary,
    Color? ambientSuccess,
    Color? text,
    Color? mutedText,
    Color? divider,
    Color? connected,
    Color? disconnected,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      chip: chip ?? this.chip,
      chipSelected: chipSelected ?? this.chipSelected,
      panelStroke: panelStroke ?? this.panelStroke,
      ambientPrimary: ambientPrimary ?? this.ambientPrimary,
      ambientSecondary: ambientSecondary ?? this.ambientSecondary,
      ambientSuccess: ambientSuccess ?? this.ambientSuccess,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      divider: divider ?? this.divider,
      connected: connected ?? this.connected,
      disconnected: disconnected ?? this.disconnected,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      background: Color.lerp(background, other.background, t) ?? background,
      card: Color.lerp(card, other.card, t) ?? card,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      chip: Color.lerp(chip, other.chip, t) ?? chip,
      chipSelected:
          Color.lerp(chipSelected, other.chipSelected, t) ?? chipSelected,
      panelStroke: Color.lerp(panelStroke, other.panelStroke, t) ?? panelStroke,
      ambientPrimary:
          Color.lerp(ambientPrimary, other.ambientPrimary, t) ?? ambientPrimary,
      ambientSecondary:
          Color.lerp(ambientSecondary, other.ambientSecondary, t) ??
              ambientSecondary,
      ambientSuccess:
          Color.lerp(ambientSuccess, other.ambientSuccess, t) ?? ambientSuccess,
      text: Color.lerp(text, other.text, t) ?? text,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      connected: Color.lerp(connected, other.connected, t) ?? connected,
      disconnected:
          Color.lerp(disconnected, other.disconnected, t) ?? disconnected,
    );
  }
}

class AppTheme {
  static const Color connectedColor = Color(0xFF29D55B);
  static const Color disconnectedColor = Color(0xFFFF2D55);
  static const Color chipSelectedColor = Color(0xFF2079FF);

  static const AppPalette _darkPalette = AppPalette(
    background: Color(0xFF06080E),
    card: Color(0xFF171A22),
    surfaceElevated: Color(0xFF1D212B),
    chip: Color(0xFF262B36),
    chipSelected: chipSelectedColor,
    panelStroke: Color(0x16FFFFFF),
    ambientPrimary: Color(0xFF4F80FF),
    ambientSecondary: Color(0xFFFF4C88),
    ambientSuccess: Color(0xFF21E59B),
    text: Color(0xFFFFFFFF),
    mutedText: Color(0xB3FFFFFF),
    divider: Color(0x14FFFFFF),
    connected: connectedColor,
    disconnected: disconnectedColor,
  );

  static const AppPalette _lightPalette = AppPalette(
    background: Color(0xFFF6F7FA),
    card: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDEFF4),
    chip: Color(0xFFE6E9F0),
    chipSelected: chipSelectedColor,
    panelStroke: Color(0x12000000),
    ambientPrimary: Color(0xFF5B7BFF),
    ambientSecondary: Color(0xFFFF5F91),
    ambientSuccess: Color(0xFF26C88A),
    text: Color(0xFF101114),
    mutedText: Color(0xB3101114),
    divider: Color(0x12000000),
    connected: connectedColor,
    disconnected: disconnectedColor,
  );

  static ThemeData get darkTheme =>
      _buildTheme(palette: _darkPalette, brightness: Brightness.dark);

  static ThemeData get lightTheme =>
      _buildTheme(palette: _lightPalette, brightness: Brightness.light);

  static AppPalette colors(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? _darkPalette;
  }

  static BoxDecoration glassPanel(
    BuildContext context, {
    required double radius,
    Color? baseColor,
    Color? glowColor,
    BoxShape shape = BoxShape.rectangle,
  }) {
    final palette = colors(context);
    final brightness = Theme.of(context).brightness;
    final base = baseColor ?? palette.card;
    final topTint = Color.lerp(
          base,
          Colors.white,
          brightness == Brightness.dark ? 0.035 : 0.02,
        ) ??
        base;
    final bottomTint = Color.lerp(
          base,
          palette.background,
          brightness == Brightness.dark ? 0.10 : 0.04,
        ) ??
        base;

    return BoxDecoration(
      shape: shape,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          topTint,
          base,
          bottomTint,
        ],
      ),
      borderRadius:
          shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      border: Border.all(color: palette.panelStroke),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.18 : 0.05,
          ),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withValues(
              alpha: brightness == Brightness.dark ? 0.08 : 0.04,
            ),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 6),
          ),
      ],
    );
  }

  static ThemeMode themeModeFrom(String value) {
    switch (value.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static ThemeData _buildTheme({
    required AppPalette palette,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.chipSelected,
      brightness: brightness,
    ).copyWith(
      primary: palette.chipSelected,
      onPrimary: Colors.white,
      secondary: palette.connected,
      onSecondary: Colors.white,
      error: palette.disconnected,
      onError: Colors.white,
      surface: palette.card,
      onSurface: palette.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: '.SF Pro Text',
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: palette.text,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: palette.text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: palette.text,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: palette.mutedText,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.text),
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(
          color: palette.text,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      extensions: [
        palette,
      ],
    );
  }
}
