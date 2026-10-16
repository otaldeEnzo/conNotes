import 'dart:typed_data';
import 'dart:ui';

/// Types of extractable structured objects embedded within a PDF page sheet.
enum PdfInternalObjectType {
  /// Raster image or embedded figure/diagram.
  image,

  /// Continuous block or paragraph of text.
  textBlock,

  /// Structured multi-row/multi-column data table.
  table,

  /// Mathematical equation, KaTeX/LaTeX expression, or formula block.
  formula;

  /// Alias for formula expressions in LaTeX format.
  static const PdfInternalObjectType latexFormula = PdfInternalObjectType.formula;
}

/// Represents an identified internal entity residing on a specific PDF page.
class PdfInternalObject {
  /// Unique identifier of the object within the session/document.
  final String id;

  /// 1-based page index where the object is situated.
  final int pageNumber;

  /// Bounding rectangle in normalized page coordinates (0.0 .. 1.0) or native PDF points.
  final Rect bounds;

  /// Classification of the object.
  final PdfInternalObjectType type;

  /// Raw textual content or recognized transcription (empty for pure images).
  final String textContent;

  /// Alias getter for bounds.
  Rect get rect => bounds;

  /// Alias getter for textContent.
  String get content => textContent;

  /// Raw image bytes when extracted or cached as bitmap (PNG/JPEG).
  final Uint8List? imageBytes;

  /// Optional base64 representation of the image for CanvasCardModel.mediaData compatibility.
  final String? base64Data;

  /// Detection confidence rating between 0.0 and 1.0.
  final double confidence;

  /// Optional metadata such as column count, row count, or LaTeX syntax string.
  final Map<String, dynamic> metadata;

  const PdfInternalObject({
    required this.id,
    required this.pageNumber,
    required this.bounds,
    required this.type,
    this.textContent = '',
    this.imageBytes,
    this.base64Data,
    this.confidence = 1.0,
    this.metadata = const <String, dynamic>{},
  });

  /// True if this object represents graphical media (image or diagram).
  bool get isImage => type == PdfInternalObjectType.image;

  /// True if this object represents tabular data.
  bool get isTable => type == PdfInternalObjectType.table;

  /// True if this object represents a mathematical equation/formula.
  bool get isFormula => type == PdfInternalObjectType.formula;

  /// True if this object is a standard textual paragraph or heading.
  bool get isTextBlock => type == PdfInternalObjectType.textBlock;

  PdfInternalObject copyWith({
    String? id,
    int? pageNumber,
    Rect? bounds,
    PdfInternalObjectType? type,
    String? textContent,
    Uint8List? imageBytes,
    String? base64Data,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return PdfInternalObject(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      bounds: bounds ?? this.bounds,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      imageBytes: imageBytes ?? this.imageBytes,
      base64Data: base64Data ?? this.base64Data,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }
}
