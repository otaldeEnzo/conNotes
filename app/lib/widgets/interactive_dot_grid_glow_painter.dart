import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'canvas_dot_grid_painter.dart';

/// Painter de alta performance para o Brilho Orgânico e Reativo do Mouse no Dot Grid.
/// Executa com complexidade O(K) onde K <= 80 pontos dentro do raio de influência do cursor.
class InteractiveDotGridGlowPainter extends CustomPainter {
  final Offset mousePosition;
  final Offset panOffset;
  final double zoomScale;
  final double gridSpacing;
  final double glowRadius;
  final Color glowColor;
  final CanvasBackgroundType backgroundType;
  final bool isDark;

  InteractiveDotGridGlowPainter({
    required this.mousePosition,
    required this.panOffset,
    required this.zoomScale,
    required this.gridSpacing,
    required this.glowRadius,
    required this.glowColor,
    required this.backgroundType,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowRadius <= 0) return;
    if (backgroundType == CanvasBackgroundType.emBranco) return;

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
    final Paint dotPaint = Paint()..style = PaintingStyle.fill;
    final double rSquared = glowRadius * glowRadius;

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
          final Color dotColor = Color.lerp(
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            Colors.white,
            falloff,
          )!.withValues(alpha: opacity);

          dotPaint.color = dotColor;
          canvas.drawCircle(Offset(sx, sy), expandedRadius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant InteractiveDotGridGlowPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.glowRadius != glowRadius ||
        oldDelegate.glowColor != glowColor;
  }
}
