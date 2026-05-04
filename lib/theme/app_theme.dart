import 'package:flutter/material.dart';

// Accent color presets — PSO2-inspired palette
class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

class AppTheme {
  // ── Accent presets ─────────────────────────────────────────────
  static const List<AccentPreset> accentPresets = [
    AccentPreset('Cyan',    Color(0xFF00B4D8)),
    AccentPreset('Azure',   Color(0xFF3B82F6)),
    AccentPreset('Purple',  Color(0xFFBC8CFF)),
    AccentPreset('Gold',    Color(0xFFFFC107)),
    AccentPreset('Green',   Color(0xFF3FB950)),
    AccentPreset('Coral',   Color(0xFFFF7B72)),
  ];

  // Active accent — defaults to Cyan, can be changed in Settings
  static Color _accent = const Color(0xFF00B4D8);
  static Color get accent => _accent;

  static void setAccent(Color color) {
    _accent = color;
  }

  // ── Base colors (never change) ─────────────────────────────────
  static const Color bgDark    = Color(0xFF0D1117);
  static const Color bgCard    = Color(0xFF161B22);
  static const Color bgSurface = Color(0xFF1C2128);
  static const Color accentGold      = Color(0xFFFFC107);
  static const Color textPrimary     = Color(0xFFE6EDF3);
  static const Color textSecondary   = Color(0xFF8B949E);
  static const Color borderColor     = Color(0xFF30363D);

  // ── Race colors ────────────────────────────────────────────────
  static const Color humanColor  = Color(0xFF58A6FF);
  static const Color newmanColor = Color(0xFFBC8CFF);
  static const Color deumanColor = Color(0xFFFF7B72);
  static const Color castColor   = Color(0xFF3FB950);

  // ── Theme builder ──────────────────────────────────────────────
  static ThemeData buildTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentGold,
        surface: bgSurface,
        onPrimary: bgDark,
        onSecondary: bgDark,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCard,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: accentColor.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: accentColor, fontSize: 12);
          }
          return const TextStyle(color: textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentColor);
          }
          return const IconThemeData(color: textSecondary);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
      ),
    );
  }

  // Convenience getter using current accent
  static ThemeData get darkTheme => buildTheme(_accent);

  static Color raceColor(String race) {
    switch (race.toLowerCase()) {
      case 'human':  return humanColor;
      case 'newman': return newmanColor;
      case 'deuman': return deumanColor;
      case 'cast':   return castColor;
      default:       return textSecondary;
    }
  }
}
