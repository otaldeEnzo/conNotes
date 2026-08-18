import 'dart:ui';
import 'package:flutter/material.dart';
import 'moscaro_v2_tokens.dart';

/// Design System Centralizado `moscaro-v2`
/// Extensão universal aplicável a qualquer componente Flutter com suporte a Dark & Light Glass.
extension MoscaroV2Extension on Widget {
  Widget moscaroV2({
    double borderRadius = MoscaroTokens.radiusPanel,
    double? blurSigma,
    bool enableBlur = true,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = MoscaroTokens.borderWidthSubtle,
    EdgeInsetsGeometry? padding,
  }) {
    final effectiveBlurSigma = blurSigma ?? MoscaroTokens.blurSigma;
    final double computedBlur = (enableBlur && effectiveBlurSigma > 0) ? effectiveBlurSigma : 0.0;
    final isLight = MoscaroTokens.isLight;

    final effectiveBgColor = backgroundColor ?? MoscaroTokens.glassTint;
    final effectiveBorderColor = borderColor ?? (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: computedBlur, sigmaY: computedBlur),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: effectiveBorderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: isLight
                    ? const Color(0x180F172A)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isLight ? 20 : 24,
                spreadRadius: -2,
                offset: isLight ? const Offset(0, 8) : const Offset(0, 12),
              ),
            ],
          ),
          child: this,
        ),
      ),
    );
  }
}
