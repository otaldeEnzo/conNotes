import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pdf_text_search_models.dart';
import '../theme/moscaro_v2_tokens.dart';

/// High-performance GPU-accelerated painter rendering search match highlight boxes
/// directly over the rendered PDF page vector content.
///
/// Features:
/// - Transforms native 72 DPI PDF point coordinates to canvas page display pixels.
/// - Inactive matches rendered with translucent cyan fill and subtle borders.
/// - Active match rendered with vibrant glowing Moscaro Aurora Blue (#00e1ff) fill and border.
/// - Rounded rectangular corners (2.5px) matching Moscaro aesthetic standard.
/// - Zero emojis anywhere.
class PdfPageSearchHighlightPainter extends CustomPainter {
  /// All matches located specifically on this page sheet.
  final List<PdfTextMatch> matches;

  /// The document-wide currently focused match (if on this page).
  final PdfTextMatch? activeMatch;

  /// Current display width of the page subcard on the infinite canvas.
  final double pageWidth;

  /// Current display height of the page subcard on the infinite canvas.
  final double pageHeight;

  /// Native width of the PDF page in 72 DPI points (from PdfPage.width).
  final double pdfNativeWidth;

  /// Native height of the PDF page in 72 DPI points (from PdfPage.height).
  final double pdfNativeHeight;

  final Paint _inactiveFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x4D00E1FF); // 30% translucent cyan

  final Paint _inactiveBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.45);

  final Paint _activeFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.55);

  final Paint _activeBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = MoscaroTokens.auroraBlue;

  final Paint _activeGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  PdfPageSearchHighlightPainter({
    required this.matches,
    this.activeMatch,
    required this.pageWidth,
    required this.pageHeight,
    required this.pdfNativeWidth,
    required this.pdfNativeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty || pdfNativeWidth <= 0.0 || pdfNativeHeight <= 0.0) return;

    final scaleX = pageWidth / pdfNativeWidth;
    final scaleY = pageHeight / pdfNativeHeight;

    // 1. Paint all inactive matches first
    for (final match in matches) {
      if (match == activeMatch) continue;

      for (final rawRect in match.rects) {
        final scaledRect = Rect.fromLTRB(
          rawRect.left * scaleX,
          rawRect.top * scaleY,
          rawRect.right * scaleX,
          rawRect.bottom * scaleY,
        );

        final rrect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(2.5));
        canvas.drawRRect(rrect, _inactiveFillPaint);
        canvas.drawRRect(rrect, _inactiveBorderPaint);
      }
    }

    // 2. Paint active focused match on top with vivid Aurora Blue glow
    if (activeMatch != null) {
      for (final rawRect in activeMatch!.rects) {
        final scaledRect = Rect.fromLTRB(
          rawRect.left * scaleX,
          rawRect.top * scaleY,
          rawRect.right * scaleX,
          rawRect.bottom * scaleY,
        );

        final rrect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(2.5));

        // Outer glow
        canvas.drawRRect(rrect, _activeGlowPaint);
        // Core highlight fill
        canvas.drawRRect(rrect, _activeFillPaint);
        // Crisp boundary stroke
        canvas.drawRRect(rrect, _activeBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PdfPageSearchHighlightPainter oldDelegate) {
    return !listEquals(oldDelegate.matches, matches) ||
        oldDelegate.activeMatch != activeMatch ||
        oldDelegate.pageWidth != pageWidth ||
        oldDelegate.pageHeight != pageHeight ||
        oldDelegate.pdfNativeWidth != pdfNativeWidth ||
        oldDelegate.pdfNativeHeight != pdfNativeHeight;
  }
}
