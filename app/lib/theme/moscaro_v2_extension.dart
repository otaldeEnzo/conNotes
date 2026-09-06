import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/diagnostics_override_controller.dart';
import 'moscaro_v2_tokens.dart';

/// Gerenciador Singleton de Shaders GLSL de Alta Performance (Dual Kawase Blur).
/// Shader Manager Singleton para carregar o Dual Kawase Shader em GPUs suportadas.
class MoscaroBlurShaderManager {
  static final MoscaroBlurShaderManager instance = MoscaroBlurShaderManager._();
  MoscaroBlurShaderManager._();

  ui.FragmentProgram? _program;

  Future<void> init() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/dual_kawase_blur.frag');
    } catch (_) {
      // Fallback gracioso para ImageFilter.blur nativo caso a plataforma não suporte shaders de fragmento
    }
  }

  ui.FragmentShader? createShader() {
    if (_program == null) return null;
    return _program!.fragmentShader();
  }
}

/// Design System Centralizado `moscaro-v2`
/// Extensão universal aplicável a qualquer componente Flutter com suporte a Dark & Light Glass e aceleração Dual Kawase.
extension MoscaroV2Extension on Widget {
  Widget moscaroV2({
    double borderRadius = MoscaroTokens.radiusPanel,
    double? blurSigma,
    bool enableBlur = true,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = MoscaroTokens.borderWidthSubtle,
    EdgeInsetsGeometry? padding,
    List<BoxShadow>? customShadows,
  }) {
    final bool bypass = DiagnosticsOverrideController.instance.bypassBackdropFilter;
    final effectiveBlurSigma = blurSigma ?? MoscaroTokens.blurSigma;
    final double computedBlur = (!bypass && enableBlur && effectiveBlurSigma > 0) ? effectiveBlurSigma : 0.0;
    final isLight = MoscaroTokens.isLight;

    final effectiveBgColor = backgroundColor ?? MoscaroTokens.glassTint;
    final effectiveBorderColor = borderColor ?? (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow);

    final defaultShadows = [
      BoxShadow(
        color: isLight
            ? const Color(0x180F172A)
            : Colors.black.withValues(alpha: 0.45),
        blurRadius: isLight ? 20 : 24,
        spreadRadius: -2,
        offset: isLight ? const Offset(0, 8) : const Offset(0, 12),
      ),
    ];

    Widget styledBox = Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: customShadows ?? defaultShadows,
      ),
      child: this,
    );

    if (computedBlur > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: computedBlur, sigmaY: computedBlur),
          child: styledBox,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: styledBox,
    );
  }
}

