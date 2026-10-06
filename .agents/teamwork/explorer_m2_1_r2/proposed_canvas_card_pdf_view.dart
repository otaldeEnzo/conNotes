import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/canvas_card_model.dart';
import '../services/pdf_document_service.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'ink_models.dart';
import 'pdf_page_subcard_widget.dart';
import 'svg_icon.dart';

/// Undecorated inter-page gap allowing stylus ink and canvas dot grid mouse glow through.
/// Hit-testing explicitly returns false so pointer, mouse hover, and stylus events pass through directly.
class PdfInterPageGap extends LeafRenderObjectWidget {
  final double height;

  const PdfInterPageGap({
    super.key,
    this.height = 36.0,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPdfInterPageGap(height);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderPdfInterPageGap renderObject) {
    renderObject.gapHeight = height;
  }
}

class _RenderPdfInterPageGap extends RenderBox {
  double _gapHeight;

  _RenderPdfInterPageGap(this._gapHeight);

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
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;
  final ValueChanged<int>? onPageChanged;
  final Widget? resizeHandles;

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
    this.getAttachedStrokes,
    this.activeTool = 'pen',
    this.onSyncCardStrokes,
    this.onPageChanged,
    this.resizeHandles,
  });

  @override
  State<CanvasCardPdfView> createState() => _CanvasCardPdfViewState();
}

class _CanvasCardPdfViewState extends State<CanvasCardPdfView> {
  PdfDocument? _pdfDocument;
  String? _loadedPdfPath;
  late int _activePageNumber;
  Timer? _pageSyncDebounceTimer;
  int? _pendingSyncPage;

  @override
  void initState() {
    super.initState();
    _activePageNumber = widget.card.currentPdfPage;
    _loadPdfDocument();
    widget.panNotifier?.addListener(_onCameraChanged);
    widget.zoomNotifier?.addListener(_onCameraChanged);
  }

  @override
  void didUpdateWidget(covariant CanvasCardPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.card.pdfPath != _loadedPdfPath) {
      _loadPdfDocument();
    }

    if (widget.card.currentPdfPage != oldWidget.card.currentPdfPage &&
        widget.card.currentPdfPage != _activePageNumber) {
      _activePageNumber = widget.card.currentPdfPage;
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
    _pageSyncDebounceTimer?.cancel();
    widget.panNotifier?.removeListener(_onCameraChanged);
    widget.zoomNotifier?.removeListener(_onCameraChanged);
    super.dispose();
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

      if (widget.card.totalPdfPages != doc.pages.length) {
        widget.onUpdateCard(widget.card.copyWith(totalPdfPages: doc.pages.length));
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

    int? candidatePage;
    double minDistance = double.infinity;
    double currentTop = 0.0;
    final gap = widget.card.pdfPageGap;

    for (final pageNum in activePages) {
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

      currentTop = pageBottom + gap;
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
        widget.onUpdateCard(widget.card.copyWith(currentPdfPage: _pendingSyncPage!));
        widget.onPageChanged?.call(_pendingSyncPage!);
        _pendingSyncPage = null;
      }
    });
  }

  List<int> _getActivePages() {
    final total = _pdfDocument?.pages.length ?? widget.card.totalPdfPages;
    final excluded = widget.card.excludedPageIndices.toSet();
    final active = <int>[];
    for (int i = 1; i <= total; i++) {
      if (!excluded.contains(i)) {
        active.add(i);
      }
    }
    return active;
  }

  double _getPageHeight(int pageNumber) {
    final doc = _pdfDocument;
    if (doc != null && pageNumber >= 1 && pageNumber <= doc.pages.length) {
      final page = doc.pages[pageNumber - 1];
      if (page.width > 0 && page.height > 0) {
        return widget.card.width * (page.height / page.width);
      }
    }
    final ratio = (widget.card.originalAspectRatio != null && widget.card.originalAspectRatio! > 0)
        ? widget.card.originalAspectRatio!
        : (1.0 / 1.4142);
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

    final detachedCard = CanvasCardModel(
      id: 'pdf_page_${widget.card.id}_p${pageNumber}_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.pdf,
      title: '${widget.card.title} (Pag. $pageNumber)',
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

  @override
  Widget build(BuildContext context) {
    if (widget.card.pdfPath == null || widget.card.pdfPath!.isEmpty) {
      return _buildEmptyPdfPlaceholder();
    }

    final activePages = _getActivePages();
    if (activePages.isEmpty) {
      return _buildAllPagesDetachedPlaceholder();
    }

    if (widget.card.pdfDisplayMode == PdfDisplayMode.singlePage) {
      return _buildSinglePageLayout(activePages);
    }

    return _buildContinuousLayout(activePages);
  }

  Widget _buildSinglePageLayout(List<int> activePages) {
    final pageNum = activePages.contains(_activePageNumber)
        ? _activePageNumber
        : activePages.first;

    final pageHeight = _getPageHeight(pageNum);
    final strokes = _getStrokesForPage(pageNum);

    return SizedBox(
      width: widget.card.width,
      height: pageHeight,
      child: PdfPageSubcardWidget(
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

    for (int i = 0; i < activePages.length; i++) {
      final pageNum = activePages[i];
      final pageHeight = _getPageHeight(pageNum);
      final isVisibleInWindow = windowSet.contains(pageNum);
      final pageY = widget.card.y + currentTop;

      if (isVisibleInWindow) {
        final strokes = _getStrokesForPage(pageNum);
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
          ),
        );
      } else {
        children.add(
          SizedBox(
            key: ValueKey('pdf_culled_placeholder_${widget.card.id}_p$pageNum'),
            width: widget.card.width,
            height: pageHeight,
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

    return SizedBox(
      width: widget.card.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildEmptyPdfPlaceholder() {
    return Container(
      width: widget.card.width,
      height: math.max(140.0, widget.card.height),
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: MoscaroTokens.borderGlowActive.withValues(alpha: 0.3),
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
              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.6),
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
    return Container(
      width: widget.card.width,
      height: 120.0,
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: MoscaroTokens.borderGlow.withValues(alpha: 0.3),
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
              color: MoscaroTokens.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'Todas as paginas foram desprendidas',
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
