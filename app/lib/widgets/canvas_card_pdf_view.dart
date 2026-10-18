import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/canvas_card_model.dart';
import '../models/pdf_internal_object_models.dart';
import '../models/pdf_text_selection_models.dart';
import '../services/pdf_document_service.dart';
import '../services/pdf_region_crop_helper.dart';
import '../services/pdf_search_engine.dart';
import '../services/stem_card_formatter_service.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import '../controllers/pdf_provenance_highlight_controller.dart';
import 'ink_models.dart';
import 'pdf_page_subcard_widget.dart';
import 'pdf_region_crop_overlay.dart';
import 'pdf_toc_sidebar_drawer.dart';
import 'svg_icon.dart';

/// Undecorated inter-page gap allowing stylus ink and canvas dot grid mouse glow through.
/// Hit-testing explicitly returns false so pointer, mouse hover, and stylus events pass through directly.
class PdfInterPageGap extends LeafRenderObjectWidget {
  final double height;

  const PdfInterPageGap({
    super.key,
    this.height = 56.0,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPdfInterPageGap(height);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderPdfInterPageGap renderObject) {
    renderObject.gapHeight = height;
  }
}

class RenderPdfInterPageGap extends RenderBox {
  double _gapHeight;

  RenderPdfInterPageGap(this._gapHeight);

  double get gapHeight => _gapHeight;
  set gapHeight(double value) {
    if (_gapHeight != value) {
      _gapHeight = value;
      markNeedsLayout();
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void performLayout() {
    size = constraints.constrain(Size(constraints.maxWidth, _gapHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 100% transparent and unpainted: canvas dot grid, mouse glow, and stylus ink pass through.
  }
}

/// CanvasCardPdfView manages multi-page PDF document display on the infinite canvas.
/// Key architectural characteristics:
/// - 100% transparent background allowing canvas dot grid, mouse glow, and stylus ink through.
/// - Undecorated 36.0px inter-page separator with hitTestSelf() == false.
/// - Sliding window viewport culling (N-1, N, N+1) to strictly bound GPU texture allocations.
/// - Dynamic camera tracking via panNotifier and zoomNotifier to determine active page N.
/// - SinglePage mode displaying exclusively the active page N.
/// - Automatic synchronization with card.currentPdfPage.
/// - Proper handling and skipping of card.excludedPageIndices.
/// - Page detachment creating independent single-page cards via onDuplicateCard.
class CanvasCardPdfView extends StatefulWidget {
  final CanvasCardModel card;
  final bool isSelected;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueNotifier<Offset>? panNotifier;
  final VoidCallback? onSelectCard;
  final VoidCallback? onDeleteCard;
  final ValueChanged<CanvasCardModel>? onDuplicateCard;
  final ValueChanged<CanvasCardModel>? onAddCard;
  final ValueChanged<CanvasCardModel>? onSolveCardWithAi;
  final ValueChanged<String>? onAskAiText;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;
  final ValueChanged<int>? onPageChanged;
  final Widget? resizeHandles;
  final PdfSearchEngine? searchEngine;

  const CanvasCardPdfView({
    super.key,
    required this.card,
    required this.isSelected,
    required this.onUpdateCard,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    this.panNotifier,
    this.onSelectCard,
    this.onDeleteCard,
    this.onDuplicateCard,
    this.onAddCard,
    this.onSolveCardWithAi,
    this.onAskAiText,
    this.getAttachedStrokes,
    this.activeTool = 'pen',
    this.onSyncCardStrokes,
    this.onPageChanged,
    this.resizeHandles,
    this.searchEngine,
    this.isCropActive = false,
    this.onCancelCrop,
    this.isTocOpen = false,
    this.onCloseToc,
    this.enableMagneticSnap = true,
    this.onSnapToPage,
  });

  final bool isCropActive;
  final VoidCallback? onCancelCrop;
  final bool isTocOpen;
  final VoidCallback? onCloseToc;
  final bool enableMagneticSnap;
  final ValueChanged<int>? onSnapToPage;

  @override
  State<CanvasCardPdfView> createState() => _CanvasCardPdfViewState();
}

class _CanvasCardPdfViewState extends State<CanvasCardPdfView> {
  PdfDocument? _pdfDocument;
  String? _loadedPdfPath;
  late int _activePageNumber;
  Timer? _pageSyncDebounceTimer;
  int? _pendingSyncPage;
  late final PdfSearchEngine _searchEngine;
  late final bool _isLocalSearchEngine;

  void _onSearchResultsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _activePageNumber = widget.card.currentPdfPage;
    _isLocalSearchEngine = widget.searchEngine == null;
    _searchEngine = widget.searchEngine ?? PdfSearchEngine(onNavigateToPage: _onSelectPage);
    _searchEngine.onNavigateToPage ??= _onSelectPage;
    if (!_searchEngine.isDisposed) {
      _searchEngine.resultsNotifier.addListener(_onSearchResultsChanged);
    }
    _loadPdfDocument();
    widget.panNotifier?.addListener(_onCameraChanged);
    widget.zoomNotifier?.addListener(_onCameraChanged);
    PdfProvenanceHighlightController.instance.addListener(_onProvenanceHighlightChanged);
  }

  @override
  void didUpdateWidget(covariant CanvasCardPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.card.pdfPath != _loadedPdfPath) {
      _searchEngine.clearSearch();
      _loadPdfDocument();
    }

    if (widget.card.currentPdfPage != _activePageNumber) {
      _activePageNumber = widget.card.currentPdfPage;
    }

    if (oldWidget.card.pdfDisplayMode != widget.card.pdfDisplayMode) {
      _activeTextSelection = null;
      _pageSyncDebounceTimer?.cancel();
    }

    if (oldWidget.panNotifier != widget.panNotifier) {
      oldWidget.panNotifier?.removeListener(_onCameraChanged);
      widget.panNotifier?.addListener(_onCameraChanged);
    }

    if (oldWidget.zoomNotifier != widget.zoomNotifier) {
      oldWidget.zoomNotifier?.removeListener(_onCameraChanged);
      widget.zoomNotifier?.addListener(_onCameraChanged);
    }
  }

  @override
  void dispose() {
    PdfProvenanceHighlightController.instance.removeListener(_onProvenanceHighlightChanged);
    _pageSyncDebounceTimer?.cancel();
    if (!_searchEngine.isDisposed) {
      _searchEngine.resultsNotifier.removeListener(_onSearchResultsChanged);
    }
    if (_isLocalSearchEngine) {
      _searchEngine.dispose();
    }
    widget.panNotifier?.removeListener(_onCameraChanged);
    widget.zoomNotifier?.removeListener(_onCameraChanged);
    super.dispose();
  }

  void _onProvenanceHighlightChanged() {
    final target = PdfProvenanceHighlightController.instance.value;
    if (target == null) return;
    if (target.cardId != widget.card.id && target.cardId != widget.card.sourceMasterCardId) {
      return;
    }

    final pageW = math.max(10.0, widget.card.width);
    final pageH = math.max(10.0, _getPageHeight(target.pageNumber));
    final norm = target.normalizedBounds;

    final displayRect = norm != null
        ? Rect.fromLTWH(
            norm.left * pageW,
            norm.top * pageH,
            norm.width * pageW,
            norm.height * pageH,
          )
        : Rect.fromLTWH(20.0, 40.0, pageW - 40.0, 60.0);

    if (mounted) {
      setState(() {
        _activePageNumber = target.pageNumber;
        _activeTextSelection = PdfTextSelectionState(
          pageNumber: target.pageNumber,
          startIndex: 0,
          endIndex: target.text?.length ?? 1,
          selectedText: target.text ?? '',
          rects: [displayRect],
          bounds: displayRect,
          isSelecting: false,
        );
      });
    }
  }

  Future<void> _loadPdfDocument() async {
    final path = widget.card.pdfPath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _pdfDocument = null;
          _loadedPdfPath = null;
        });
      }
      return;
    }

