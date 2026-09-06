import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/performance_telemetry_controller.dart';

/// Painter de alta performance para desenhar a linha do tempo de 150 quadros do Flutter.
class PerformanceTimelinePainter extends CustomPainter {
  final List<PerformanceFrameSample> samples;
  final double targetFps;

  static final Paint _uiPaint = Paint()
    ..color = const Color(0xFF00E1FF)
    ..style = PaintingStyle.fill;

  static final Paint _rasterPaint = Paint()
    ..color = const Color(0xFFBD00FF)
    ..style = PaintingStyle.fill;

  static final Paint _jankPaint = Paint()
    ..color = const Color(0xFFFF2A6D)
    ..style = PaintingStyle.fill;

  static final Paint _line120Paint = Paint()
    ..color = const Color(0x5500E1FF)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _line60Paint = Paint()
    ..color = const Color(0x66FFB703)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  PerformanceTimelinePainter({
    required this.samples,
    this.targetFps = 120.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const double maxMs = 33.33; // Escala máxima de 30 FPS (33ms) para acomodar engasgos
    final double h = size.height;
    final double w = size.width;

    // 1. Linhas Guias de Orçamento de Tempo
    final double y120 = h - (8.33 / maxMs * h).clamp(0.0, h);
    final double y60 = h - (16.66 / maxMs * h).clamp(0.0, h);

    // Linha 120 FPS (8.33 ms)
    canvas.drawLine(Offset(0, y120), Offset(w, y120), _line120Paint);

    // Linha 60 FPS (16.66 ms)
    canvas.drawLine(Offset(0, y60), Offset(w, y60), _line60Paint);

    if (samples.isEmpty) return;

    // 2. Barras de Cada Quadro
    final int count = samples.length;
    final double barWidth = math.max(2.0, w / PerformanceTelemetryController.maxSamples);

    for (int i = 0; i < count; i++) {
      final s = samples[i];
      final double x = i * barWidth;

      final double uiHeight = (s.buildMs / maxMs * h).clamp(0.0, h);
      final double rasterHeight = (s.rasterMs / maxMs * h).clamp(0.0, h - uiHeight);
      final double totalHeight = (s.totalMs / maxMs * h).clamp(0.0, h);

      final Paint barPaint = s.isJank ? _jankPaint : _rasterPaint;

      // Barra de Rasterização (GPU)
      final rasterRect = Rect.fromLTWH(
        x + 0.5,
        h - totalHeight,
        barWidth - 1.0,
        rasterHeight,
      );
      canvas.drawRect(rasterRect, barPaint);

      // Barra de UI (CPU)
      final uiRect = Rect.fromLTWH(
        x + 0.5,
        h - uiHeight,
        barWidth - 1.0,
        uiHeight,
      );
      canvas.drawRect(uiRect, s.isJank ? _jankPaint : _uiPaint);

      // Marcador de Jank no Topo
      if (s.isJank) {
        canvas.drawCircle(Offset(x + barWidth / 2, h - totalHeight - 2), 2.0, _jankPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PerformanceTimelinePainter oldDelegate) {
    return true; // Repintura reativa leve confinada em RepaintBoundary
  }
}
