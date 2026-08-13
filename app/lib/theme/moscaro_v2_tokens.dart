import 'package:flutter/material.dart';

/// Tokens Oficiais do Design System `moscaro-v2`
/// Atualizado com parâmetros refinados de Glassmorphism e Glow.
class MoscaroTokens {
  // Cores Oficiais
  static const Color backgroundDeep = Color(0xFF09273C);
  static const Color backgroundSurface = Color(0xFF0A0B0D);
  
  // Atualizado: Opacidade reduzida (cerca de 6%) para dar o aspecto de reflexo sutil no vidro
  static const Color glassWhite = Color(0x0FFFFFFF); 
  
  // Atualizado: Borda sutil ligeiramente mais refinada
  static const Color borderGlow = Color(0x26FFFFFF); // ~15% opacity
  
  static const Color auroraBlue = Color(0xFF3B82F6); // Corrigido para 8 dígitos hexadecimais
  static const Color auroraPurple = Color(0xFF8B5CF6);
  static const Color auroraPink = Color(0xFFFF007A);

  // Atualizado: Aumentado para 30.0 para criar um desfoque mais intenso e profundo (estilo Google Stitch)
  static const double blurSigma = 35.0;

  // Raios dos Cantos
  static const double radiusPanel = 24.0;
  static const double radiusPill = 30.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 20.0;

  // Espessuras de Borda
  static const double borderWidthSubtle = 1.2;
  static const double borderWidthAurora = 1.8;

  // Parâmetros do Canvas & Glow (Aumentado o raio para espalhar mais o brilho difuso)
  static const double mouseGlowRadius = 120.0;
}