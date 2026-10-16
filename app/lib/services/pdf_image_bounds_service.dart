import 'dart:ffi';
import 'dart:math' as math;
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:pdfrx/src/pdfium/pdfium_bindings.dart' as pdfium_bindings;
// ignore: implementation_imports
import 'package:pdfrx/src/pdfium/pdfrx_pdfium.dart';

/// Serviço nativo de inspeção geométrica via Google PDFium (sem heurísticas frágeis).
/// Extrai os retângulos matemáticos exatos de ilustrações/figuras para suprimir
/// a seleção indevida de rótulos de texto sobrepostos a diagramas (ex: redes cristalinas,
/// fórmulas gráficas, etc.), reservando essas regiões exclusivamente para a ferramenta de Crop.
class PdfImageBoundsService {
  PdfImageBoundsService._internal();

  static final PdfImageBoundsService instance = PdfImageBoundsService._internal();

  final Map<String, Map<int, List<Rect>>> _cache = {};

  /// Retorna as regiões (Rect em Flutter space) de todas as figuras da página.
  /// Descarta imagens de página inteira (área >= 90%) para não afetar páginas escaneadas com OCR.
  List<Rect> getImageRectsForPageSync({
    required String pdfPath,
    required int pageNumber,
    required double nativePageWidth,
    required double nativePageHeight,
  }) {
    if (pdfPath.isEmpty || pageNumber < 1) return const [];

    final docMap = _cache.putIfAbsent(pdfPath, () => {});
    if (docMap.containsKey(pageNumber)) {
      return docMap[pageNumber]!;
    }

    try {
      final pathPtr = pdfPath.toNativeUtf8();
      final doc = pdfium.FPDF_LoadDocument(pathPtr.cast<Char>(), nullptr.cast<Char>());
      malloc.free(pathPtr);

      if (doc.address == 0) {
        docMap[pageNumber] = const [];
        return const [];
      }

      try {
        final pageIndex = pageNumber - 1;
        final page = pdfium.FPDF_LoadPage(doc, pageIndex);
        if (page.address == 0) {
          docMap[pageNumber] = const [];
          return const [];
        }

        final imageRects = <Rect>[];
        final pageArea = nativePageWidth * nativePageHeight;

        try {
          final count = pdfium.FPDFPage_CountObjects(page);
          final pLeft = calloc<Float>();
          final pBottom = calloc<Float>();
          final pRight = calloc<Float>();
          final pTop = calloc<Float>();

          try {
            for (int i = 0; i < count; i++) {
              final obj = pdfium.FPDFPage_GetObject(page, i);
              if (obj.address == 0) continue;

              final type = pdfium.FPDFPageObj_GetType(obj);
              if (type == pdfium_bindings.FPDF_PAGEOBJ_IMAGE) {
                final ok = pdfium.FPDFPageObj_GetBounds(obj, pLeft, pBottom, pRight, pTop);
                if (ok != 0) {
                  final l = pLeft.value;
                  final b = pBottom.value;
                  final r = pRight.value;
                  final t = pTop.value;

                  final width = (r - l).abs();
                  final height = (t - b).abs();
                  final imageArea = width * height;

                  // Salvaguarda OCR: descarta imagens de página inteira (livros escaneados)
                  if (pageArea > 0 && (imageArea / pageArea) >= 0.90) {
                    continue;
                  }

                  // Converter de PDF space (origem inferior-esquerda, Y para cima)
                  // para Flutter space (origem superior-esquerda, Y para baixo)
                  final flutterTop = nativePageHeight - t;
                  final flutterBottom = nativePageHeight - b;
                  final top = math.min(flutterTop, flutterBottom);
                  final bottom = math.max(flutterTop, flutterBottom);
                  final left = math.min(l, r);
                  final right = math.max(l, r);

                  imageRects.add(Rect.fromLTRB(left, top, right, bottom));
                }
              }
            }
          } finally {
            calloc.free(pLeft);
            calloc.free(pBottom);
            calloc.free(pRight);
            calloc.free(pTop);
          }
        } finally {
          pdfium.FPDF_ClosePage(page);
        }

        docMap[pageNumber] = imageRects;
        return imageRects;
      } finally {
        pdfium.FPDF_CloseDocument(doc);
      }
    } catch (e) {
      debugPrint('[PdfImageBoundsService] Error extracting image rects: $e');
      docMap[pageNumber] = const [];
      return const [];
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
