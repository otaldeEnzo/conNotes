import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

enum CanvasBackgroundType { dotGrid, pautado, isometric, emBranco }

/// Engine de Renderização 2D do Canvas Infinito.
/// Suporta Dot Grid dinâmico, Pautado, Grid Isométrico para engenharia/STEM e base para tesselação customizada.
class CanvasDotGridPainter extends CustomPainter {
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePosition;
  final CanvasBackgroundType backgroundType;
  final bool isDrawing;
  static Float32List? _pointsBuffer;

  CanvasDotGridPainter({
    required this.panOffset,
    required this.zoomScale,
    required this.mousePosition,
    required this.backgroundType,
    this.isDrawing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo com gradiente radial azul profundo STEM Moscaro v2
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.4,
        colors: [
          MoscaroTokens.backgroundDeep,
          MoscaroTokens.backgroundSurface,
        ],
        stops: [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    if (backgroundType == CanvasBackgroundType.emBranco) {
      return;
    }

    final baseSpacing = 32.0 * zoomScale;

    // 2. Modo Dot Grid com LOD dinâmico e Zero-Allocation por frame
    if (backgroundType == CanvasBackgroundType.dotGrid) {
      double spacing = baseSpacing;
      while (spacing < 24.0) {
        spacing *= 2.0; // LOD Inteligente: previne explosão de 200.000 pontos ao afastar o zoom
      }
      while (spacing > 64.0) {
        spacing /= 2.0;
      }

      final startX = (panOffset.dx % spacing) - spacing;
      final startY = (panOffset.dy % spacing) - spacing;
      final double dotRadius = (1.2 * zoomScale).clamp(0.8, 2.5);

      final Paint dotPaint = Paint()
        ..color = const Color(0x20FFFFFF)
        ..strokeWidth = dotRadius * 2
        ..strokeCap = StrokeCap.round;

      int cols = ((size.width + spacing - startX) / spacing).ceil() + 1;
      int rows = ((size.height + spacing - startY) / spacing).ceil() + 1;
      int totalPoints = cols * rows;

      if (_pointsBuffer == null || _pointsBuffer!.length < totalPoints * 2) {
        _pointsBuffer = Float32List(math.max(totalPoints * 2, 4096));
      }

      int count = 0;
      final buf = _pointsBuffer!;

      for (double x = startX; x < size.width + spacing; x += spacing) {
        for (double y = startY; y < size.height + spacing; y += spacing) {
          if (count + 1 < buf.length) {
            buf[count++] = x;
            buf[count++] = y;
          }
        }
      }

      if (count > 0) {
        canvas.drawRawPoints(PointMode.points, Float32List.sublistView(buf, 0, count), dotPaint);
      }
    } 
    // 3. Modo Pautado (Notebook STEM)
    else if (backgroundType == CanvasBackgroundType.pautado) {
      final startY = (panOffset.dy % baseSpacing) - baseSpacing;
      final linePaint = Paint()
        ..color = const Color(0x20FFFFFF)
        ..strokeWidth = 1.0;

      for (double y = startY; y < size.height + baseSpacing; y += baseSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
    // 4. Modo Isométrico (Engenharia / Geometria Espacial a 30° / 150°)
    else if (backgroundType == CanvasBackgroundType.isometric) {
      final isoPaint = Paint()
        ..color = MoscaroTokens.auroraBlue.withOpacity(0.09)
        ..strokeWidth = 1.0;

      final double hSpacing = baseSpacing * math.sqrt(3);
      final double vSpacing = baseSpacing;

      final startX = (panOffset.dx % hSpacing) - hSpacing;
      final startY = (panOffset.dy % (vSpacing * 2)) - (vSpacing * 2);

      // Linhas verticais
      for (double x = startX; x < size.width + hSpacing; x += hSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), isoPaint);
      }

      // Linhas diagonais a 30° e 150°
      final double diagLen = size.width + size.height * 2;
      final double tan30 = math.tan(math.pi / 6);

      for (double y = startY - diagLen; y < size.height + diagLen; y += vSpacing * 2) {
        // Diagonal subindo
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y + size.width * tan30),
          isoPaint,
        );
        // Diagonal descendo
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y - size.width * tan30),
          isoPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasDotGridPainter oldDelegate) {
    if (isDrawing && oldDelegate.isDrawing) {
      return oldDelegate.panOffset != panOffset ||
          oldDelegate.zoomScale != zoomScale ||
          oldDelegate.backgroundType != backgroundType;
    }
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.mousePosition != mousePosition ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.isDrawing != isDrawing;
  }
}
