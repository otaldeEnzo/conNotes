import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import '../services/cards_telemetry_controller.dart';
import 'infinite_hit_test_stack.dart';
import '../controllers/pdf_family_live_preview_controller.dart';
import '../theme/moscaro_v2_tokens.dart';

/// Enumeration of the 4 corner vertices for proportional resizing.
enum PdfCornerVertex {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Returns the diagonal mouse cursor for each corner vertex.
MouseCursor getPdfCornerCursor(PdfCornerVertex vertex) {
  switch (vertex) {
    case PdfCornerVertex.topLeft:
    case PdfCornerVertex.bottomRight:
      return SystemMouseCursors.resizeUpLeftDownRight;
    case PdfCornerVertex.topRight:
    case PdfCornerVertex.bottomLeft:
      return SystemMouseCursors.resizeUpRightDownLeft;
  }
}

/// State tracking live size and opposite-vertex anchor translation during drag.
class PdfResizeDragState {
  final Size size;
  final Offset translationOffset;
  final PdfCornerVertex vertex;

  const PdfResizeDragState({
    required this.size,
    required this.translationOffset,
    required this.vertex,
  });
}

/// Result of proportional corner resizing calculation.
class PdfResizeResult {
  final double newWidth;
  final double newHeight;
  final double shiftX;
  final double shiftY;

  const PdfResizeResult({
    required this.newWidth,
    required this.newHeight,
    required this.shiftX,
    required this.shiftY,
  });
}

/// Pure mathematical calculation for proportional 4-vertex resizing.
class PdfResizeMath {
  static const double minCardWidth = 240.0;
  static const double maxCardWidth = 2400.0;
  static const double standardA4Ratio = 0.7071; // 1.0 / 1.4142

  /// Calculates the effective aspect ratio for an individual page.
  static double calculatePageAspectRatio(CanvasCardModel card) {
    if (card.originalAspectRatio != null && card.originalAspectRatio! > 0) {
      return card.originalAspectRatio!;
    }
    return standardA4Ratio;
  }

  /// Calculates the effective aspect ratio (dW / dH) for proportional resizing.
  static double calculateDifferentialRatio(CanvasCardModel card) {
    final pageRatio = calculatePageAspectRatio(card);
    if (card.pdfDisplayMode == PdfDisplayMode.singlePage || card.sourceMasterCardId != null) {
      return pageRatio;
    }
    final activePages = math.max(1, card.totalPdfPages - card.excludedPageIndices.length);
    return pageRatio / activePages;
  }

  /// Computes the new width, new height, and opposite-vertex origin shift.
  static PdfResizeResult computeResize({
    required PdfCornerVertex vertex,
    required Offset delta,
    required double initialWidth,
    required double initialHeight,
    required CanvasCardModel card,
  }) {
    final rEff = calculateDifferentialRatio(card);
    double effDelta = 0.0;
    double shiftX = 0.0;
    double shiftY = 0.0;

    switch (vertex) {
      case PdfCornerVertex.bottomRight:
        effDelta = (delta.dx + (delta.dy * rEff)) / 2.0;
        break;

      case PdfCornerVertex.bottomLeft:
        effDelta = (-delta.dx + (delta.dy * rEff)) / 2.0;
        break;

      case PdfCornerVertex.topRight:
        effDelta = (delta.dx + (-delta.dy * rEff)) / 2.0;
        break;

      case PdfCornerVertex.topLeft:
        effDelta = (-delta.dx + (-delta.dy * rEff)) / 2.0;
        break;
    }

    final newWidth = (initialWidth + effDelta).clamp(minCardWidth, maxCardWidth);
    final pageRatio = calculatePageAspectRatio(card);
    final isSingle = card.pdfDisplayMode == PdfDisplayMode.singlePage || card.sourceMasterCardId != null;
    final newHeight = isSingle
        ? (newWidth / pageRatio)
        : card.copyWith(width: newWidth).calculateMinHeight();

    switch (vertex) {
      case PdfCornerVertex.bottomRight:
        shiftX = 0.0;
        shiftY = 0.0;
        break;

      case PdfCornerVertex.bottomLeft:
        shiftX = initialWidth - newWidth;
        shiftY = 0.0;
        break;

      case PdfCornerVertex.topRight:
        shiftX = 0.0;
        shiftY = initialHeight - newHeight;
        break;

      case PdfCornerVertex.topLeft:
        shiftX = initialWidth - newWidth;
        shiftY = initialHeight - newHeight;
        break;
    }

    return PdfResizeResult(
      newWidth: newWidth,
      newHeight: newHeight,
      shiftX: shiftX,
      shiftY: shiftY,
    );
  }
}

/// Visual and interactive handle for a single corner vertex.
/// Adheres to Moscaro v2 liquid glass styling with aurora cyan glow.
class PdfCornerResizeHandle extends StatefulWidget {
  final PdfCornerVertex vertex;
  final double left;
  final double top;
  final bool isDragging;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;