    if (_pdfDocument != null && _loadedPdfPath == path) {
      return;
    }

    try {
      final doc = await PdfDocumentService.instance.loadDocument(path);
      if (!mounted) return;
      setState(() {
        _pdfDocument = doc;
        _loadedPdfPath = path;
      });

      final firstPage = doc.pages.isNotEmpty ? doc.pages.first : null;
      final realRatio = (firstPage != null && firstPage.width > 0 && firstPage.height > 0)
          ? (firstPage.width / firstPage.height)
          : null;

      final shouldUpdatePages = widget.card.totalPdfPages != doc.pages.length;
      final shouldUpdateRatio = realRatio != null &&
          (widget.card.originalAspectRatio == null || (widget.card.originalAspectRatio! - realRatio).abs() > 0.001);

      if (shouldUpdatePages || shouldUpdateRatio) {
        widget.onUpdateCard(widget.card.copyWith(
          totalPdfPages: doc.pages.length,
          originalAspectRatio: realRatio ?? widget.card.originalAspectRatio,
        ));
      }
    } catch (e) {
      debugPrint('[CanvasCardPdfView] Error loading PDF from $path: $e');
      if (mounted) {
        setState(() {
          _pdfDocument = null;
          _loadedPdfPath = null;
        });
      }
    }
  }

  void _onCameraChanged() {
    if (!mounted) return;
    if (widget.card.pdfDisplayMode == PdfDisplayMode.singlePage) return;
    _recomputeActivePageFromCamera();
  }

  void _recomputeActivePageFromCamera() {
    final pan = widget.panNotifier?.value ?? Offset.zero;
    final zoom = (widget.zoomNotifier?.value ?? widget.zoomScale).clamp(0.05, 10.0);

    final mediaQuery = MediaQuery.maybeSizeOf(context);
    final viewportHeight = mediaQuery?.height ?? 900.0;

    final canvasCenterY = (viewportHeight / 2.0 - pan.dy) / zoom;
    final cardLocalY = canvasCenterY - widget.card.y;

    final activePages = _getActivePages();
    if (activePages.isEmpty) return;

    final isGrid = widget.card.pdfDisplayMode == PdfDisplayMode.grid;
    int? candidatePage;
    double minDistance = double.infinity;
    double currentTop = 0.0;
    final gap = widget.card.pdfPageGap;

    for (int idx = 0; idx < activePages.length; idx++) {
      final pageNum = activePages[idx];
      final pageH = _getPageHeight(pageNum);
      final pageBottom = currentTop + pageH;
      final pageCenter = currentTop + (pageH / 2.0);

      if (cardLocalY >= (currentTop - gap / 2.0) && cardLocalY <= (pageBottom + gap / 2.0)) {
        candidatePage = pageNum;
        break;
      }

      final dist = (pageCenter - cardLocalY).abs();
      if (dist < minDistance) {
        minDistance = dist;
        candidatePage = pageNum;
      }

      if (!isGrid || idx % 2 == 1) {
        currentTop = pageBottom + gap;
      }
    }

    final newActivePage = candidatePage ?? activePages.first;
    if (newActivePage != _activePageNumber) {
      setState(() {
        _activePageNumber = newActivePage;
      });
      _schedulePageSync(newActivePage);
    }
  }

  void _schedulePageSync(int newPage) {
    _pendingSyncPage = newPage;
    _pageSyncDebounceTimer?.cancel();
    _pageSyncDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (_pendingSyncPage != null && widget.card.currentPdfPage != _pendingSyncPage) {
        final syncedPage = _pendingSyncPage!;
        widget.onUpdateCard(widget.card.copyWith(currentPdfPage: syncedPage));
        widget.onPageChanged?.call(syncedPage);
        if (widget.enableMagneticSnap) {
          widget.onSnapToPage?.call(syncedPage);
        }
        _pendingSyncPage = null;
      }
    });
  }

  List<int> _getActivePages() {
    final total = _pdfDocument?.pages.length ?? widget.card.totalPdfPages;
    final excluded = widget.card.excludedPageIndices.toSet();
    final ordered = widget.card.pageOrder.isNotEmpty
        ? widget.card.pageOrder.where((p) => p >= 1 && p <= total).toList()
        : List<int>.generate(total, (i) => i + 1);
    final active = <int>[];
    for (final p in ordered) {
      if (!excluded.contains(p)) {
        active.add(p);
      }
    }
    return active;
  }

  double _getPageHeight(int pageNumber) {
    final turns = widget.card.pageRotations[pageNumber] ?? 0;
    final isTransposed = (turns % 2) != 0;
    final doc = _pdfDocument;
    if (doc != null && pageNumber >= 1 && pageNumber <= doc.pages.length) {
      final page = doc.pages[pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        final ratio = isTransposed ? (page.width / page.height) : (page.height / page.width);
        return widget.card.width * ratio;
      }
    }
    final double ratio;
    if (isTransposed) {
      ratio = (widget.card.originalAspectRatio != null && widget.card.originalAspectRatio! > 0)
          ? (1.0 / widget.card.originalAspectRatio!)
          : 1.4142;
    } else {
      ratio = (widget.card.originalAspectRatio != null && widget.card.originalAspectRatio! > 0)
          ? widget.card.originalAspectRatio!
          : (1.0 / 1.4142);
    }
    return widget.card.width / ratio;
  }

  double _getPageTopOffset(int targetPage, List<int> activePages) {
    double top = 0.0;
    final gap = widget.card.pdfPageGap;
    for (final p in activePages) {
      if (p == targetPage) return top;
      top += _getPageHeight(p) + gap;
    }
    return top;
  }

  List<InkStroke> _getStrokesForPage(int pageNumber) {
    final strokeIds = widget.card.getStrokesForPage(pageNumber);
    if (strokeIds.isEmpty || widget.getAttachedStrokes == null) {
      return const <InkStroke>[];
    }
    return widget.getAttachedStrokes!(strokeIds.toSet());
  }

  void _onSelectPage(int pageNumber) {
    widget.onSelectCard?.call();
    _pageSyncDebounceTimer?.cancel();
    if (_activePageNumber != pageNumber) {
      setState(() {
        _activePageNumber = pageNumber;
      });
    }
    if (widget.card.currentPdfPage != pageNumber) {
      widget.onUpdateCard(widget.card.copyWith(currentPdfPage: pageNumber));
      widget.onPageChanged?.call(pageNumber);
    }
  }

  void _onDetachPage(int pageNumber) {
    final activePages = _getActivePages();
    final pageTopOffset = _getPageTopOffset(pageNumber, activePages);
    final pageHeight = _getPageHeight(pageNumber);
    final pageStrokes = widget.card.getStrokesForPage(pageNumber);

    final cleanBaseTitle = widget.card.title.replaceAll(RegExp(r'\s*\((Pág|Pag)\.?\s*\d+\)', caseSensitive: false), '').trim();
    final detachedTitle = cleanBaseTitle.isNotEmpty ? cleanBaseTitle : 'Documento PDF';

    final detachedCard = CanvasCardModel(
      id: 'pdf_page_${widget.card.id}_p${pageNumber}_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.pdf,
      title: detachedTitle,
      x: widget.card.x + widget.card.width + 40.0,
      y: widget.card.y + pageTopOffset,
      width: widget.card.width,
      height: pageHeight,
      pdfPath: widget.card.pdfPath,
      pdfDisplayMode: PdfDisplayMode.singlePage,
      currentPdfPage: pageNumber,
      totalPdfPages: widget.card.totalPdfPages,
      originalAspectRatio: widget.card.originalAspectRatio,
      invertLuminance: widget.card.invertLuminance,
      isPdfLocked: false,
      isDetached: true,
      sourceMasterCardId: widget.card.id,
      pageAttachedStrokeIds: <int, List<String>>{pageNumber: List<String>.from(pageStrokes)},
      attachedStrokeIds: List<String>.from(pageStrokes),
    );

    widget.onDuplicateCard?.call(detachedCard);

    final newExcluded = List<int>.from(widget.card.excludedPageIndices);
    if (!newExcluded.contains(pageNumber)) {
      newExcluded.add(pageNumber);
    }

    final newStrokesMap = Map<int, List<String>>.from(widget.card.pageAttachedStrokeIds)
      ..remove(pageNumber);

    final remainingActive = [
      for (int i = 1; i <= widget.card.totalPdfPages; i++)
        if (!newExcluded.contains(i)) i
    ];

    final nextActivePage = remainingActive.contains(_activePageNumber)
        ? _activePageNumber
        : (remainingActive.isNotEmpty ? remainingActive.first : 1);

    final updatedMasterCard = widget.card.copyWith(
      excludedPageIndices: newExcluded,
      pageAttachedStrokeIds: newStrokesMap,
      currentPdfPage: nextActivePage,
    );

    final newMinHeight = updatedMasterCard.calculateMinHeight();
    widget.onUpdateCard(updatedMasterCard.copyWith(height: newMinHeight));

    setState(() {
      _activePageNumber = nextActivePage;
    });
  }

  PdfTextSelectionState? _activeTextSelection;

  void _onTextSelectionChanged(PdfTextSelectionState? selection) {
    if (mounted) {
      setState(() {
        _activeTextSelection = selection;
      });
    }
  }

  void _spawnNewCard(CanvasCardModel newCard) {
    if (widget.onAddCard != null) {
      widget.onAddCard!(newCard);
    } else {
      widget.onDuplicateCard?.call(newCard);
    }
  }

  void _handleGenerateStemCardFromSelection(PdfTextSelectionState selection) {
    final formatResult = StemCardFormatterService.instance.formatSelectedText(
      rawText: selection.selectedText,
      pageNumber: selection.pageNumber,
      documentTitle: widget.card.title,
    );

    final targetPos = _calculateAdjacentPositionForPageRect(
      pageNum: selection.pageNumber,
      rect: selection.bounds,
    );

    final pageW = math.max(10.0, widget.card.width);
    final pageH = math.max(10.0, _getPageHeight(selection.pageNumber));
    final normX = selection.bounds.left / pageW;
    final normY = selection.bounds.top / pageH;
    final normW = selection.bounds.width / pageW;
    final normH = selection.bounds.height / pageH;

    final initialCard = CanvasCardModel(
      id: 'stem_card_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.textLatex,
      title: formatResult.title,
      content: formatResult.content,
      x: targetPos.dx,
      y: targetPos.dy,
      width: formatResult.width,
      height: 100.0,
      sourceMasterCardId: widget.card.sourceMasterCardId ?? widget.card.id,
      sourceDocumentTitle: widget.card.title,
      sourcePageNumber: selection.pageNumber,
      sourceText: selection.selectedText,
      sourceBoundsX: normX,
      sourceBoundsY: normY,
      sourceBoundsWidth: normW,
      sourceBoundsHeight: normH,
    );
    // Ajusta a altura exata para acomodar perfeitamente o texto e a badge de proveniência sem scroll ou espaço excessivo
    final snugHeight = math.max(150.0, initialCard.calculateMinHeight() + 6.0);
    final newCard = initialCard.copyWith(height: snugHeight);
    _spawnNewCard(newCard);
    if (mounted) {
      setState(() {
        _activeTextSelection = null;
      });
    }
  }

  void _handleAskAiFromSelection(PdfTextSelectionState selection) {
    widget.onAskAiText?.call(selection.selectedText);
    if (mounted) {
      setState(() {
        _activeTextSelection = null;
      });
    }
  }

  void _handleHighlightSelection(PdfTextSelectionState selection) {
    if (selection.rects.isEmpty) return;

    final newStrokeIds = <String>{};
    final newStrokes = <InkStroke>[];
    final rnd = math.Random();
    final pageTopOffset = _getPageTopOffset(selection.pageNumber, _getActivePages());

    for (final rect in selection.rects) {
      final strokeId = 'stroke_highlight_${DateTime.now().millisecondsSinceEpoch}_${rnd.nextInt(10000)}';
      newStrokeIds.add(strokeId);

      final startPoint = StrokePoint(
        point: Offset(widget.card.x + rect.left, widget.card.y + pageTopOffset + rect.center.dy),
        pressure: 1.0,
      );
      final endPoint = StrokePoint(
        point: Offset(widget.card.x + rect.right, widget.card.y + pageTopOffset + rect.center.dy),
        pressure: 1.0,
      );

      newStrokes.add(
        InkStroke(
          id: strokeId,
          points: [startPoint, endPoint],
          color: const Color(0xFFF59E0B),
          strokeWidth: math.max(14.0, rect.height),
          toolType: InkToolType.highlighter,
          enablePressure: false,
          parentCardId: widget.card.id,
        ),
      );
    }

    final existingMap = Map<int, List<String>>.from(widget.card.pageAttachedStrokeIds);
    final existingPageStrokes = widget.card.getStrokesForPage(selection.pageNumber);
    existingMap[selection.pageNumber] = {...existingPageStrokes, ...newStrokeIds}.toList();

    final updatedCard = widget.card.copyWith(
      pageAttachedStrokeIds: existingMap,
    );
    widget.onUpdateCard(updatedCard);

    if (widget.onSyncCardStrokes != null) {
      widget.onSyncCardStrokes!(newStrokes, widget.card.id);
    }

    if (mounted) {
      setState(() {
        _activeTextSelection = null;
      });
    }
  }

  Offset _calculateAdjacentPositionForPageRect({required int pageNum, required Rect rect}) {
    final activePages = _getActivePages();
    final double pageTopOffset;

    if (widget.card.pdfDisplayMode == PdfDisplayMode.singlePage) {
      pageTopOffset = 0.0;
    } else if (widget.card.pdfDisplayMode == PdfDisplayMode.grid) {
      final gap = widget.card.pdfPageGap;
      final itemWidth = (widget.card.width - gap) / 2.0;
      final idx = activePages.indexOf(pageNum);
      double rowTop = 0.0;
      for (int i = 0; i < (idx >= 0 ? idx : 0); i += 2) {
        final p1 = activePages[i];
        final p2 = (i + 1 < activePages.length) ? activePages[i + 1] : null;
        final h1 = _getPageHeight(p1) * (itemWidth / widget.card.width);
        final h2 = p2 != null ? _getPageHeight(p2) * (itemWidth / widget.card.width) : 0.0;
        rowTop += math.max(h1, h2) + gap;
      }
      pageTopOffset = rowTop;
    } else {
      pageTopOffset = _getPageTopOffset(pageNum, activePages);
    }

    return PdfRegionCropHelper.calculateAdjacentCardPosition(
      cardX: widget.card.x,
      cardWidth: widget.card.width,
      cardY: widget.card.y + 28.0, // align with visual page below 28px card header
      pageTopOffset: pageTopOffset,
      cropTop: rect.top,
      gap: 28.0,
    );
  }

  void _handleSpawnCardForObject(PdfInternalObject obj, int pageNum) {
    if (obj.type == PdfInternalObjectType.image) {
      _handleCropAsImage(obj.rect);
    } else if (obj.type == PdfInternalObjectType.latexFormula) {
      final targetPos = _calculateAdjacentPositionForPageRect(
        pageNum: pageNum,
        rect: obj.rect,
      );
      final newCard = CanvasCardModel(
        id: 'stem_latex_${DateTime.now().millisecondsSinceEpoch}',
        cardType: CardType.textLatex,
        title: 'Fórmula KaTeX (Pág. $pageNum)',
        content: '\$\$\\begin{aligned}\n${obj.content}\n\\end{aligned}\$\$',
        x: targetPos.dx,
        y: targetPos.dy,
        width: math.max(380.0, obj.rect.width),
        height: math.max(220.0, obj.rect.height),
      );
      _spawnNewCard(newCard);
    } else if (obj.type == PdfInternalObjectType.table) {
      final targetPos = _calculateAdjacentPositionForPageRect(
        pageNum: pageNum,
        rect: obj.rect,
      );
      final newCard = CanvasCardModel(
        id: 'stem_table_${DateTime.now().millisecondsSinceEpoch}',
        cardType: CardType.textLatex,
        title: 'Tabela Estruturada (Pág. $pageNum)',
        content: obj.content,
        x: targetPos.dx,
        y: targetPos.dy,
        width: math.max(420.0, obj.rect.width),
        height: math.max(260.0, obj.rect.height),
      );
      _spawnNewCard(newCard);
    } else {
      final targetPos = _calculateAdjacentPositionForPageRect(
        pageNum: pageNum,
        rect: obj.rect,
      );
      final newCard = CanvasCardModel(
        id: 'stem_text_${DateTime.now().millisecondsSinceEpoch}',
        cardType: CardType.textLatex,
        title: 'Bloco de Texto (Pág. $pageNum)',
        content: obj.content,
        x: targetPos.dx,
        y: targetPos.dy,
        width: math.max(380.0, obj.rect.width),
        height: 240.0,
      );
      _spawnNewCard(newCard);
    }
  }

  void _handleAskAiForObject(PdfInternalObject obj, int pageNum) {
    if (obj.type == PdfInternalObjectType.image) {
      _handleCropAskAi(obj.rect);
    } else {
      widget.onAskAiText?.call(obj.content);
    }
  }

  Offset _calculateCropAdjacentPosition(Rect cropRect) {
    return _calculateAdjacentPositionForPageRect(
      pageNum: _activePageNumber,
      rect: cropRect,
    );
  }

  Future<void> _handleCropAsImage(Rect cropRect) async {
    final pageNum = _activePageNumber;
    final page = (_pdfDocument != null && pageNum >= 1 && pageNum <= _pdfDocument!.pages.length)
        ? _pdfDocument!.pages[pageNum - 1]
        : null;

    final pageWidth = widget.card.width;
    final pageHeight = _getPageHeight(pageNum);
    final nativeW = page?.width ?? pageWidth;
    final nativeH = page?.height ?? pageHeight;

    final base64Image = await PdfRegionCropHelper.cropAndRenderRegion(
      page: page,
      cropRect: cropRect,
      displayedPageWidth: pageWidth,
      displayedPageHeight: pageHeight,
      nativePdfWidth: nativeW,
      nativePdfHeight: nativeH,
    );

    if (base64Image == null) return;

    final targetPos = _calculateCropAdjacentPosition(cropRect);
    final cropAspect = (cropRect.width > 0 && cropRect.height > 0)
        ? cropRect.width / cropRect.height
        : 1.0;
    final targetWidth = cropRect.width.clamp(160.0, 750.0);
    final targetHeight = targetWidth / cropAspect;

    final newCard = CanvasCardModel(
      id: 'crop_media_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.media,
      title: 'Recorte STEM (Pág. $pageNum)',
      x: targetPos.dx,
      y: targetPos.dy,
      width: targetWidth,
      height: targetHeight,
      originalAspectRatio: cropAspect,
      lockAspectRatio: true,
      mediaData: base64Image,
      invertLuminance: widget.card.invertLuminance,
    );

    widget.onDuplicateCard?.call(newCard);
    widget.onCancelCrop?.call();
  }

  Future<void> _handleCropAskAi(Rect cropRect) async {
    final pageNum = _activePageNumber;
    final page = (_pdfDocument != null && pageNum >= 1 && pageNum <= _pdfDocument!.pages.length)
        ? _pdfDocument!.pages[pageNum - 1]
        : null;

    final pageWidth = widget.card.width;
    final pageHeight = _getPageHeight(pageNum);
    final nativeW = page?.width ?? pageWidth;
    final nativeH = page?.height ?? pageHeight;

    final base64Image = await PdfRegionCropHelper.cropAndRenderRegion(
      page: page,
      cropRect: cropRect,
      displayedPageWidth: pageWidth,
      displayedPageHeight: pageHeight,
      nativePdfWidth: nativeW,
      nativePdfHeight: nativeH,
    );

    if (base64Image == null) return;

    final targetPos = _calculateCropAdjacentPosition(cropRect);
    final cropAspect = (cropRect.width > 0 && cropRect.height > 0)
        ? cropRect.width / cropRect.height
        : 1.0;
    final targetWidth = cropRect.width.clamp(160.0, 750.0);
    final targetHeight = targetWidth / cropAspect;

    final newCard = CanvasCardModel(
      id: 'crop_media_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.media,
      title: 'Recorte IA (Pág. $pageNum)',
      x: targetPos.dx,
      y: targetPos.dy,
      width: targetWidth,
      height: targetHeight,
      originalAspectRatio: cropAspect,
      lockAspectRatio: true,
      mediaData: base64Image,
      invertLuminance: widget.card.invertLuminance,
    );

    widget.onDuplicateCard?.call(newCard);
    widget.onSolveCardWithAi?.call(newCard);
    widget.onCancelCrop?.call();
  }

  Future<void> _handleCropAsStemCard(Rect cropRect) async {
    final pageNum = _activePageNumber;
    final targetPos = _calculateCropAdjacentPosition(cropRect);

    final newCard = CanvasCardModel(
      id: 'crop_stem_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.textLatex,
      title: 'Anotação STEM (Pág. $pageNum)',
      content: '\$\$\\begin{aligned}\n'
          '\\text{Resolução / Fórmulas da Questão (Pág. $pageNum)}\n'
          '\\end{aligned}\$\$\n\n'
          '---\n*Anote aqui os passos da resolução e teoremas aplicados.*',
      x: targetPos.dx,
      y: targetPos.dy,
      width: math.max(360.0, cropRect.width),
      height: 240.0,
    );

    widget.onDuplicateCard?.call(newCard);
    widget.onCancelCrop?.call();
  }

  Future<void> _handleCropExtractLatex(Rect cropRect) async {
    final pageNum = _activePageNumber;
    final targetPos = _calculateCropAdjacentPosition(cropRect);

    final newCard = CanvasCardModel(
      id: 'crop_latex_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.textLatex,
      title: 'Fórmula KaTeX (Pág. $pageNum)',
      content: '\$\$\\begin{aligned}\n'
          '\\text{Fórmula Extraída (Pág. $pageNum)}\n'
          r'f(x) = \int_{0}^{\infty} \frac{\sin(t)}{t} \, dt = \frac{\pi}{2}' '\n'
          r'\end{aligned}\$\$',
      x: targetPos.dx,
      y: targetPos.dy,
      width: math.max(380.0, cropRect.width),
      height: 220.0,
    );

    widget.onDuplicateCard?.call(newCard);
    widget.onCancelCrop?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card.pdfPath == null || widget.card.pdfPath!.isEmpty) {
      return _buildEmptyPdfPlaceholder();
    }

    final activePages = _getActivePages();
    if (activePages.isEmpty) {
      return _buildAllPagesDetachedPlaceholder();
    }

    Widget body;
    if (widget.card.pdfDisplayMode == PdfDisplayMode.singlePage) {
      body = _buildSinglePageLayout(activePages);
    } else if (widget.card.pdfDisplayMode == PdfDisplayMode.grid) {
      body = _buildGridLayout(activePages);
    } else {
      body = _buildContinuousLayout(activePages);
    }

    void handleToggleBookmark(int page) {
      final bookmarks = List<int>.from(widget.card.bookmarkedPages);
      if (bookmarks.contains(page)) {
        bookmarks.remove(page);
      } else {
        bookmarks.add(page);
      }
      widget.onUpdateCard(widget.card.copyWith(bookmarkedPages: bookmarks));
    }

    void handlePageJump(int page) {
      setState(() => _activePageNumber = page);
      widget.onPageChanged?.call(page);
      widget.onUpdateCard(widget.card.copyWith(currentPdfPage: page));
    }

    if (widget.isCropActive || widget.isTocOpen) {
      final pageNum = _activePageNumber;
      final double cropTop;
      final double cropLeft;
      final double cropWidth;
      final double cropHeight;

      if (widget.card.pdfDisplayMode == PdfDisplayMode.singlePage) {
        cropTop = 0.0;
        cropLeft = 0.0;
        cropWidth = widget.card.width;
        cropHeight = _getPageHeight(pageNum);
      } else if (widget.card.pdfDisplayMode == PdfDisplayMode.grid) {
        final gap = widget.card.pdfPageGap;
        final itemWidth = (widget.card.width - gap) / 2.0;
        final idx = activePages.indexOf(pageNum);
        final col = (idx >= 0 ? idx : 0) % 2;
        cropLeft = col == 0 ? 0.0 : itemWidth + gap;
        cropWidth = itemWidth;
        cropHeight = _getPageHeight(pageNum) * (itemWidth / widget.card.width);

        double rowTop = 0.0;
        for (int i = 0; i < (idx >= 0 ? idx : 0); i += 2) {
          final p1 = activePages[i];
          final p2 = (i + 1 < activePages.length) ? activePages[i + 1] : null;
          final h1 = _getPageHeight(p1) * (itemWidth / widget.card.width);
          final h2 = p2 != null ? _getPageHeight(p2) * (itemWidth / widget.card.width) : 0.0;
          rowTop += math.max(h1, h2) + gap;
        }
        cropTop = rowTop;
      } else {
        cropTop = _getPageTopOffset(pageNum, activePages);
        cropLeft = 0.0;
        cropWidth = widget.card.width;
        cropHeight = _getPageHeight(pageNum);
      }

      return SizedBox(
        width: widget.card.width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            body,
            if (widget.isCropActive)
              Positioned(
                top: cropTop,
                left: cropLeft,
                width: cropWidth,
                height: cropHeight,
                child: PdfRegionCropOverlay(
                  pageWidth: cropWidth,
                  pageHeight: cropHeight,
                  onCropAsImage: _handleCropAsImage,
                  onCropSendToAi: _handleCropAskAi,
                  onCropAsStemCard: _handleCropAsStemCard,
                  onCropExtractLatex: _handleCropExtractLatex,
                  onCancel: () => widget.onCancelCrop?.call(),
                ),
              ),
            if (widget.isTocOpen)
              Positioned(
                top: 0,
                left: widget.card.width + 12.0,
                child: PdfTocSidebarDrawer(
                  card: widget.card,
                  exactHeight: _getPageHeight(_activePageNumber),
                  onPageJump: handlePageJump,
                  onToggleBookmark: handleToggleBookmark,
                  onClose: () => widget.onCloseToc?.call(),
                ),
              ),
          ],
        ),
      );
    }

    return body;
  }

  Widget _buildGridLayout(List<int> activePages) {
    final gap = widget.card.pdfPageGap;
    final itemWidth = (widget.card.width - gap) / 2.0;
    final zoom = widget.zoomNotifier?.value ?? widget.zoomScale;
    final searchResult = _searchEngine.currentResult;

    int activeIdx = activePages.indexOf(_activePageNumber);
    if (activeIdx == -1) {
      activeIdx = 0;
    }
    final int activeRow = activeIdx ~/ 2;

    final rows = <Widget>[];
    for (int i = 0; i < activePages.length; i += 2) {
      final int currentRow = i ~/ 2;
      final bool isVisible = (currentRow - activeRow).abs() <= 2;

      final p1 = activePages[i];
      final p2 = (i + 1 < activePages.length) ? activePages[i + 1] : null;

      final p1Height = _getPageHeight(p1) * (itemWidth / widget.card.width);
      final Widget item1;
      if (isVisible) {
        final p1Strokes = _getStrokesForPage(p1);
        final p1Matches = searchResult.matchesForPage(p1);
        final p1ActiveMatch = (searchResult.currentMatch?.pageNumber == p1)
            ? searchResult.currentMatch
            : null;

        item1 = PdfPageSubcardWidget(
          key: ValueKey('pdf_subcard_${widget.card.id}_p$p1'),
          document: _pdfDocument,
          pageNumber: p1,
          width: itemWidth,
          height: p1Height,
          pageX: widget.card.x,
          pageY: widget.card.y,
          isPageSelected: p1 == _activePageNumber && widget.isSelected,
          isDocumentSelected: widget.isSelected,
          invertLuminance: widget.card.invertLuminance,
          isPdfLocked: widget.card.isPdfLocked,
          zoomScale: zoom,
          onSelectPage: _onSelectPage,
          onSelectWholeDocument: widget.onSelectCard,
          onDetachPage: _onDetachPage,
          attachedStrokes: p1Strokes,
          searchMatches: p1Matches,
          activeSearchMatch: p1ActiveMatch,
          activeTool: widget.activeTool,
          textSelection: _activeTextSelection,
          onTextSelectionChanged: _onTextSelectionChanged,
          onGenerateStemCardFromSelection: _activeTextSelection != null
              ? () => _handleGenerateStemCardFromSelection(_activeTextSelection!)
              : null,
          onAskAiSelection: _activeTextSelection != null
              ? () => _handleAskAiFromSelection(_activeTextSelection!)
              : null,
          onHighlightSelection: _activeTextSelection != null
              ? () => _handleHighlightSelection(_activeTextSelection!)
              : null,
          rotationQuarterTurns: widget.card.pageRotations[p1] ?? 0,
          onSpawnCardForObject: (obj) => _handleSpawnCardForObject(obj, p1),
          onAskAiObject: (obj) => _handleAskAiForObject(obj, p1),
        );
      } else {
        item1 = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onSelectPage(p1),
          child: Container(
            width: itemWidth,
            height: p1Height,
            decoration: BoxDecoration(
              color: MoscaroTokens.glassTint,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: MoscaroTokens.borderGlow.withValues(alpha: 0.15),
              ),
            ),
          ),
        );
      }

      Widget? item2;
      if (p2 != null) {
        final p2Height = _getPageHeight(p2) * (itemWidth / widget.card.width);
        if (isVisible) {
          final p2Strokes = _getStrokesForPage(p2);
          final p2Matches = searchResult.matchesForPage(p2);
          final p2ActiveMatch = (searchResult.currentMatch?.pageNumber == p2)
              ? searchResult.currentMatch
              : null;

          item2 = PdfPageSubcardWidget(
            key: ValueKey('pdf_subcard_${widget.card.id}_p$p2'),
            document: _pdfDocument,
            pageNumber: p2,
            width: itemWidth,
            height: p2Height,
            pageX: widget.card.x + itemWidth + gap,
            pageY: widget.card.y,
            isPageSelected: p2 == _activePageNumber && widget.isSelected,
            isDocumentSelected: widget.isSelected,
            invertLuminance: widget.card.invertLuminance,
            isPdfLocked: widget.card.isPdfLocked,
            zoomScale: zoom,
            onSelectPage: _onSelectPage,
            onSelectWholeDocument: widget.onSelectCard,
            onDetachPage: _onDetachPage,
            attachedStrokes: p2Strokes,
            searchMatches: p2Matches,
            activeSearchMatch: p2ActiveMatch,
            activeTool: widget.activeTool,
            textSelection: _activeTextSelection,
            onTextSelectionChanged: _onTextSelectionChanged,
            onGenerateStemCardFromSelection: _activeTextSelection != null
                ? () => _handleGenerateStemCardFromSelection(_activeTextSelection!)
                : null,
            onAskAiSelection: _activeTextSelection != null
                ? () => _handleAskAiFromSelection(_activeTextSelection!)
                : null,
            onHighlightSelection: _activeTextSelection != null
                ? () => _handleHighlightSelection(_activeTextSelection!)
                : null,
            rotationQuarterTurns: widget.card.pageRotations[p2] ?? 0,
            onSpawnCardForObject: (obj) => _handleSpawnCardForObject(obj, p2),
            onAskAiObject: (obj) => _handleAskAiForObject(obj, p2),
          );
        } else {
          item2 = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onSelectPage(p2),
            child: Container(
              width: itemWidth,
              height: p2Height,
              decoration: BoxDecoration(
                color: MoscaroTokens.glassTint,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: MoscaroTokens.borderGlow.withValues(alpha: 0.15),
                ),
              ),
            ),
          );
        }
      }

      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item1,
            if (item2 != null) ...[
              SizedBox(width: gap),
              item2,
            ] else
              SizedBox(width: itemWidth + gap),
          ],
        ),
      );

      if (i + 2 < activePages.length) {
        rows.add(SizedBox(height: gap));
      }
    }

    return SizedBox(
      width: widget.card.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rows,
      ),
    );
  }

  Widget _buildSinglePageLayout(List<int> activePages) {
    final pageNum = activePages.contains(widget.card.currentPdfPage)
        ? widget.card.currentPdfPage
        : (activePages.contains(_activePageNumber)
            ? _activePageNumber
            : activePages.first);

    final pageHeight = _getPageHeight(pageNum);
    final strokes = _getStrokesForPage(pageNum);
    final searchResult = _searchEngine.currentResult;
    final pageMatches = searchResult.matchesForPage(pageNum);
    final activeMatch = (searchResult.currentMatch?.pageNumber == pageNum)
        ? searchResult.currentMatch
        : null;

    return SizedBox(
      key: ValueKey('pdf_single_box_${widget.card.id}_p$pageNum'),
      width: widget.card.width,
      height: pageHeight,
      child: PdfPageSubcardWidget(
        key: ValueKey('pdf_subcard_${widget.card.id}_p$pageNum'),
        document: _pdfDocument,
        pageNumber: pageNum,
        width: widget.card.width,
        height: pageHeight,
        pageX: widget.card.x,
        pageY: widget.card.y,
        isPageSelected: widget.isSelected,
        isDocumentSelected: widget.isSelected,
        invertLuminance: widget.card.invertLuminance,
        isPdfLocked: widget.card.isPdfLocked,
        zoomScale: widget.zoomNotifier?.value ?? widget.zoomScale,
        onSelectPage: _onSelectPage,
        onSelectWholeDocument: widget.onSelectCard,
        onDetachPage: _onDetachPage,
        attachedStrokes: strokes,
        resizeHandles: widget.resizeHandles,
        searchMatches: pageMatches,
        activeSearchMatch: activeMatch,
        activeTool: widget.activeTool,
        textSelection: _activeTextSelection,
        onTextSelectionChanged: _onTextSelectionChanged,
        onGenerateStemCardFromSelection: _activeTextSelection != null
            ? () => _handleGenerateStemCardFromSelection(_activeTextSelection!)
            : null,
        onAskAiSelection: _activeTextSelection != null
            ? () => _handleAskAiFromSelection(_activeTextSelection!)
            : null,
        onHighlightSelection: _activeTextSelection != null
            ? () => _handleHighlightSelection(_activeTextSelection!)
            : null,
        rotationQuarterTurns: widget.card.pageRotations[pageNum] ?? 0,
        onSpawnCardForObject: (obj) => _handleSpawnCardForObject(obj, pageNum),
        onAskAiObject: (obj) => _handleAskAiForObject(obj, pageNum),
      ),
    );
  }

  Widget _buildContinuousLayout(List<int> activePages) {
    int activeIdx = activePages.indexOf(_activePageNumber);
    if (activeIdx == -1) {
      activeIdx = 0;
      _activePageNumber = activePages.first;
    }

    final windowSet = <int>{};
    if (activeIdx > 0) {
      windowSet.add(activePages[activeIdx - 1]);
    }
    windowSet.add(activePages[activeIdx]);
    if (activeIdx < activePages.length - 1) {
      windowSet.add(activePages[activeIdx + 1]);
    }

    final children = <Widget>[];
    double currentTop = 0.0;
    final gap = widget.card.pdfPageGap;
    final zoom = widget.zoomNotifier?.value ?? widget.zoomScale;
    final searchResult = _searchEngine.currentResult;

    for (int i = 0; i < activePages.length; i++) {
      final pageNum = activePages[i];
      final pageHeight = _getPageHeight(pageNum);
      final isVisibleInWindow = windowSet.contains(pageNum);
      final pageY = widget.card.y + currentTop;

      if (isVisibleInWindow) {
        final strokes = _getStrokesForPage(pageNum);
        final pageMatches = searchResult.matchesForPage(pageNum);
        final activeMatch = (searchResult.currentMatch?.pageNumber == pageNum)
            ? searchResult.currentMatch
            : null;
        children.add(
          PdfPageSubcardWidget(
            key: ValueKey('pdf_subcard_${widget.card.id}_p$pageNum'),
            document: _pdfDocument,
            pageNumber: pageNum,
            width: widget.card.width,
            height: pageHeight,
            pageX: widget.card.x,
            pageY: pageY,
            isPageSelected: pageNum == _activePageNumber && widget.isSelected,
            isDocumentSelected: widget.isSelected,
            invertLuminance: widget.card.invertLuminance,
            isPdfLocked: widget.card.isPdfLocked,
            zoomScale: zoom,
            onSelectPage: _onSelectPage,
            onSelectWholeDocument: widget.onSelectCard,
            onDetachPage: _onDetachPage,
            attachedStrokes: strokes,
            searchMatches: pageMatches,
            activeSearchMatch: activeMatch,
            activeTool: widget.activeTool,
            textSelection: _activeTextSelection,
            onTextSelectionChanged: _onTextSelectionChanged,
            onGenerateStemCardFromSelection: _activeTextSelection != null
                ? () => _handleGenerateStemCardFromSelection(_activeTextSelection!)
                : null,
            onAskAiSelection: _activeTextSelection != null
                ? () => _handleAskAiFromSelection(_activeTextSelection!)
                : null,
            onHighlightSelection: _activeTextSelection != null
                ? () => _handleHighlightSelection(_activeTextSelection!)
                : null,
            rotationQuarterTurns: widget.card.pageRotations[pageNum] ?? 0,
            onSpawnCardForObject: (obj) => _handleSpawnCardForObject(obj, pageNum),
            onAskAiObject: (obj) => _handleAskAiForObject(obj, pageNum),
          ),
        );
      } else {
        children.add(
          GestureDetector(
            key: ValueKey('pdf_culled_placeholder_${widget.card.id}_p$pageNum'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _onSelectPage(pageNum),
            child: Container(
              width: widget.card.width,
              height: pageHeight,
              decoration: BoxDecoration(
                color: MoscaroTokens.glassTint,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: MoscaroTokens.borderGlow.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        );
      }

      currentTop += pageHeight;

      if (i < activePages.length - 1) {
        children.add(
          PdfInterPageGap(
            key: ValueKey('pdf_gap_${widget.card.id}_p${pageNum}_to_${activePages[i + 1]}'),
            height: gap,
          ),
        );
        currentTop += gap;
      }
    }

    return ClipRect(
      child: SizedBox(
        width: widget.card.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _buildEmptyPdfPlaceholder() {
    final themeAccent = MoscaroThemeController.instance.currentTheme.accentPrimary;
    return Container(
      width: widget.card.width,
      height: math.max(140.0, widget.card.height),
      decoration: BoxDecoration(
        color: widget.card.customGlassColor ?? MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: themeAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: 'layers',
              size: 28,
              color: themeAccent.withValues(alpha: 0.70),
            ),
            const SizedBox(height: 10),
            Text(
              'Nenhum documento PDF vinculado',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: MoscaroTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllPagesDetachedPlaceholder() {
    final themeAccent = MoscaroThemeController.instance.currentTheme.accentPrimary;
    return Container(
      width: widget.card.width,
      height: 120.0,
      decoration: BoxDecoration(
        color: widget.card.customGlassColor ?? MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: themeAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: 'share',
              size: 24,
              color: themeAccent.withValues(alpha: 0.70),
            ),
            const SizedBox(height: 8),
            Text(
              'Todas as páginas foram desprendidas',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: MoscaroTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
