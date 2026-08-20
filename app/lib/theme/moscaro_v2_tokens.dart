import 'package:flutter/material.dart';
import '../models/theme_models.dart';

/// Tokens Oficiais do Design System `moscaro-v2`
/// Atualizado dinamicamente pelo MoscaroThemeController para suporte a temas escuros e claros (Light/Dark Mode).
class MoscaroTokens {
  // Cores Oficiais de Fundo
  static Color backgroundDeep = const Color(0xFF070B14);
  static Color backgroundSurface = const Color(0xFF0C1626);

  // Detecção Dinâmica de Tema Claro vs Escuro
  static bool get isLight => backgroundSurface.computeLuminance() > 0.45;

  // Vidro Líquido Translúcido (Película Temática Moscaro v2)
  static const Color glassWhite = Color(0x0FFFFFFF);
  static Color glassTint = const Color(0x990A1424);

  // Bordas de Brilho & Acentos
  static const Color borderGlow = Color(0x26FFFFFF);
  static Color borderGlowActive = const Color(0x6600E1FF);

  // Cores Aurora / STEM Oficiais (Atualizadas dinamicamente pelo tema ativo)
  static Color auroraBlue = const Color(0xFF00E1FF); // Acento Primário
  static Color auroraPurple = const Color(0xFFA855F7); // Acento Secundário
  static const Color auroraPink = Color(0xFFFF007A); // Rosa Choque
  static const Color auroraGreen = Color(0xFF10B981); // Verde Menta
  static const Color auroraAmber = Color(0xFFF59E0B); // Laranja Âmbar

  // Tipografia e Contraste Adaptativo do Canvas (WCAG AAA)
  static Color canvasTextColor = Colors.white;
  static Color canvasSubtextColor = Colors.white70;

  // Tokens de Texto e Ícones Globais Adaptativos ao Tema
  static Color get textPrimary => isLight ? Colors.black : Colors.white;
  static Color get textSecondary => isLight ? Colors.black87 : const Color(0xB3FFFFFF);
  static Color get textMuted => isLight ? Colors.black54 : const Color(0x80FFFFFF);
  static Color get iconInactive => isLight ? Colors.black87 : const Color(0xB3FFFFFF);
  static Color get borderSubtle => isLight ? Colors.black26 : const Color(0x1FFFFFFF);

  // Lista padrão de cores rápidas STEM (Alinhada ao tema ativo)
  static List<Color> stemPalette = [
    Colors.white,
    const Color(0xFF00E1FF),
    const Color(0xFFA855F7),
    const Color(0xFFFF007A),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
  ];

  // Desfoque e Sombras
  static double blurSigma = 35.0;

  // Presença Individual de Blur por Componente
  static bool enableSidebarBlur = true;
  static bool enableToolbarBlur = true;
  static bool enableSubBarsBlur = true;
  static bool enableModalsBlur = true;
  static bool enableInstrumentsBlur = true;
  static bool enableCardsBlur = true;

  // Raios dos Cantos
  static const double radiusPanel = 24.0;
  static const double radiusPill = 30.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 20.0;

  // Espessuras de Borda
  static const double borderWidthSubtle = 1.2;
  static const double borderWidthAurora = 1.8;

  // 5. Cores Específicas de Cards STEM (Callouts & Progresso)
  static Color calloutTipColor = const Color(0xFF00E1FF);
  static Color calloutTheoremColor = const Color(0xFFA855F7);
  static Color calloutWarningColor = const Color(0xFFF59E0B);
  static Color calloutConceptColor = const Color(0xFF10B981);
  static Color cardProgressColor = const Color(0xFF00E1FF);

  /// Atualiza todos os tokens centrais de cor com a definição do tema ativo
  static void applyTheme(ThemeDefinition theme) {
    backgroundDeep = theme.backgroundDeep;
    backgroundSurface = theme.backgroundSurface;
    auroraBlue = theme.accentPrimary;
    auroraPurple = theme.accentSecondary;
    borderGlowActive = theme.borderGlowColor;
    glassTint = theme.glassColor;
    stemPalette = List<Color>.from(theme.stemPalette);
    blurSigma = theme.blurSigma;
    canvasTextColor = theme.canvasTextColor;
    canvasSubtextColor = theme.canvasSubtextColor;
    enableSidebarBlur = theme.enableSidebarBlur;
    enableToolbarBlur = theme.enableToolbarBlur;
    enableSubBarsBlur = theme.enableSubBarsBlur;
    enableModalsBlur = theme.enableModalsBlur;
    enableInstrumentsBlur = theme.enableInstrumentsBlur;
    enableCardsBlur = theme.enableCardsBlur;
    calloutTipColor = theme.calloutTipColor;
    calloutTheoremColor = theme.calloutTheoremColor;
    calloutWarningColor = theme.calloutWarningColor;
    calloutConceptColor = theme.calloutConceptColor;
    cardProgressColor = theme.cardProgressColor;
  }
}