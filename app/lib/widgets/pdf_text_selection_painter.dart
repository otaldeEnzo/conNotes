import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

/// Painter rendering translucent selection boxes and drag handles over selected PDF text,
/// styled with the active theme accent.
class PdfTextSelectionPainter extends CustomPainter {
  final List<Rect> rects;
  final bool isSelecting;
  final Color? accentColor;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _handlePaint = Paint()..style = PaintingStyle.fill;

  PdfTextSelectionPainter({
    required this.rects,
    this.isSelecting = false,
    this.accentColor,
  }) {
    final effectiveAccent = accentColor ?? MoscaroTokens.auroraBlue;
    _fillPaint.color = effectiveAccent.withValues(alpha: 0.28);
    _borderPaint.color = effectiveAccent.withValues(alpha: 0.55);
    _handlePaint.color = effectiveAccent;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isEmpty) return;

    for (final rect in rects) {
      final rrect = RRect.fromRectAndRadius(
        rect.inflate(1.0),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(rrect, _fillPaint);
      canvas.drawRRect(rrect, _borderPaint);
    }

    // Draw start and end selection handles
    final first = rects.first;
    final last = rects.last;

    // Start handle (vertical bar on left of first rect)
    final startHandleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(first.left - 2.0, first.top, 2.5, first.height),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(startHandleRRect, _handlePaint);

    // End handle (vertical bar on right of last rect)
    final endHandleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(last.right - 0.5, last.top, 2.5, last.height),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(endHandleRRect, _handlePaint);
  }

  @override
  bool shouldRepaint(covariant PdfTextSelectionPainter oldDelegate) {
    return oldDelegate.rects != rects ||
        oldDelegate.isSelecting != isSelecting ||
        oldDelegate.accentColor != accentColor;
  }
}