  const PdfCornerResizeHandle({
    super.key,
    required this.vertex,
    required this.left,
    required this.top,
    this.isDragging = false,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  @override
  State<PdfCornerResizeHandle> createState() => _PdfCornerResizeHandleState();
}

class _PdfCornerResizeHandleState extends State<PdfCornerResizeHandle> {
  @override
  Widget build(BuildContext context) {
    const hitTargetSize = 28.0;
    final cursor = getPdfCornerCursor(widget.vertex);

    return Positioned(
      left: widget.left,
      top: widget.top,
      width: hitTargetSize,
      height: hitTargetSize,
      child: MouseRegion(
        cursor: cursor,
        hitTestBehavior: HitTestBehavior.opaque,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.onPanStart,
          onPanUpdate: widget.onPanUpdate,
          onPanEnd: widget.onPanEnd,
          onPanCancel: widget.onPanCancel,
          child: CustomPaint(
            painter: _PdfCornerGripPainter(
              color: MoscaroTokens.auroraBlue,
              isDragging: widget.isDragging,
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle Moscaro v2 diagonal grip indicator in the bottom-right corner.
class _PdfCornerGripPainter extends CustomPainter {
  final Color color;
  final bool isDragging;

  const _PdfCornerGripPainter({
    required this.color,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = isDragging ? 0.95 : 0.60;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Two sleek diagonal grip lines in the bottom-right corner
    canvas.drawLine(
      Offset(size.width - 5.0, size.height - 14.0),
      Offset(size.width - 14.0, size.height - 5.0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 5.0, size.height - 8.0),
      Offset(size.width - 8.0, size.height - 5.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PdfCornerGripPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDragging != isDragging;
  }
}

/// Frame widget wrapping a PDF card or page with 4 diagonal corner handles.
/// Completely eliminates side edge handles to avoid aspect-ratio distortion or letterboxing.
class PdfCornerResizeFrame extends StatefulWidget {
  final CanvasCardModel card;
  final bool isSelected;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final List<CanvasCardModel>? allCards;
  final Widget Function(BuildContext context, Size currentSize) builder;

  const PdfCornerResizeFrame({
    super.key,
    required this.card,
    required this.isSelected,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    required this.onUpdateCard,
    this.allCards,
    required this.builder,
  });

  @override
  State<PdfCornerResizeFrame> createState() => _PdfCornerResizeFrameState();
}

class _PdfCornerResizeFrameState extends State<PdfCornerResizeFrame> {
  double get _currentZoom {
    final z = widget.zoomNotifier?.value ?? widget.zoomScale;
    return z > 0 ? z : 1.0;
  }

  Offset? _dragStartGlobalPos;
  double? _initialWidth;
  double? _initialHeight;
  double? _initialCardX;
  double? _initialCardY;

  final ValueNotifier<PdfResizeDragState?> _dragStateNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _dragStateNotifier.dispose();
    super.dispose();
  }

  Map<String, PdfCardLiveTransform> _computeFamilyLiveTransforms({
    required double newWidth,
    required double shiftX,
    required double shiftY,
  }) {
    if (widget.card.cardType != CardType.pdf || widget.allCards == null) return {};

    final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
    final familyCards = widget.allCards!.where((c) =>
        c.cardType == CardType.pdf &&
        (c.id == masterId || c.sourceMasterCardId == masterId)
    ).toList();

    if (familyCards.isEmpty) return {};

    familyCards.sort((a, b) {
      final pageCmp = a.currentPdfPage.compareTo(b.currentPdfPage);
      if (pageCmp != 0) return pageCmp;
      return a.y.compareTo(b.y);
    });

    final initialW = _initialWidth ?? widget.card.width;
    if (initialW <= 0) return {};
    final scale = newWidth / initialW;

    final resizedIndex = familyCards.indexWhere((c) => c.id == widget.card.id);
    if (resizedIndex == -1) return {};

    final resizedCardInitialX = _initialCardX ?? widget.card.x;
    final resizedCardInitialY = _initialCardY ?? widget.card.y;
    final resizedFinalX = resizedCardInitialX + shiftX;
    final resizedFinalY = resizedCardInitialY + shiftY;

    // Fixed constant inter-page gap: perfectly fits the 36px floating pill with 10px top/bottom margins
    final gap = widget.card.pdfPageGap > 0 ? widget.card.pdfPageGap : 56.0;

    // Determine topY for page 1 (both for final layout and live preview)
    double topYFinal = resizedFinalY;
    double topYPreview = resizedFinalY;
    for (int i = 0; i < resizedIndex; i++) {
      final prevCard = familyCards[i];
      final pageRatio = PdfResizeMath.calculatePageAspectRatio(prevCard);
      final prevFinalHeight = newWidth / pageRatio;
      final isMaster = prevCard.sourceMasterCardId == null;
      final headerH = isMaster ? 28.0 : 0.0;
      final prevInitialHeight = (prevCard.width > 0) ? (prevCard.width / pageRatio) : prevCard.height;
      final prevVisualHeight = (prevInitialHeight + headerH) * scale;

      topYFinal -= (prevFinalHeight + headerH + gap);
      topYPreview -= (prevVisualHeight + gap);
    }

    double currentFinalY = topYFinal;
    double currentPreviewY = topYPreview;
    final transforms = <String, PdfCardLiveTransform>{};

    for (final member in familyCards) {
      final pageRatio = PdfResizeMath.calculatePageAspectRatio(member);
      final memberFinalHeight = newWidth / pageRatio;
      final isMaster = member.sourceMasterCardId == null;
      final headerH = isMaster ? 28.0 : 0.0;
      final memberInitialHeight = (member.width > 0) ? (member.width / pageRatio) : member.height;
      final memberVisualHeight = (memberInitialHeight + headerH) * scale;

      final finalX = resizedFinalX;
      final finalY = currentFinalY;
      final previewTranslationY = currentPreviewY - member.y;
      final translation = Offset(finalX - member.x, previewTranslationY);

      transforms[member.id] = PdfCardLiveTransform(
        scale: scale,
        translation: translation,
        finalWidth: newWidth,
        finalHeight: memberFinalHeight,
        finalX: finalX,
        finalY: finalY,
      );

      currentFinalY += memberFinalHeight + headerH + gap;
      currentPreviewY += memberVisualHeight + gap;
    }

    return transforms;
  }

  void _onPanStart(DragStartDetails details, PdfCornerVertex vertex) {
    _dragStartGlobalPos = details.globalPosition;
    _initialWidth = widget.card.width;
    final pageRatio = PdfResizeMath.calculatePageAspectRatio(widget.card);
    _initialHeight = widget.card.width / pageRatio;
    _initialCardX = widget.card.x;
    _initialCardY = widget.card.y;

    CardsTelemetryController.instance.startCardResize(
      cardId: widget.card.id,
      handle: CardHoverZone.corner,
    );
    
    final familyId = widget.card.sourceMasterCardId ?? widget.card.id;
    PdfFamilyLivePreviewController.instance.beginInteraction(familyId);
  }

  void _onPanUpdate(DragUpdateDetails details, PdfCornerVertex vertex) {
    if (_dragStartGlobalPos == null ||
        _initialWidth == null ||
        _initialHeight == null ||
        _initialCardX == null ||
        _initialCardY == null) {
      return;
    }

    final delta = (details.globalPosition - _dragStartGlobalPos!) / _currentZoom;
    final result = PdfResizeMath.computeResize(
      vertex: vertex,
      delta: delta,
      initialWidth: _initialWidth!,
      initialHeight: _initialHeight!,
      card: widget.card,
    );

    final transforms = _computeFamilyLiveTransforms(
      newWidth: result.newWidth,
      shiftX: result.shiftX,
      shiftY: result.shiftY,
    );
    PdfFamilyLivePreviewController.instance.updateInteraction(transforms);

    CardsTelemetryController.instance.updateCardResize(
      delta: delta,
      currentSize: Size(result.newWidth, result.newHeight),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    try {
      final liveState = PdfFamilyLivePreviewController.instance.value;
      final transforms = liveState.cardTransforms;
      if (transforms != null && transforms.isNotEmpty && widget.allCards != null) {
        final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
        final familyCards = widget.allCards!.where((c) =>
            c.cardType == CardType.pdf &&
            (c.id == masterId || c.sourceMasterCardId == masterId)
        ).toList();

        for (final member in familyCards) {
          if (transforms.containsKey(member.id)) {
            final t = transforms[member.id]!;
            widget.onUpdateCard(member.copyWith(
              x: t.finalX,
              y: t.finalY,
              width: t.finalWidth,
              height: t.finalHeight,
            ));
          }
        }
      }
    } finally {
      CardsTelemetryController.instance.endCardResize();
      PdfFamilyLivePreviewController.instance.endInteraction();
      _dragStateNotifier.value = null;
      _dragStartGlobalPos = null;
      _initialWidth = null;
      _initialHeight = null;
      _initialCardX = null;
      _initialCardY = null;
    }
  }

  void _onPanCancel() {
    try {
      PdfFamilyLivePreviewController.instance.endInteraction();
    } finally {
      CardsTelemetryController.instance.endCardResize();
      _dragStateNotifier.value = null;
      _dragStartGlobalPos = null;
      _initialWidth = null;
      _initialHeight = null;
      _initialCardX = null;
      _initialCardY = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PdfResizeDragState?>(
      valueListenable: _dragStateNotifier,
      builder: (context, dragState, _) {
        final currentWidth = dragState?.size.width ?? widget.card.width;
        final pageRatio = PdfResizeMath.calculatePageAspectRatio(widget.card);
        final expectedPageHeight = currentWidth / pageRatio;
        final currentHeight = dragState?.size.height ?? expectedPageHeight;
        final isMasterPdf = widget.card.cardType == CardType.pdf && widget.card.sourceMasterCardId == null;
        final headerH = isMasterPdf ? 28.0 : 0.0;
        final totalFrameHeight = currentHeight + headerH;
        final translation = dragState?.translationOffset ?? Offset.zero;

        final showHandles = widget.isSelected &&
            !widget.card.isPinned &&
            !widget.card.isPdfLocked &&
            !widget.card.isCollapsed;

        const handleSize = 28.0;
        const headerOffset = 60.0;

        final frameContent = InfiniteHitTestSizedBox(
          width: currentWidth,
          height: totalFrameHeight + headerOffset,
          child: InfiniteHitTestStack(
            clipBehavior: Clip.none,
            children: [
              // 1. Content builder receiving constrained current size
              Positioned.fill(
                child: widget.builder(context, Size(currentWidth, currentHeight)),
              ),

              // 2. The corner vertex handle (Exclusively Bottom-Right)
              if (showHandles)
                PdfCornerResizeHandle(
                  vertex: PdfCornerVertex.bottomRight,
                  left: currentWidth - handleSize,
                  top: headerOffset + totalFrameHeight - handleSize,
                  isDragging: dragState?.vertex == PdfCornerVertex.bottomRight,
                  onPanStart: (d) => _onPanStart(d, PdfCornerVertex.bottomRight),
                  onPanUpdate: (d) => _onPanUpdate(d, PdfCornerVertex.bottomRight),
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                ),
            ],
          ),
        );

        if (translation == Offset.zero) {
          return frameContent;
        }

        return Transform.translate(
          offset: translation,
          child: frameContent,
        );
      },
    );
  }
}
