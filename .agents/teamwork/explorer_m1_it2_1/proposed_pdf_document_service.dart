import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import '../widgets/ink_models.dart';

/// Singleton service managing pdfrx Pdfium document lifecycles, text fragment metrics,
/// caching, and high-resolution 300 DPI composite annotation export.
class PdfDocumentService {
  PdfDocumentService._internal();

  static PdfDocumentService _instance = PdfDocumentService._internal();

  /// Global singleton instance.
  static PdfDocumentService get instance => _instance;

  /// Visible for testing to allow stub/mock injection.
  @visibleForTesting
  static set instance(PdfDocumentService testInstance) => _instance = testInstance;

  final Map<String, PdfDocument> _documentCache = <String, PdfDocument>{};
  final Map<String, Map<int, PdfPageText>> _pageTextCache = <String, Map<int, PdfPageText>>{};
  bool _isInitialized = false;

  /// Indicates whether pdfrx engine has been initialized.
  bool get isInitialized => _isInitialized;

  /// Current number of active cached documents.
  int get cachedDocumentCount => _documentCache.length;

  /// Bootstraps native pdfrx platform channels and Pdfium bindings.
  /// Idempotent: safe to invoke repeatedly.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await pdfrxFlutterInitialize();
    } catch (e) {
      debugPrint('PdfDocumentService.initialize warning: $e');
    }
    _isInitialized = true;
  }

  /// Opens and caches a PdfDocument from a local filesystem path.
  Future<PdfDocument> loadDocument(String filePath) async {
    await initialize();

    final cached = _documentCache[filePath];
    if (cached != null) {
      return cached;
    }

    final doc = await PdfDocument.openFile(filePath);
    _documentCache[filePath] = doc;
    return doc;
  }

  /// Asynchronously parses and caches text fragment metrics from a specific page.
  /// [pageNumber] is 1-based (1..pages.length).
  Future<PdfPageText?> loadPageText(String filePath, int pageNumber) async {
    final cachedPageMap = _pageTextCache[filePath];
    if (cachedPageMap != null && cachedPageMap.containsKey(pageNumber)) {
      return cachedPageMap[pageNumber];
    }

    try {
      final doc = await loadDocument(filePath);
      if (pageNumber < 1 || pageNumber > doc.pages.length) {
        return null;
      }

      final page = doc.pages[pageNumber - 1];
      final pageText = await page.loadText();
      _pageTextCache.putIfAbsent(filePath, () => <int, PdfPageText>{})[pageNumber] = pageText;
      return pageText;
    } catch (e) {
      debugPrint('PdfDocumentService.loadPageText error on $filePath page $pageNumber: $e');
      return null;
    }
  }

  /// Returns whether a given 1-based [pageNumber] is excluded from export.
  @visibleForTesting
  static bool shouldExcludePage(int pageNumber, Iterable<int> excludedPageIndices) {
    return excludedPageIndices.contains(pageNumber);
  }

  /// Retrieves ink strokes specifically for 1-based [pageNumber] without bleeding.
  @visibleForTesting
  static List<InkStroke> getStrokesForPage(
    int pageNumber,
    Map<int, List<InkStroke>> strokesPerPage,
  ) {
    return strokesPerPage[pageNumber] ?? const <InkStroke>[];
  }

  /// Exports an annotated PDF document by compositing high-resolution (300 DPI) base page
  /// bitmaps with user ink strokes into a flattened document via package:pdf.
  ///
  /// [originalPdfPath]: Local path to source PDF.
  /// [outputPath]: Destination path for the exported PDF.
  /// [strokesPerPage]: Map of page numbers (1-based) to page-local ink strokes.
  /// [cardWidth]: Display width of the card on canvas, used to scale stroke coordinates.
  /// [excludedPageIndices]: Page numbers (1-based) excluded from export (e.g. detached pages).
  Future<void> exportAnnotatedPdf({
    required String originalPdfPath,
    required String outputPath,
    required Map<int, List<InkStroke>> strokesPerPage,
    required double cardWidth,
    required List<int> excludedPageIndices,
  }) async {
    final doc = await loadDocument(originalPdfPath);
    final pdfDoc = pw.Document();

    const double targetDpi = 300.0;
    const double pdfPointsDpi = 72.0;
    const double dpiScale = targetDpi / pdfPointsDpi; // 4.166667

    final Set<int> excludedSet = excludedPageIndices.toSet();

    for (int pageNum = 1; pageNum <= doc.pages.length; pageNum++) {
      if (shouldExcludePage(pageNum, excludedSet)) {
        continue;
      }

      final page = doc.pages[pageNum - 1];
      final int targetPixelWidth = (page.width * dpiScale).round();
      final int targetPixelHeight = (page.height * dpiScale).round();

      // Render base page to raster bitmap
      final renderedPageImage = await page.render(
        fullWidth: targetPixelWidth.toDouble(),
        fullHeight: targetPixelHeight.toDouble(),
      );

      if (renderedPageImage == null) {
        continue;
      }

      final ui.Image baseUiImage;
      try {
        baseUiImage = await renderedPageImage.createImage();
      } finally {
        renderedPageImage.dispose();
      }

      try {
        final List<InkStroke> pageStrokes = getStrokesForPage(pageNum, strokesPerPage);

        final Uint8List pngBytes;

        if (pageStrokes.isEmpty) {
          final byteData = await baseUiImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) {
            continue;
          }
          pngBytes = byteData.buffer.asUint8List();
        } else {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(
            recorder,
            Rect.fromLTWH(0.0, 0.0, targetPixelWidth.toDouble(), targetPixelHeight.toDouble()),
          );

          // 1. Draw base page raster image
          canvas.drawImage(baseUiImage, Offset.zero, Paint());

          // 2. Scale transform from card display width to 300 DPI raster pixels
          final double strokeScale = cardWidth > 0.0 ? (targetPixelWidth / cardWidth) : dpiScale;
          canvas.save();
          canvas.scale(strokeScale, strokeScale);

          // 3. Paint each stroke
          for (final stroke in pageStrokes) {
            _paintStroke(canvas, stroke);
          }

          canvas.restore();

          final picture = recorder.endRecording();
          ui.Image? compositeUiImage;
          try {
            compositeUiImage = await picture.toImage(targetPixelWidth, targetPixelHeight);
            final byteData = await compositeUiImage.toByteData(format: ui.ImageByteFormat.png);
            if (byteData == null) {
              continue;
            }
            pngBytes = byteData.buffer.asUint8List();
          } finally {
            picture.dispose();
            compositeUiImage?.dispose();
          }
        }

        // 4. Append page to package:pdf document
        pdfDoc.addPage(
          pw.Page(
            pageFormat: pw_pdf.PdfPageFormat(page.width, page.height, marginAll: 0),
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(pngBytes),
                  fit: pw.BoxFit.fill,
                ),
              );
            },
          ),
        );
      } finally {
        baseUiImage.dispose();
      }
    }

    final pdfBytes = await pdfDoc.save();
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(pdfBytes);
  }

  /// Paints a single InkStroke on a Canvas during export flattening.
  void _paintStroke(ui.Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final isHighlighter = stroke.toolType == InkToolType.highlighter;
    final strokeColor = isHighlighter ? stroke.color.withValues(alpha: 0.4) : stroke.color;

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final dotPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(stroke.points.first.point, stroke.strokeWidth / 2.0, dotPaint);
      return;
    }

    final path = InkStroke.buildCatmullRomPath(stroke.points);
    canvas.drawPath(path, paint);
  }

  /// Disposes a specific cached document and releases native Pdfium resources.
  void disposeDocument(String filePath) {
    final doc = _documentCache.remove(filePath);
    doc?.dispose();
    _pageTextCache.remove(filePath);
  }

  /// Disposes all cached documents and text fragments.
  void disposeAll() {
    for (final doc in _documentCache.values) {
      doc.dispose();
    }
    _documentCache.clear();
    _pageTextCache.clear();
  }
}
