import 'package:flutter/material.dart';
import '../models/character_data.dart';
import '../widgets/tier_border.dart';

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
  static void setAccent(Color color) => _accent = color;

  // ── Background presets ────────────────────────────────────────
  static const List<AccentPreset> bgPresets = [
    AccentPreset('Midnight', Color(0xFF0D1117)),
    AccentPreset('Void',     Color(0xFF0D0D0D)),
    AccentPreset('Navy',     Color(0xFF0A0F1C)),
    AccentPreset('Dusk',     Color(0xFF110D1C)),
    AccentPreset('Grove',    Color(0xFF0A110C)),
    AccentPreset('Ember',    Color(0xFF140A0A)),
    AccentPreset('Pearl',    Color(0xFFF6F8FA)),
    AccentPreset('Ivory',    Color(0xFFFFFBF0)),
    AccentPreset('Mist',     Color(0xFFEFF1F5)),
    AccentPreset('Petal',    Color(0xFFFFF0F3)),
    AccentPreset('Sage',     Color(0xFFF0F4EF)),
    AccentPreset('Slate',    Color(0xFFF0F4F8)),
  ];

  // Active bg base — derived colors computed via HSL lightness steps
  static Color _bgBase = const Color(0xFF0D1117);
  static Color get bgBase => _bgBase;
  static void setBgBase(Color color) => _bgBase = color;

  static bool get isLight =>
      ThemeData.estimateBrightnessForColor(_bgBase) == Brightness.light;

  static Color get bgDark => _bgBase;
  static Color get bgCard {
    final hsl = HSLColor.fromColor(_bgBase);
    final delta = isLight ? -0.04 : 0.04;
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }
  static Color get bgSurface {
    final hsl = HSLColor.fromColor(_bgBase);
    final delta = isLight ? -0.07 : 0.07;
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  static const Color accentGold      = Color(0xFFFFC107);
  static Color get textPrimary =>
      isLight ? const Color(0xFF24292F) : const Color(0xFFE6EDF3);
  static Color get textSecondary =>
      isLight ? const Color(0xFF57606A) : const Color(0xFF8B949E);
  static Color get borderColor =>
      isLight ? const Color(0xFFD0D7DE) : const Color(0xFF30363D);

  // ── Race colors ────────────────────────────────────────────────
  static const Color humanColor  = Color(0xFF58A6FF);
  static const Color newmanColor = Color(0xFFBC8CFF);
  static const Color deumanColor = Color(0xFFFF7B72);
  static const Color castColor   = Color(0xFF3FB950);

  // ── Theme builder ──────────────────────────────────────────────
  static ThemeData buildTheme(Color accentColor) {
    final light = isLight;
    final tp = textPrimary;
    final ts = textSecondary;
    final bc = borderColor;
    return ThemeData(
      brightness: light ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: (light ? ColorScheme.light : ColorScheme.dark)(
        primary: accentColor,
        secondary: accentGold,
        surface: bgSurface,
        onPrimary: light ? tp : bgDark,
        onSecondary: light ? tp : bgDark,
        onSurface: tp,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgCard,
        foregroundColor: tp,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tp,
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
          side: BorderSide(color: bc, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: bc),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: bc),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        labelStyle: TextStyle(color: ts),
        hintStyle: TextStyle(color: ts),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: light ? tp : bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        labelStyle: TextStyle(color: tp, fontSize: 12),
        side: BorderSide(color: bc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: accentColor.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: accentColor, fontSize: 12);
          }
          return TextStyle(color: ts, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentColor);
          }
          return IconThemeData(color: ts);
        }),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: tp, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: tp, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: tp, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: tp),
        bodyLarge: TextStyle(color: tp),
        bodyMedium: TextStyle(color: ts),
        labelLarge: TextStyle(color: tp),
      ),
    );
  }

  // ── Tier border effects ────────────────────────────────────────

  static const Map<CharacterTier, List<TierBorderEffect>> tierEffectOptions = {
    CharacterTier.s: [
      TierBorderEffect.rainbow,
      TierBorderEffect.auroraPulse,
      TierBorderEffect.prismaticSparkle,
      TierBorderEffect.holographic,
    ],
    CharacterTier.a: [
      TierBorderEffect.shimmer,
      TierBorderEffect.pulseGlow,
      TierBorderEffect.doubleRing,
      TierBorderEffect.molten,
    ],
    CharacterTier.b: [
      TierBorderEffect.shimmer,
      TierBorderEffect.doubleRing,
      TierBorderEffect.electricArc,
      TierBorderEffect.particleSparks,
    ],
    CharacterTier.c: [
      TierBorderEffect.shimmer,
      TierBorderEffect.dashedRotation,
      TierBorderEffect.plasmaWave,
      TierBorderEffect.emberGlow,
    ],
    CharacterTier.d: [
      TierBorderEffect.none,
      TierBorderEffect.subtlePulse,
      TierBorderEffect.dimFlicker,
    ],
  };

  static Map<CharacterTier, TierBorderEffect> _tierEffects = {
    CharacterTier.s: TierBorderEffect.rainbow,
    CharacterTier.a: TierBorderEffect.shimmer,
    CharacterTier.b: TierBorderEffect.shimmer,
    CharacterTier.c: TierBorderEffect.shimmer,
    CharacterTier.d: TierBorderEffect.none,
  };

  static TierBorderEffect effectForTier(CharacterTier tier) {
    final saved = _tierEffects[tier] ?? TierBorderEffect.none;
    final pool = tierEffectOptions[tier];
    if (pool == null || pool.contains(saved)) return saved;
    return pool.first;
  }

  static void setTierEffect(CharacterTier tier, TierBorderEffect effect) =>
      _tierEffects[tier] = effect;

  static Map<CharacterTier, TierBorderEffect> get tierEffects =>
      Map.unmodifiable(_tierEffects);

  static void loadTierEffects(Map<CharacterTier, TierBorderEffect> effects) =>
      _tierEffects = Map.of(effects);

  static final tierEffectNotifier = ValueNotifier<int>(0);

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
