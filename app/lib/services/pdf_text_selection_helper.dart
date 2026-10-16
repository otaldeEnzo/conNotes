import 'dart:math' as math;
import 'dart:ui';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_text_selection_models.dart';

/// Helper utility for extracting, hit-testing, and consolidating text selections on PDF pages.
class PdfTextSelectionHelper {
  /// Locates the character index in [pageText] nearest to [displayPos].
  static int findNearestCharIndex({
    required PdfPageText pageText,
    required Offset displayPos,
    required double pageWidth,
    required double pageHeight,
    required double pdfNativeWidth,
    required double pdfNativeHeight,
  }) {
    if (pageText.fragments.isEmpty || pdfNativeWidth <= 0.0 || pdfNativeHeight <= 0.0) {
      return 0;
    }

    final double scaleX = pageWidth / pdfNativeWidth;
    final double scaleY = pageHeight / pdfNativeHeight;

    final double targetPdfX = displayPos.dx / scaleX;
    final double targetPdfY = displayPos.dy / scaleY;

    int nearestIdx = 0;
    double minDistanceSq = double.infinity;

    for (final fragment in pageText.fragments) {
      final bounds = fragment.bounds;
      // Fast bounding box vertical check (with 15pt tolerance)
      if (targetPdfY < bounds.top - 15.0 || targetPdfY > bounds.bottom + 15.0) {
        continue;
      }

      final charRects = fragment.charRects;
      for (int i = 0; i < charRects.length; i++) {
        final rect = charRects[i];
        final globalIdx = fragment.index + i;

        // Direct hit inside character rect
        if (targetPdfX >= rect.left &&
            targetPdfX <= rect.right &&
            targetPdfY >= rect.top &&
            targetPdfY <= rect.bottom) {
          return globalIdx;
        }

        final charCenterX = (rect.left + rect.right) / 2.0;
        final charCenterY = (rect.top + rect.bottom) / 2.0;
        final dx = charCenterX - targetPdfX;
        final dy = (charCenterY - targetPdfY) * 2.0; // prioritize vertical row alignment
        final distSq = (dx * dx) + (dy * dy);

        if (distSq < minDistanceSq) {
          minDistanceSq = distSq;
          nearestIdx = globalIdx;
        }
      }
    }

    return nearestIdx;
  }

  /// Builds a consolidated [PdfTextSelectionState] for character range [charA] to [charB].
  static PdfTextSelectionState buildSelection({
    required PdfPageText pageText,
    required int pageNumber,
    required int charA,
    required int charB,
    required double pageWidth,
    required double pageHeight,
    required double pdfNativeWidth,
    required double pdfNativeHeight,
    bool isSelecting = false,
  }) {
    final fullText = pageText.fullText;
    if (fullText.isEmpty || pdfNativeWidth <= 0.0 || pdfNativeHeight <= 0.0) {
      return PdfTextSelectionState.empty;
    }

    final int start = math.max(0, math.min(charA, charB));
    final int end = math.min(fullText.length, math.max(charA, charB));

    if (start >= end) {
      return PdfTextSelectionState.empty;
    }

    final String selectedText = fullText.substring(start, end);
    final double scaleX = pageWidth / pdfNativeWidth;
    final double scaleY = pageHeight / pdfNativeHeight;

    final rawCharRects = <Rect>[];

    for (final fragment in pageText.fragments) {
      final fragStart = fragment.index;
      final fragEnd = fragment.index + fragment.length;

      final overlapStart = math.max(start, fragStart);
      final overlapEnd = math.min(end, fragEnd);

      if (overlapStart < overlapEnd) {
        final charRects = fragment.charRects;
        final localOffset = overlapStart - fragStart;
        final localCount = overlapEnd - overlapStart;

        for (int i = localOffset; i < localOffset + localCount && i < charRects.length; i++) {
          final cRect = charRects[i];
          rawCharRects.add(Rect.fromLTRB(cRect.left, cRect.top, cRect.right, cRect.bottom));
        }
      }
    }

    if (rawCharRects.isEmpty) {
      return PdfTextSelectionState.empty;
    }

    // Consolidate adjacent character rects on the same line into contiguous line boxes
    final consolidatedLineRects = _consolidateCharRectsIntoLines(rawCharRects);

    // Map to display page coordinates
    final displayRects = consolidatedLineRects.map((r) {
      return Rect.fromLTRB(
        r.left * scaleX,
        r.top * scaleY,
        r.right * scaleX,
        r.bottom * scaleY,
      );
    }).toList();

    final overallBounds = displayRects.reduce((a, b) => a.expandToInclude(b));

    return PdfTextSelectionState(
      pageNumber: pageNumber,
      startIndex: start,
      endIndex: end,
      selectedText: selectedText,
      rects: displayRects,
      bounds: overallBounds,
      isSelecting: isSelecting,
    );
  }

  /// Consolidates character rects into horizontal line bounding boxes.
  static List<Rect> _consolidateCharRectsIntoLines(List<Rect> charRects) {
    if (charRects.isEmpty) return const <Rect>[];

    // Sort by top Y, then left X
    final sorted = List<Rect>.from(charRects)
      ..sort((a, b) {
        final dy = a.top.compareTo(b.top);
        if (dy.abs() > 4.0) return dy;
        return a.left.compareTo(b.left);
      });

    final lines = <Rect>[];
    Rect currentLine = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      // If next character belongs to roughly the same horizontal line
      final bool sameLine = (next.top - currentLine.top).abs() < 6.0 &&
          (next.bottom - currentLine.bottom).abs() < 6.0 &&
          next.left <= currentLine.right + 12.0;

      if (sameLine) {
        currentLine = currentLine.expandToInclude(next);
      } else {
        lines.add(currentLine);
        currentLine = next;
      }
    }
    lines.add(currentLine);

    return lines;
  }
}
