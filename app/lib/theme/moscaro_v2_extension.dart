import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'moscaro_v2_tokens.dart';

/// Gerenciador Singleton de Shaders GLSL de Alta Performance (Dual Kawase Blur).
class KawaseShaderManager {
  static final KawaseShaderManager instance = KawaseShaderManager._();
  KawaseShaderManager._() {
    _initShader();
  }

  ui.FragmentProgram? _program;
  bool _isLoading = false;
  bool _hasError = false;

  bool get isReady => _program != null;
  bool get hasError => _hasError;

  Future<void> _initShader() async {
    if (_isLoading || _program != null) return;
    _isLoading = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/kawase_blur.frag');
    } catch (_) {
      _hasError = true;
    } finally {
      _isLoading = false;
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
    final effectiveBlurSigma = blurSigma ?? MoscaroTokens.blurSigma;
    final double computedBlur = (enableBlur && effectiveBlurSigma > 0) ? effectiveBlurSigma : 0.0;
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

    Widget container = Container(
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
      container = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: computedBlur, sigmaY: computedBlur),
        child: container,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: container,
    );
  }
}

