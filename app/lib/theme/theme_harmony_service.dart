import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/theme_models.dart';

/// Serviço Matemático de Teoria das Cores & Harmonia STEM (HSL Color Engine).
class ThemeHarmonyService {
  ThemeHarmonyService._();

  /// Gera um tema matematicamente equilibrado a partir de uma cor de fundo e um acento primário
  static ThemeDefinition generateHarmoniousTheme({
    required Color baseBg,
    required Color primaryAccent,
    String name = 'Tema Harmônico',
  }) {
    final bgHsl = HSLColor.fromColor(baseBg);
    final accentHsl = HSLColor.fromColor(primaryAccent);
    final isLight = bgHsl.lightness > 0.45;

    // 1. Fundo Deep & Surface preservando a cor base escolhida pelo usuário
    final backgroundSurface = baseBg;
    final backgroundDeep = isLight
        ? bgHsl.withLightness((bgHsl.lightness - 0.08).clamp(0.0, 1.0)).toColor()
        : bgHsl.withLightness((bgHsl.lightness - 0.03).clamp(0.01, 1.0)).toColor();

    // 2. Acento Secundário (Shift Harmônico de 130° na roda de cores)
    final secHue = (accentHsl.hue + 130.0) % 360.0;
    final accentSecondary = HSLColor.fromAHSL(
      1.0,
      secHue,
      accentHsl.saturation.clamp(0.60, 0.95),
      isLight ? 0.45 : 0.65,
    ).toColor();

    // 3. Película de Vidro Translúcida Moscaro (~15% opacidade baseada no surface)
    final glassColor = isLight
        ? Colors.white.withValues(alpha: 0.25)
        : backgroundSurface.withValues(alpha: 0.15);

    // 4. Dot Grid & Glow contrastantes
    final dotGridColor = primaryAccent.withValues(alpha: isLight ? 0.35 : 0.22);
    final mouseGlowColor = primaryAccent;
    final borderGlowColor = primaryAccent.withValues(alpha: isLight ? 0.40 : 0.30);

    // 5. Paleta Rápida de 6 Canetas STEM
    final stemPalette = generateStemPaletteFromAccent(primaryAccent, isLight: isLight);

    // 6. Gradiente Multi-Paradas Harmônico (4 a 5 Paradas)
    final gradientColors = generateGradientStops(backgroundSurface, primaryAccent, accentSecondary, count: 5);

    return ThemeDefinition(
      preset: AppThemePreset.custom,
      customId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      isCustom: true,
      name: name,
      bgMode: CanvasBackgroundMode.gradient,
      backgroundDeep: backgroundDeep,
      backgroundSurface: backgroundSurface,
      gradientColors: gradientColors,
      accentPrimary: primaryAccent,
      accentSecondary: accentSecondary,
      dotGridColor: dotGridColor,
      mouseGlowColor: mouseGlowColor,
      glassColor: glassColor,
      borderGlowColor: borderGlowColor,
      stemPalette: stemPalette,
    );
  }

  /// Gera uma sequência harmônica de N paradas de cor para o gradiente de fundo
  static List<Color> generateGradientStops(Color baseBg, Color accent1, Color accent2, {int count = 5}) {
    final bgHsl = HSLColor.fromColor(baseBg);
    final a1Hsl = HSLColor.fromColor(accent1);
    final a2Hsl = HSLColor.fromColor(accent2);
    final isLight = bgHsl.lightness > 0.45;

    final List<Color> stops = [];
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final targetHue = t < 0.5
          ? (bgHsl.hue + (2 * t) * (a1Hsl.hue - bgHsl.hue))
          : (a1Hsl.hue + (2 * (t - 0.5)) * (a2Hsl.hue - a1Hsl.hue));
      final hue = targetHue % 360.0;
      final lightnessDelta = isLight
          ? -(math.sin(t * math.pi) * 0.08)
          : (math.sin(t * math.pi) * 0.07);
      final lightness = (bgHsl.lightness + lightnessDelta).clamp(0.02, 0.98);
      final saturation = (bgHsl.saturation + (t * 0.20)).clamp(0.05, 0.95);
      stops.add(HSLColor.fromAHSL(1.0, hue < 0 ? hue + 360 : hue, saturation, lightness).toColor());
    }
    return stops;
  }

  /// Gera uma paleta STEM de 6 canetas vivas a partir do acento primário
  static List<Color> generateStemPaletteFromAccent(Color primaryAccent, {bool isLight = false}) {
    final hsl = HSLColor.fromColor(primaryAccent);
    final h = hsl.hue;

    return [
      isLight ? const Color(0xFF0F172A) : Colors.white,
      primaryAccent,
      HSLColor.fromAHSL(1.0, (h + 120.0) % 360.0, 0.90, isLight ? 0.45 : 0.65).toColor(),
      HSLColor.fromAHSL(1.0, (h + 240.0) % 360.0, 0.90, isLight ? 0.45 : 0.65).toColor(),
      HSLColor.fromAHSL(1.0, (h + 45.0) % 360.0, 0.92, isLight ? 0.42 : 0.62).toColor(),
      HSLColor.fromAHSL(1.0, (h + 180.0) % 360.0, 0.90, isLight ? 0.40 : 0.60).toColor(),
    ];
  }

  /// Gera um tema aleatório surpreendente inspirado em estética Dark STEM / Cyberpunk
  static ThemeDefinition generateRandomTheme() {
    final random = math.Random();

    // Sementes temáticas de alta vivacidade
    final themes = [
      {'name': 'Aurora Quântica', 'bgHue': 210.0, 'accentHue': 185.0},
      {'name': 'Matriz Esmeralda', 'bgHue': 150.0, 'accentHue': 155.0},
      {'name': 'Pulso Ultravioleta', 'bgHue': 275.0, 'accentHue': 310.0},
      {'name': 'Fusão Solar', 'bgHue': 25.0, 'accentHue': 40.0},
      {'name': 'Deep Cyberpunk', 'bgHue': 260.0, 'accentHue': 340.0},
      {'name': 'Cobalto Técnico', 'bgHue': 225.0, 'accentHue': 200.0},
      {'name': 'Neon Ruby', 'bgHue': 345.0, 'accentHue': 355.0},
    ];

    final pick = themes[random.nextInt(themes.length)];
    final bgHue = pick['bgHue'] as double;
    final accentHue = pick['accentHue'] as double;

    final baseBg = HSLColor.fromAHSL(1.0, bgHue, 0.35, 0.06).toColor();
    final primaryAccent = HSLColor.fromAHSL(1.0, accentHue, 0.95, 0.60).toColor();

    return generateHarmoniousTheme(
      baseBg: baseBg,
      primaryAccent: primaryAccent,
      name: '${pick['name']} #${random.nextInt(900) + 100}',
    );
  }
}
