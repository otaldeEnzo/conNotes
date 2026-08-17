import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

enum CanvasBackgroundType { dotGrid, pautado, isometric, emBranco }

/// Engine de Renderização 2D do Canvas Infinito com suporte a Pautas de Caderno,
/// Grid Isométrico Rígido (Lattice 3D STEM sem drift) e Delimitação do 4º Quadrante.
class CanvasDotGridPainter extends CustomPainter {
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePosition;
  final CanvasBackgroundType backgroundType;
  final bool isDrawing;

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

    // Salva o estado do Canvas e aplica a transformação mundial (World Space)
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final double worldLeft = -panOffset.dx / zoomScale;
    final double worldTop = -panOffset.dy / zoomScale;
    final double worldRight = (size.width - panOffset.dx) / zoomScale;
    final double worldBottom = (size.height - panOffset.dy) / zoomScale;

    // 2. Renderização de Padrões de Fundo (World Coordinates)
    if (backgroundType == CanvasBackgroundType.dotGrid) {
      _paintDotGrid(canvas, worldLeft, worldTop, worldRight, worldBottom);
    } else if (backgroundType == CanvasBackgroundType.pautado) {
      _paintPautadoNotebook(canvas, worldLeft, worldTop, worldRight, worldBottom);
    } else if (backgroundType == CanvasBackgroundType.isometric) {
      _paintIsometricLattice(canvas, worldLeft, worldTop, worldRight, worldBottom);
    }

    // 3. Pautas Universais de Caderno (Margem Esquerda em X=80 e Cabeçalho em Y=102 sobre uma pauta)
    _paintNotebookMarginAndHeader(canvas, worldLeft, worldTop, worldRight, worldBottom);

    // 4. Delimitação da Origem do 4º Quadrante (Bordas X=0 e Y=0)
    _paintOriginBoundaries(canvas, worldLeft, worldTop, worldRight, worldBottom);

