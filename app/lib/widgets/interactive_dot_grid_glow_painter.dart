import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'canvas_dot_grid_painter.dart';

/// Painter de alta performance para o Brilho Orgânico e Reativo do Mouse no Dot Grid.
/// Executa com complexidade O(K) onde K <= 80 pontos dentro do raio de influência do cursor.
class InteractiveDotGridGlowPainter extends CustomPainter {
  final ValueNotifier<Offset?> mousePosNotifier;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final double gridSpacing;
  final double glowRadius;
  final Color glowColor;
  final CanvasBackgroundType backgroundType;
  final bool isDark;

  final Paint _dotPaint = Paint()..style = PaintingStyle.fill;

  InteractiveDotGridGlowPainter({
    required this.mousePosNotifier,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.gridSpacing,
    required this.glowRadius,
    required this.glowColor,
    required this.backgroundType,
    required this.isDark,
    Listenable? repaint,
  }) : super(repaint: repaint ?? Listenable.merge([mousePosNotifier, panNotifier, zoomNotifier]));

  @override
  void paint(Canvas canvas, Size size) {
    final mousePosition = mousePosNotifier.value;
    if (mousePosition == null) return;
    if (glowRadius <= 0) return;
    if (backgroundType != CanvasBackgroundType.dotGrid) return;

    final panOffset = panNotifier.value;
    final zoomScale = zoomNotifier.value;

    // 1. Determinação do espaçamento em coordenadas de mundo (idêntico ao CanvasDotGridPainter)
    double spacing = gridSpacing;
    final double scaledSpacing = spacing * zoomScale;
    if (scaledSpacing < 18.0) {
      spacing = gridSpacing * 2.0;
    } else if (scaledSpacing > 76.0) {
      spacing = gridSpacing / 2.0;
    }

    // 2. Mapeamento da posição do cursor para coordenadas de mundo
    final double worldMouseX = (mousePosition.dx - panOffset.dx) / zoomScale;
    final double worldMouseY = (mousePosition.dy - panOffset.dy) / zoomScale;
    final double worldRadius = glowRadius / zoomScale;

    // Confinado ao 4º quadrante (x >= 0, y >= 0)
    final int minCol = math.max(0, ((worldMouseX - worldRadius) / spacing).floor());
    final int maxCol = math.max(0, ((worldMouseX + worldRadius) / spacing).ceil());
    final int minRow = math.max(0, ((worldMouseY - worldRadius) / spacing).floor());
    final int maxRow = math.max(0, ((worldMouseY + worldRadius) / spacing).ceil());

    final double baseDotRadius = (1.2 / zoomScale).clamp(0.6, 2.2) * zoomScale;
    final double rSquared = glowRadius * glowRadius;

    // Cores base para interpolação ARGB inteira direta (Zero alocações de Color na heap)
    final int startR = isDark ? 148 : 100;
    final int startG = isDark ? 163 : 116;
    final int startB = isDark ? 184 : 139;
    final int deltaR = 255 - startR;
    final int deltaG = 255 - startG;
    final int deltaB = 255 - startB;

    // 3. Renderização sutil, orgânica e pontual (sem névoa no fundo, apenas os pontos ganham vida)
    for (int col = minCol; col <= maxCol; col++) {
      final double wx = col * spacing;
      final double sx = panOffset.dx + (wx * zoomScale);
      if (sx < 0 || sx > size.width) continue;

      for (int row = minRow; row <= maxRow; row++) {
        final double wy = row * spacing;
        final double sy = panOffset.dy + (wy * zoomScale);
        if (sy < 0 || sy > size.height) continue;

        final double dx = sx - mousePosition.dx;
        final double dy = sy - mousePosition.dy;
        final double distSquared = (dx * dx) + (dy * dy);

        if (distSquared <= rSquared) {
          final double dist = math.sqrt(distSquared);
          final double ratio = (1.0 - (dist / glowRadius)).clamp(0.0, 1.0);

          // Curva de atenuação suave (Hermite Smoothstep para falloff realista)
          final double falloff = ratio * ratio * (3.0 - (2.0 * ratio));

          // Crescimento sutil e elegante dos pontos (de 1.0x até ~1.85x no epicentro)
          final double expandedRadius = baseDotRadius * (1.0 + (0.85 * falloff));

          // Luminosidade viva: passa de opacidade discreta a branco puro brilhante no centro
          final double opacity = (0.22 + (0.78 * falloff)).clamp(0.0, 1.0);
          final int a = (opacity * 255.0).round().clamp(0, 255);
          final int r = (startR + deltaR * falloff).round().clamp(0, 255);
          final int g = (startG + deltaG * falloff).round().clamp(0, 255);
          final int b = (startB + deltaB * falloff).round().clamp(0, 255);

          _dotPaint.color = Color.fromARGB(a, r, g, b);
          canvas.drawCircle(Offset(sx, sy), expandedRadius, _dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant InteractiveDotGridGlowPainter oldDelegate) {
    return oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.glowRadius != glowRadius ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.isDark != isDark;
  }
}
