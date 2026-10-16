import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_internal_object_models.dart';
import 'pdf_page_spatial_index.dart';

/// Service analyzing PDF pages for structured internal elements:
/// images, figures, tabular grids, and STEM mathematical formulas.
class PdfObjectDetectionService {
  PdfObjectDetectionService._internal();

  static final PdfObjectDetectionService instance = PdfObjectDetectionService._internal();

  final Map<String, Map<int, List<PdfInternalObject>>> _objectCache = {};
  final Map<String, Map<int, PdfPageSpatialIndex>> _spatialIndexCache = {};

  /// Retrieves or builds the spatial index for a given page.
  Future<PdfPageSpatialIndex?> getSpatialIndex({
    required String filePath,
    required PdfPage page,
    required int pageNumber,
  }) async {
    final docMap = _spatialIndexCache.putIfAbsent(filePath, () => {});
    if (docMap.containsKey(pageNumber)) {
      return docMap[pageNumber];
    }

    try {
      final pageText = await page.loadText();
      final index = PdfPageSpatialIndex.fromPageText(
        pageText: pageText,
        pageNumber: pageNumber,
        nativeWidth: page.width,
        nativeHeight: page.height,
      );
      docMap[pageNumber] = index;
      return index;
    } catch (e) {
      debugPrint('[PdfObjectDetectionService] getSpatialIndex error: $e');
      return null;
    }
  }

  /// Detects all structured entities on [page].
  Future<List<PdfInternalObject>> detectObjectsForPage({
    required String filePath,
    required PdfPage page,
    required int pageNumber,
  }) async {
    final docMap = _objectCache.putIfAbsent(filePath, () => {});
    if (docMap.containsKey(pageNumber)) {
      return docMap[pageNumber]!;
    }

    final detected = <PdfInternalObject>[];

    try {
      final spatialIndex = await getSpatialIndex(
        filePath: filePath,
        page: page,
        pageNumber: pageNumber,
      );

      if (spatialIndex != null) {
        final detectedFromIndex = detectObjectsFromSpatialIndex(
          spatialIndex,
          idPrefix: '${filePath.hashCode}',
        );
        detected.addAll(detectedFromIndex);
      }

      docMap[pageNumber] = detected;
      return detected;
    } catch (e) {
      debugPrint('[PdfObjectDetectionService] detectObjects error: $e');
      docMap[pageNumber] = const [];
      return const [];
    }
  }