    canvas.restore();
  }

  /// Renderiza o Dot Grid com LOD dinâmico em coordenadas de mundo
  void _paintDotGrid(Canvas canvas, double left, double top, double right, double bottom) {
    double spacing = 32.0;
    final scaledSpacing = spacing * zoomScale;
    if (scaledSpacing < 20.0) {
      spacing = 64.0;
    } else if (scaledSpacing > 72.0) {
      spacing = 16.0;
    }

    final double startX = (left / spacing).floor() * spacing;
    final double startY = (top / spacing).floor() * spacing;
    final double dotRadius = (1.2 / zoomScale).clamp(0.6, 2.2);

    final Paint dotPaint = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = dotRadius * 2
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    for (double x = startX; x <= right + spacing; x += spacing) {
      if (x < 0) continue; // Confinado ao 4º quadrante (x >= 0)
      for (double y = startY; y <= bottom + spacing; y += spacing) {
        if (y < 0) continue; // Confinado ao 4º quadrante (y >= 0)
        points.add(Offset(x, y));
      }
    }

    if (points.isNotEmpty) {
      canvas.drawPoints(PointMode.points, points, dotPaint);
    }
  }

  /// Renderiza o modo Pautado (Linhas horizontais regulares espaçadas a cada 34pt)
  void _paintPautadoNotebook(Canvas canvas, double left, double top, double right, double bottom) {
    const double lineSpacing = 34.0;
    final double startY = math.max(0.0, (top / lineSpacing).floor() * lineSpacing);

    final linePaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1.0 / zoomScale;

    // Linhas horizontais pautadas
    for (double y = startY; y <= bottom + lineSpacing; y += lineSpacing) {
      if (y < 0) continue;
      canvas.drawLine(
        Offset(math.max(0.0, left), y),
        Offset(math.max(0.0, right), y),
        linePaint,
      );
    }
  }

  /// Pautas de Caderno Universais (presentes em todos os modos: Dot Grid, Isométrico, Pautado e Em Branco)
  void _paintNotebookMarginAndHeader(Canvas canvas, double left, double top, double right, double bottom) {
    // 1. Pauta de Cabeçalho (Header Rule em Y = 102.0, exatamente em cima da 3ª linha pautada)
    const double headerY = 102.0;
    if (headerY >= top && headerY <= bottom) {
      final headerPaint = Paint()
        ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.38)
        ..strokeWidth = 1.4 / zoomScale;
      canvas.drawLine(
        Offset(math.max(0.0, left), headerY),
        Offset(math.max(0.0, right), headerY),
        headerPaint,
      );
    }

    // 2. Pauta de Margem Vertical Esquerda (Red/Coral Margin Rule em X = 80.0)
    const double marginX = 80.0;
    if (marginX >= left && marginX <= right) {
      final marginPaint = Paint()
        ..color = const Color(0x48FF5577) // Linha sutil de margem rosa/coral
        ..strokeWidth = 1.5 / zoomScale;
      canvas.drawLine(
        Offset(marginX, math.max(0.0, top)),
        Offset(marginX, math.max(0.0, bottom)),
        marginPaint,
      );
    }
  }

  /// Renderiza a malha Isométrica perfeita a 3 eixos (Vertical, +30° e -30°)
  /// sem qualquer drift ou desalinhamento entre linhas durante pan/zoom.
  void _paintIsometricLattice(Canvas canvas, double left, double top, double right, double bottom) {
    const double l = 42.0; // Comprimento da aresta do triângulo equilátero
    final double w = l * math.sqrt(3) / 2.0; // ~36.373 Espaçamento exato entre colunas verticais

    final isoPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.11)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    // 1. Linhas Verticais (x = c * W)
    final int cMin = math.max(0, (left / w).floor());
    final int cMax = math.max(0, (right / w).ceil());

    for (int c = cMin; c <= cMax; c++) {
      final x = c * w;
      canvas.drawLine(
        Offset(x, math.max(0.0, top)),
        Offset(x, math.max(0.0, bottom)),
        isoPaint,
      );
    }

    // 2. Diagonais a +30° (y = x / sqrt(3) + k * L)
    final double sqrt3 = math.sqrt(3);
    final double minKVal = top - right / sqrt3;
    final double maxKVal = bottom - left / sqrt3;
    final int kMin = (minKVal / l).floor() - 1;
    final int kMax = (maxKVal / l).ceil() + 1;

    for (int k = kMin; k <= kMax; k++) {
      final double kL = k * l;
      // Encontra intersecções com a caixa delimitadora do 4º quadrante
      final double x1 = math.max(0.0, left);
      final double y1 = x1 / sqrt3 + kL;
      final double x2 = math.max(0.0, right);
      final double y2 = x2 / sqrt3 + kL;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), isoPaint);
    }

    // 3. Diagonais a -30° (y = -x / sqrt(3) + m * L)
    final double minMVal = top + left / sqrt3;
    final double maxMVal = bottom + right / sqrt3;
    final int mMin = (minMVal / l).floor() - 1;
    final int mMax = (maxMVal / l).ceil() + 1;

    for (int m = mMin; m <= mMax; m++) {
      final double mL = m * l;
      final double x1 = math.max(0.0, left);
      final double y1 = -x1 / sqrt3 + mL;
      final double x2 = math.max(0.0, right);
      final double y2 = -x2 / sqrt3 + mL;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), isoPaint);
    }
  }

  /// Desenha a borda luminosa e guias da origem do 4º Quadrante (x = 0, y = 0)
  void _paintOriginBoundaries(Canvas canvas, double left, double top, double right, double bottom) {
    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.32)
      ..strokeWidth = 1.8 / zoomScale;

    // Borda Superior (Y = 0)
    if (0.0 >= top && 0.0 <= bottom) {
      canvas.drawLine(
        Offset(math.max(0.0, left), 0.0),
        Offset(math.max(0.0, right), 0.0),
        borderPaint,
      );
    }

    // Borda Esquerda (X = 0)
    if (0.0 >= left && 0.0 <= right) {
      canvas.drawLine(
        Offset(0.0, math.max(0.0, top)),
        Offset(0.0, math.max(0.0, bottom)),
        borderPaint,
      );
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

