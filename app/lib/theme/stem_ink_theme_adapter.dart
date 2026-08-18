import 'package:flutter/material.dart';

/// Adaptador Inteligente de Cores de Tinta STEM para Alternância entre Temas Claros e Escuros.
class StemInkThemeAdapter {
  StemInkThemeAdapter._();

  /// Adapta dinamicamente uma cor de traço para garantir contraste máximo e legibilidade impecável no tema atual.
  static Color adaptStrokeColor(Color originalColor, {required bool isLightTheme}) {
    final hsl = HSLColor.fromColor(originalColor);
    final isAchromatic = hsl.saturation < 0.18;

    if (isLightTheme) {
      // 1. Fundo Claro (Luminância > 0.45):
      if (isAchromatic) {
        // Branco puro e quase branco -> Grafite Escuro Profundo (#0F172A)
        if (hsl.lightness > 0.88) {
          return const Color(0xFF0F172A);
        }
        // Cinzas claros -> Espelhamento de luminosidade para cinzas escuros/chumbo de alto contraste
        if (hsl.lightness > 0.45) {
          final invertedLightness = ((1.0 - hsl.lightness) * 0.75 + 0.10).clamp(0.10, 0.45);
          return hsl.withLightness(invertedLightness).toColor();
        }
        // Cinzas já escuros permanecem nítidos
        return originalColor;
      } else {
        // Cores cromáticas: Evita que tons muito claros (ex: amarelo pálido) sumam no branco
        if (hsl.lightness > 0.82) {
          return hsl.withLightness(0.55).toColor();
        }
        return originalColor;
      }
    } else {
      // 2. Fundo Escuro (Luminância <= 0.45):
      if (isAchromatic) {
        // Preto puro e quase preto -> Branco Puro (#FFFFFF)
        if (hsl.lightness < 0.12) {
          return Colors.white;
        }
        // Cinzas muito escuros -> Espelhamento para cinzas claros legíveis
        if (hsl.lightness < 0.45) {
          final invertedLightness = ((1.0 - hsl.lightness) * 0.75 + 0.20).clamp(0.55, 0.92);
          return hsl.withLightness(invertedLightness).toColor();
        }
        return originalColor;
      } else {
        // Cores cromáticas: Evita que tons muito escuros sumam no preto
        if (hsl.lightness < 0.18) {
          return hsl.withLightness(0.55).toColor();
        }
        return originalColor;
      }
    }
  }
}
