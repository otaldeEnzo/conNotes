import 'package:flutter/material.dart';

/// Tokens Oficiais do Design System `moscaro-v2`
/// Atualizado com paleta STEM de alta vivacidade e espectro de presets.
class MoscaroTokens {
  // Cores Oficiais de Fundo
  static const Color backgroundDeep = Color(0xFF0C243B);
  static const Color backgroundSurface = Color(0xFF060D14);
  
  // Vidro Líquido Translúcido (Moscaro v2 ~6% opacidade)
  static const Color glassWhite = Color(0x0FFFFFFF); 
  
  // Bordas de Brilho & Acentos
  static const Color borderGlow = Color(0x26FFFFFF); // ~15% opacity
  static const Color borderGlowActive = Color(0x6600E1FF); // Ciano neon ativo
  
  // Cores Aurora / STEM Oficiais
  static const Color auroraBlue = Color(0xFF00E1FF); // Ciano Neon STEM oficial
  static const Color auroraPurple = Color(0xFFA855F7); // Roxo Elétrico
  static const Color auroraPink = Color(0xFFFF007A); // Rosa Choque
  static const Color auroraGreen = Color(0xFF10B981); // Verde Menta
  static const Color auroraAmber = Color(0xFFF59E0B); // Laranja Âmbar

  // Lista padrão de cores rápidas STEM
  static const List<Color> stemPalette = [
    Colors.white,
    Color(0xFF00E1FF),
    Color(0xFFA855F7),
    Color(0xFFFF007A),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  // Desfoque e Sombras
  static const double blurSigma = 35.0;

  // Raios dos Cantos
  static const double radiusPanel = 24.0;
  static const double radiusPill = 30.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 20.0;

  // Espessuras de Borda
  static const double borderWidthSubtle = 1.2;
  static const double borderWidthAurora = 1.8;

  // Parâmetros do Canvas & Glow
  static const double mouseGlowRadius = 120.0;
}