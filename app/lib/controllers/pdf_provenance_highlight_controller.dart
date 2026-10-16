import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Define o alvo e os limites geométricos normalizados para destacar visualmente
/// o trecho de texto no PDF que deu origem a um card STEM.
class PdfProvenanceHighlightTarget {
  final String cardId;
  final int pageNumber;
  final String? text;
  final Rect? normalizedBounds;

  const PdfProvenanceHighlightTarget({
    required this.cardId,
    required this.pageNumber,
    this.text,
    this.normalizedBounds,
  });
}

/// Controlador reativo que gerencia o destaque luminoso e a seleção
/// instantânea de proveniência de texto nos cards de PDF do canvas.
class PdfProvenanceHighlightController extends ValueNotifier<PdfProvenanceHighlightTarget?> {
  static final PdfProvenanceHighlightController instance = PdfProvenanceHighlightController._();

  PdfProvenanceHighlightController._() : super(null);

  void triggerHighlight({
    required String cardId,
    required int pageNumber,
    String? text,
    Rect? normalizedBounds,
  }) {
    value = PdfProvenanceHighlightTarget(
      cardId: cardId,
      pageNumber: pageNumber,
      text: text,
      normalizedBounds: normalizedBounds,
    );
  }

  void clear() {
    value = null;
  }
}