  /// Detects structured entities directly from an already computed [PdfPageSpatialIndex].
  List<PdfInternalObject> detectObjectsFromSpatialIndex(
    PdfPageSpatialIndex spatialIndex, {
    String idPrefix = 'obj',
  }) {
    final detected = <PdfInternalObject>[];
    final fullText = spatialIndex.fullText;
    final pageNumber = spatialIndex.pageNumber;

    // 1. STEM Formula Detection (Heuristic: isolated Greek / Math symbols, fractions, matrices)
    final mathRegex = RegExp(r'([a-zA-Z0-9_\^\+\-\*/\(\)=]{2,}\s*[=><\u2248]\s*[\d\w\s\+\-\*/\(\)\\\^]+|[\u0391-\u03C9\u2200-\u22FF\u2A00-\u2AFF]{2,})');
    for (final line in spatialIndex.lines) {
      final lineText = fullText.substring(line.startIndex, math.min(fullText.length, line.endIndex));
      if (mathRegex.hasMatch(lineText) && line.charRects.length > 3) {
        detected.add(PdfInternalObject(
          id: 'formula_${idPrefix}_p${pageNumber}_${line.startIndex}',
          pageNumber: pageNumber,
          bounds: line.bounds,
          type: PdfInternalObjectType.formula,
          textContent: lineText.trim(),
          confidence: 0.88,
          metadata: {
            'latex': lineText.trim(),
          },
        ));
      }
    }

    // 2. Table Detection (Heuristic: multiple aligned lines with numeric data or tabbed spacing)
    if (spatialIndex.lines.length >= 3) {
      final lines = spatialIndex.lines;
      for (int i = 0; i <= lines.length - 3; i++) {
        final l1 = lines[i];
        final l2 = lines[i + 1];
        final l3 = lines[i + 2];
        final t1 = fullText.substring(l1.startIndex, l1.endIndex);
        final t2 = fullText.substring(l2.startIndex, l2.endIndex);
        final t3 = fullText.substring(l3.startIndex, l3.endIndex);

        final cols1 = t1.trim().split(RegExp(r'\s{2,}|\t'));
        final cols2 = t2.trim().split(RegExp(r'\s{2,}|\t'));
        final cols3 = t3.trim().split(RegExp(r'\s{2,}|\t'));

        if (cols1.length >= 2 && cols2.length >= 2 && cols3.length >= 2) {
          final tableBounds = Rect.fromLTRB(
            math.min(l1.bounds.left, math.min(l2.bounds.left, l3.bounds.left)),
            l1.bounds.top,
            math.max(l1.bounds.right, math.max(l2.bounds.right, l3.bounds.right)),
            l3.bounds.bottom,
          );

          detected.add(PdfInternalObject(
            id: 'table_${idPrefix}_p${pageNumber}_$i',
            pageNumber: pageNumber,
            bounds: tableBounds,
            type: PdfInternalObjectType.table,
            textContent: '$t1\n$t2\n$t3',
            confidence: 0.85,
            metadata: {
              'rows': 3,
              'columns': math.max(cols1.length, math.max(cols2.length, cols3.length)),
            },
          ));
          i += 2; // Skip grouped rows
        }
      }
    }

    return detected;
  }

  /// Convenience wrapper to detect objects from a [PdfPageSpatialIndex] or [PdfPageText].
  List<PdfInternalObject> detectObjects({
    PdfPageSpatialIndex? spatialIndex,
    PdfPageText? pageText,
    int pageNumber = 1,
    double nativeWidth = 0,
    double nativeHeight = 0,
    double? pageWidth,
    double? pageHeight,
    double? pdfNativeWidth,
    double? pdfNativeHeight,
    String idPrefix = 'obj',
  }) {
    if (spatialIndex != null) {
      return detectObjectsFromSpatialIndex(spatialIndex, idPrefix: idPrefix);
    }
    final effectiveNativeW = nativeWidth > 0 ? nativeWidth : (pdfNativeWidth ?? 0.0);
    final effectiveNativeH = nativeHeight > 0 ? nativeHeight : (pdfNativeHeight ?? 0.0);
    if (pageText != null && effectiveNativeW > 0 && effectiveNativeH > 0) {
      final index = PdfPageSpatialIndex.fromPageText(
        pageText: pageText,
        pageNumber: pageNumber,
        nativeWidth: effectiveNativeW,
        nativeHeight: effectiveNativeH,
      );
      return detectObjectsFromSpatialIndex(index, idPrefix: idPrefix);
    }
    return const [];
  }

  /// Locates any detected object covering [displayPos].
  PdfInternalObject? findObjectAt({
    required List<PdfInternalObject> objects,
    required Offset displayPos,
    required double displayWidth,
    required double displayHeight,
    required double nativeWidth,
    required double nativeHeight,
  }) {
    if (objects.isEmpty || nativeWidth <= 0 || nativeHeight <= 0) return null;
    final scaleX = displayWidth / nativeWidth;
    final scaleY = displayHeight / nativeHeight;

    final targetX = displayPos.dx / scaleX;
    final targetY = displayPos.dy / scaleY;

    for (final obj in objects) {
      if (obj.bounds.contains(Offset(targetX, targetY))) {
        return obj;
      }
    }
    return null;
  }

  /// Clears internal caches when documents close or reload.
  void clearCache([String? filePath]) {
    if (filePath != null) {
      _objectCache.remove(filePath);
      _spatialIndexCache.remove(filePath);
    } else {
      _objectCache.clear();
      _spatialIndexCache.clear();
    }
  }
}
