import 'package:flutter/material.dart';

/// Helper responsible for calculating magnetic page latching and snap targets
/// in continuous scroll PDF mode.
///
/// Characteristics:
/// - Magnetic Latch: If the scroll deceleration halts within [magneticThreshold]
///   pixels of a page boundary, it computes the target offset to latch cleanly.
/// - Pure calculation logic (fully testable).
class PdfMagneticSnapHelper {
  const PdfMagneticSnapHelper._();

  /// Default magnetic latching threshold in logical pixels.
  static const double defaultMagneticThreshold = 56.0;

  /// Default animation curve and duration for Moscaro magnetic snapping.
  static const Curve snapCurve = Curves.easeOutCubic;
  static const Duration snapDuration = Duration(milliseconds: 260);

  /// Computes top offsets for all active pages in a continuous scroll layout.
  static List<double> computePageTopOffsets({
    required List<int> activePages,
    required double Function(int page) getPageHeight,
    required double gap,
  }) {
    final offsets = <double>[];
    double accumulatedTop = 0.0;

    for (int i = 0; i < activePages.length; i++) {
      offsets.add(accumulatedTop);
      final h = getPageHeight(activePages[i]);
      accumulatedTop += h + gap;
    }

    return offsets;
  }

  /// Calculates the nearest page boundary to [currentScrollOffset].
  /// Returns the target offset if within [magneticThreshold], or `null` if the
  /// scroll position should remain freely at rest.
  static double? calculateSnapTargetOffset({
    required double currentScrollOffset,
    required List<double> pageTopOffsets,
    double magneticThreshold = defaultMagneticThreshold,
  }) {
    if (pageTopOffsets.isEmpty) return null;

    double minDistance = double.infinity;
    double? nearestTarget;

    for (final offset in pageTopOffsets) {
      final distance = (currentScrollOffset - offset).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestTarget = offset;
      }
    }

    if (minDistance <= magneticThreshold && nearestTarget != null) {
      return nearestTarget;
    }

    return null;
  }

  /// Returns the 1-based page number corresponding to the nearest page top offset.
  static int findNearestPageNumber({
    required double currentScrollOffset,
    required List<int> activePages,
    required List<double> pageTopOffsets,
  }) {
    if (activePages.isEmpty) return 1;
    if (activePages.length != pageTopOffsets.length) return activePages.first;

    double minDistance = double.infinity;
    int nearestPage = activePages.first;

    for (int i = 0; i < activePages.length; i++) {
      final distance = (currentScrollOffset - pageTopOffsets[i]).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestPage = activePages[i];
      }
    }

    return nearestPage;
  }

  /// Computes the target canvas camera pan offset in Y to magnetically latch
  /// a page top to the viewport header.
  static Offset computeTargetPanForPage({
    required Offset currentPan,
    required double cardY,
    required double pageTopOffset,
    required double zoom,
    double viewportTopPadding = 40.0,
  }) {
    final targetCanvasY = cardY + pageTopOffset;
    final targetPanY = viewportTopPadding - (targetCanvasY * zoom);
    return Offset(currentPan.dx, targetPanY);
  }
}
