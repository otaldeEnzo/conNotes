import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/theme_models.dart';

/// Pintor de Texturas Procedurais STEM de Alta Performance para o Fundo do Canvas.
class ThemeTexturePainter extends CustomPainter {
  final CanvasTextureType textureType;
  final Offset panOffset;
  final double zoomScale;
  final Color accentColor;

  ThemeTexturePainter({
    required this.textureType,
    required this.panOffset,
    required this.zoomScale,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (textureType == CanvasTextureType.none) return;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final double worldLeft = -panOffset.dx / zoomScale;
    final double worldTop = -panOffset.dy / zoomScale;
    final double worldRight = (size.width - panOffset.dx) / zoomScale;
    final double worldBottom = (size.height - panOffset.dy) / zoomScale;

    switch (textureType) {
      case CanvasTextureType.graphPaper:
        _paintGraphPaper(canvas, worldLeft, worldTop, worldRight, worldBottom);
        break;
      case CanvasTextureType.blueprintCloth:
        _paintBlueprintCloth(canvas, worldLeft, worldTop, worldRight, worldBottom);
        break;
      case CanvasTextureType.carbonFiber:
        _paintCarbonFiber(canvas, worldLeft, worldTop, worldRight, worldBottom);
        break;
      case CanvasTextureType.analogGrain:
        _paintAnalogGrain(canvas, worldLeft, worldTop, worldRight, worldBottom);
        break;
      case CanvasTextureType.none:
        break;
    }

    canvas.restore();
  }

  /// 1. Papel Milimetrado Técnico Escuro (Subdivisões de 5mm e 1mm com alta precisão)
  void _paintGraphPaper(Canvas canvas, double left, double top, double right, double bottom) {
    const double minorSpacing = 8.0;
    const double majorSpacing = 40.0;

    final minorPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.07)
      ..strokeWidth = 0.5;

    final majorPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..strokeWidth = 0.9;

    final startX = (left / minorSpacing).floor() * minorSpacing;
    final startY = (top / minorSpacing).floor() * minorSpacing;

    for (double x = startX; x <= right; x += minorSpacing) {
      final isMajor = (x.round() % majorSpacing.round()).abs() < 0.5;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), isMajor ? majorPaint : minorPaint);
    }

    for (double y = startY; y <= bottom; y += minorSpacing) {
      final isMajor = (y.round() % majorSpacing.round()).abs() < 0.5;
      canvas.drawLine(Offset(left, y), Offset(right, y), isMajor ? majorPaint : minorPaint);
    }
  }

  /// 2. Blueprint Têxtil de Engenharia (Linhas entrelaçadas estilo tecido de prancheta)
  void _paintBlueprintCloth(Canvas canvas, double left, double top, double right, double bottom) {
    const double spacing = 16.0;
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.6;

    final startX = (left / spacing).floor() * spacing;
    final startY = (top / spacing).floor() * spacing;

    for (double x = startX; x <= right; x += spacing) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
    for (double y = startY; y <= bottom; y += spacing) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  /// 3. Fibra de Carbono Matrix (Padrão diagonal de micro-trama 3D)
  void _paintCarbonFiber(Canvas canvas, double left, double top, double right, double bottom) {
    const double step = 20.0;
    final blockPaint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    final blockPaint2 = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final startX = (left / step).floor() * step;
    final startY = (top / step).floor() * step;

    for (double x = startX; x <= right; x += step) {
      for (double y = startY; y <= bottom; y += step) {
        final isEven = ((x / step).round() + (y / step).round()) % 2 == 0;
        final rect = Rect.fromLTWH(x, y, step * 0.9, step * 0.9);
        canvas.drawRect(rect, isEven ? blockPaint1 : blockPaint2);
      }
    }
  }

  /// 4. Grão Analógico Suave (Pontilhismo aleatório determinístico)
  void _paintAnalogGrain(Canvas canvas, double left, double top, double right, double bottom) {
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    const double grainSpacing = 28.0;
    final startX = (left / grainSpacing).floor() * grainSpacing;
    final startY = (top / grainSpacing).floor() * grainSpacing;

    for (double x = startX; x <= right; x += grainSpacing) {
      for (double y = startY; y <= bottom; y += grainSpacing) {
        final pseudoRandom = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
        final offsetX = (pseudoRandom - pseudoRandom.floor()) * 12.0;
        final offsetY = ((pseudoRandom * 2.0) - (pseudoRandom * 2.0).floor()) * 12.0;
        canvas.drawCircle(Offset(x + offsetX, y + offsetY), 0.7, grainPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ThemeTexturePainter oldDelegate) {
    return oldDelegate.textureType != textureType ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.accentColor != accentColor;
  }
}
