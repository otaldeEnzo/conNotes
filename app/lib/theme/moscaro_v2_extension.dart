import 'dart:ui';
import 'package:flutter/material.dart';
import 'moscaro_v2_tokens.dart';

/// Design System Centralizado `moscaro-v2`
/// Extensão universal aplicável a qualquer componente Flutter.
/// Atualizado com a sombra externa difusa preta para efeito de flutuação 3D.
extension MoscaroV2Extension on Widget {
  Widget moscaroV2({
    double borderRadius = MoscaroTokens.radiusPanel,
    double blurSigma = MoscaroTokens.blurSigma,
    Color backgroundColor = MoscaroTokens.glassWhite,
    Color borderColor = MoscaroTokens.borderGlow,
    double borderWidth = MoscaroTokens.borderWidthSubtle,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              // Sombra externa difusa preta com deslocamento para fazer a pílula flutuar no espaço 3D
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: this,
        ),
      ),
    );
  }
}
