import 'dart:ui';

/// Represents an active or completed text selection on a PDF page sheet.
class PdfTextSelectionState {
  /// 1-based page number where selection is occurring.
  final int pageNumber;

  /// Global character start index within the page text.
  final int startIndex;

  /// Global character end index within the page text.
  final int endIndex;

  /// The raw text string selected.
  final String selectedText;

  /// Bounding rectangles of all selected lines in display page coordinates.
  final List<Rect> rects;

  /// Overall bounding box enclosing the entire selection on the page sheet.
  final Rect bounds;

  /// Whether user is currently dragging to expand or contract selection.
  final bool isSelecting;

  const PdfTextSelectionState({
    required this.pageNumber,
    required this.startIndex,
    required this.endIndex,
    required this.selectedText,
    required this.rects,
    required this.bounds,
    this.isSelecting = false,
  });

  bool get isEmpty => selectedText.isEmpty || rects.isEmpty;
  bool get isNotEmpty => !isEmpty;

  static const PdfTextSelectionState empty = PdfTextSelectionState(
    pageNumber: 1,
    startIndex: 0,
    endIndex: 0,
    selectedText: '',
    rects: <Rect>[],
    bounds: Rect.zero,
    isSelecting: false,
  );

  PdfTextSelectionState copyWith({
    int? pageNumber,
    int? startIndex,
    int? endIndex,
    String? selectedText,
    List<Rect>? rects,
    Rect? bounds,
    bool? isSelecting,
  }) {
    return PdfTextSelectionState(
      pageNumber: pageNumber ?? this.pageNumber,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      selectedText: selectedText ?? this.selectedText,
      rects: rects ?? this.rects,
      bounds: bounds ?? this.bounds,
      isSelecting: isSelecting ?? this.isSelecting,
    );
  }
}
