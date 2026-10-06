import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import 'card_format_floating_pill.dart';
import 'canvas_card_media_view.dart';
import 'media_card_floating_pill.dart';
import 'media_lightbox_modal.dart';
import 'markdown_latex_block_view.dart';
import 'svg_icon.dart';
import 'card_resizable_frame.dart';
import '../services/cards_telemetry_controller.dart';
import 'infinite_hit_test_stack.dart';
import 'ink_models.dart';
import 'card_processing_view.dart';
import 'card_streaming_preview_view.dart';
import 'canvas_card_pdf_view.dart';
import 'pdf_corner_resize_handle.dart';
import 'pdf_card_floating_pill.dart';
import 'pdf_delete_confirm_dialog.dart';
import '../services/pdf_search_engine.dart';
import '../controllers/pdf_family_live_preview_controller.dart';
import '../controllers/canvas_selection_controller.dart';

/// Widget Completo do Card no Canvas Infinito (100% Moscaro Glass + Regiões Dinâmicas de Redimensionamento).
class CanvasCardWidget extends StatefulWidget {
  static final Map<String, double> actualHeights = {};

  final CanvasCardModel card;
  final bool isSelected;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueNotifier<Offset>? panNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<String> onSelectCard;
  final ValueChanged<String> onDeleteCard;
  final ValueChanged<CanvasCardModel> onDuplicateCard;
  final List<CanvasCardModel>? allCards;
  final double gridSpacing;
  final VoidCallback? onSolveWithAi;
  final VoidCallback? onExtractLatex;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final bool isPrimarySelected;
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;

  const CanvasCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    this.isPrimarySelected = true,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    this.panNotifier,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
    this.allCards,
    this.gridSpacing = 28.0,
    this.onSolveWithAi,
    this.onExtractLatex,
    this.getAttachedStrokes,
    this.activeTool = 'pen',
    this.onSyncCardStrokes,
  });

  @override
  State<CanvasCardWidget> createState() => _CanvasCardWidgetState();
}

class _CanvasCardWidgetState extends State<CanvasCardWidget> {
  double get _currentZoom {
    final z = widget.zoomNotifier?.value ?? widget.zoomScale;
    return z > 0 ? z : 1.0;
  }

  Offset? _dragStartPos;
  Offset? _currentMouseGlobalPos;
  Offset? _grabOffset;
  double? _initialCardX;
  double? _initialCardY;
  bool _isEditingTitle = false;
  bool _isEditingBlock = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey<MarkdownLatexBlockViewState> _blockViewKey = GlobalKey<MarkdownLatexBlockViewState>();
  CardActiveTextStyles _activeStyles = const CardActiveTextStyles();
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
  late final ValueNotifier<double> _dragRotationNotifier = ValueNotifier<double>(widget.card.rotation);
  final GlobalKey _cardContainerKey = GlobalKey();
  late final PdfSearchEngine _pdfSearchEngine = PdfSearchEngine(
    onNavigateToPage: _onPdfPageJump,
  );

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _pdfSearchEngine.onNavigateToPage ??= _onPdfPageJump;
  }

  void _onPdfPageJump(int newPage) {
    if (widget.card.currentPdfPage != newPage) {
      final updated = widget.card.copyWith(currentPdfPage: newPage);
      final newMinH = updated.calculateMinHeight();
      widget.onUpdateCard(updated.copyWith(height: newMinH));
    }
  }

  List<int> _getPdfActivePages() {
    final total = widget.card.totalPdfPages;
    final excluded = widget.card.excludedPageIndices.toSet();
    final active = <int>[];
    for (int i = 1; i <= total; i++) {
      if (!excluded.contains(i)) {
        active.add(i);
      }
    }
    return active;
  }

  void _handleDetachCurrentPage() {
    final pageNum = widget.card.currentPdfPage;
    final ratio = (widget.card.originalAspectRatio != null && widget.card.originalAspectRatio! > 0)
        ? widget.card.originalAspectRatio!
        : (1.0 / 1.4142);
    final pageHeight = widget.card.width / ratio;
    final pageStrokes = widget.card.getStrokesForPage(pageNum);

    final detachedCard = CanvasCardModel(
      id: 'pdf_page_${widget.card.id}_p${pageNum}_${DateTime.now().millisecondsSinceEpoch}',
      cardType: CardType.pdf,
      title: '${widget.card.title} (Pag. $pageNum)',
      x: widget.card.x + widget.card.width + 40.0,
      y: widget.card.y,
      width: widget.card.width,
      height: pageHeight,
      pdfPath: widget.card.pdfPath,
      pdfDisplayMode: PdfDisplayMode.singlePage,
      currentPdfPage: pageNum,
      totalPdfPages: widget.card.totalPdfPages,
      originalAspectRatio: widget.card.originalAspectRatio,
      invertLuminance: widget.card.invertLuminance,
      isPdfLocked: false,
      isDetached: true,
      sourceMasterCardId: widget.card.id,
      pageAttachedStrokeIds: <int, List<String>>{pageNum: List<String>.from(pageStrokes)},
      attachedStrokeIds: List<String>.from(pageStrokes),
    );

    widget.onDuplicateCard(detachedCard);

    final newExcluded = List<int>.from(widget.card.excludedPageIndices);
    if (!newExcluded.contains(pageNum)) {
      newExcluded.add(pageNum);
    }

    final newStrokesMap = Map<int, List<String>>.from(widget.card.pageAttachedStrokeIds)
      ..remove(pageNum);

    final remainingActive = [
      for (int i = 1; i <= widget.card.totalPdfPages; i++)
        if (!newExcluded.contains(i)) i
    ];

    final nextActivePage = remainingActive.contains(widget.card.currentPdfPage)
        ? widget.card.currentPdfPage
        : (remainingActive.isNotEmpty ? remainingActive.first : 1);

    final updatedMasterCard = widget.card.copyWith(
      excludedPageIndices: newExcluded,
      pageAttachedStrokeIds: newStrokesMap,
      currentPdfPage: nextActivePage,
    );

    final newMinHeight = updatedMasterCard.calculateMinHeight();
    widget.onUpdateCard(updatedMasterCard.copyWith(height: newMinHeight));
  }

  void _handleReattachPage(int pageNumber) {
    final newExcluded = List<int>.from(widget.card.excludedPageIndices)..remove(pageNumber);
    final updatedMaster = widget.card.copyWith(
      excludedPageIndices: newExcluded,
      currentPdfPage: pageNumber,
    );
    final newMinHeight = updatedMaster.calculateMinHeight();
    widget.onUpdateCard(updatedMaster.copyWith(height: newMinHeight));

    if (widget.allCards != null) {
      for (final c in widget.allCards!) {
        if (c.cardType == CardType.pdf &&
            (c.sourceMasterCardId == widget.card.id || c.id.startsWith('pdf_page_${widget.card.id}_p$pageNumber')) &&
            c.currentPdfPage == pageNumber) {
          widget.onDeleteCard(c.id);
          break;
        }
      }
    }
  }

  void _handleReattachToMaster() {
    final masterId = widget.card.sourceMasterCardId;
    if (masterId == null) return;

    if (widget.allCards != null) {
      final matches = widget.allCards!.where((c) => c.id == masterId);
      if (matches.isNotEmpty) {
        final master = matches.first;
        final newExcluded = List<int>.from(master.excludedPageIndices)
          ..remove(widget.card.currentPdfPage);
        final updatedMaster = master.copyWith(
          excludedPageIndices: newExcluded,
          currentPdfPage: widget.card.currentPdfPage,
        );
        final newMinHeight = updatedMaster.calculateMinHeight();
        widget.onUpdateCard(updatedMaster.copyWith(height: newMinHeight));
      }
    }
    widget.onDeleteCard(widget.card.id);
  }

  Future<void> _handleDeletePdfCard() async {
    final isMaster = widget.card.sourceMasterCardId == null;
    if (isMaster && widget.allCards != null) {
      final familyMembers = widget.allCards!.where((c) =>
          c.cardType == CardType.pdf &&
          (c.id == widget.card.id || c.sourceMasterCardId == widget.card.id)).toList();

      if (familyMembers.length > 1) {
        final choice = await PdfDeleteConfirmDialog.show(
          context,
          pageNumber: widget.card.currentPdfPage,
          totalPages: widget.card.totalPdfPages,
        );

        if (choice == null || choice == PdfDeleteChoice.cancel) {
          return;
        }

        if (choice == PdfDeleteChoice.deleteAllPages) {
          for (final member in familyMembers) {
            widget.onDeleteCard(member.id);
          }
          return;
        }

        if (choice == PdfDeleteChoice.deleteCurrentPageOnly) {
          final remaining = familyMembers.where((c) => c.id != widget.card.id).toList();
          if (remaining.isNotEmpty) {
            remaining.sort((a, b) => a.currentPdfPage.compareTo(b.currentPdfPage));
            final newMaster = remaining.first;
            final updatedNewMaster = newMaster.copyWith(
              sourceMasterCardId: null,
            );
            widget.onUpdateCard(updatedNewMaster);

            for (final other in remaining.skip(1)) {
              widget.onUpdateCard(other.copyWith(sourceMasterCardId: newMaster.id));
            }
          }
          widget.onDeleteCard(widget.card.id);
          return;
        }
      }
    }

    widget.onDeleteCard(widget.card.id);
  }

  @override
  void didUpdateWidget(CanvasCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.title != widget.card.title && !_isEditingTitle) {
      _titleController.text = widget.card.title;
    }
    if (!widget.isSelected && oldWidget.isSelected) {
      _isEditingBlock = false;
    }
    if (oldWidget.card.rotation != widget.card.rotation) {
      _dragRotationNotifier.value = widget.card.rotation;
    }
    if (_dragStartPos != null) {
      if (oldWidget.panNotifier != widget.panNotifier) {
        oldWidget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
        widget.panNotifier?.addListener(_onCanvasTransformDuringDrag);
      }
      if (oldWidget.zoomNotifier != widget.zoomNotifier) {
        oldWidget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);
        widget.zoomNotifier?.addListener(_onCanvasTransformDuringDrag);
      }
    }
  }

  @override
  void dispose() {
    widget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);
    CanvasCardWidget.actualHeights.remove(widget.card.id);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _dragOffsetNotifier.dispose();
    _dragRotationNotifier.dispose();
    _pdfSearchEngine.dispose();
    super.dispose();
  }

  void _submitTitle() {
    globalIsEditingText = false;
    final clean = _titleController.text.trim();
    widget.onUpdateCard(widget.card.copyWith(title: clean.isNotEmpty ? clean : 'Card STEM'));
    setState(() => _isEditingTitle = false);
  }

  Offset? _currentDelta;

  void _onHeaderPanStart(DragStartDetails details) {
    if (_isEditingTitle) return;
    widget.onSelectCard(widget.card.id);
    if (widget.card.isPinned) return;
    final pan = widget.panNotifier?.value ?? Offset.zero;
    final zoom = _currentZoom;
    final startCanvasPoint = (details.globalPosition - pan) / zoom;
    _dragStartPos = details.globalPosition;
    _currentMouseGlobalPos = details.globalPosition;
    _initialCardX = widget.card.x;
    _initialCardY = widget.card.y;
    _grabOffset = startCanvasPoint - Offset(widget.card.x, widget.card.y);
    _dragOffsetNotifier.value = Offset.zero;
    _currentDelta = Offset.zero;
    CardsTelemetryController.instance.startCardDrag(cardId: widget.card.id);
    widget.panNotifier?.addListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.addListener(_onCanvasTransformDuringDrag);

    if (widget.card.cardType == CardType.pdf) {
      final familyId = widget.card.sourceMasterCardId ?? widget.card.id;
      PdfFamilyLivePreviewController.instance.beginInteraction(familyId);
    }
  }

  void _onHeaderPanUpdate(DragUpdateDetails details) {
    if (_isEditingTitle || widget.card.isPinned || _dragStartPos == null) return;
    _currentMouseGlobalPos = details.globalPosition;
    _updateCardDragPosition();
  }

  void _onCanvasTransformDuringDrag() {
    if (_dragStartPos != null && _currentMouseGlobalPos != null && _grabOffset != null) {
      _updateCardDragPosition();
    }
  }

  void _updateCardDragPosition() {
    if (_currentMouseGlobalPos == null || _grabOffset == null || _initialCardX == null || _initialCardY == null) return;
    final pan = widget.panNotifier?.value ?? Offset.zero;
    final zoom = _currentZoom;
    final currentCanvasPoint = (_currentMouseGlobalPos! - pan) / zoom;
    final targetCardPos = currentCanvasPoint - _grabOffset!;
    final delta = targetCardPos - Offset(_initialCardX!, _initialCardY!);
    _currentDelta = delta;

    final isPdfCard = widget.card.cardType == CardType.pdf;
    if (isPdfCard && widget.allCards != null) {
      final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
      final transforms = <String, PdfCardLiveTransform>{};
      for (final c in widget.allCards!) {
        if (c.cardType == CardType.pdf && (c.id == masterId || c.sourceMasterCardId == masterId)) {
          transforms[c.id] = PdfCardLiveTransform(
            scale: 1.0,
            translation: delta,
            finalWidth: c.width,
            finalHeight: c.height,
            finalX: c.x + delta.dx,
            finalY: c.y + delta.dy,
          );
        }
      }
      PdfFamilyLivePreviewController.instance.updateInteraction(transforms);
    } else {
      _dragOffsetNotifier.value = delta;
    }

    CardsTelemetryController.instance.updateCardDragDelta(delta);
  }

  void _onHeaderPanEnd(DragEndDetails details) {
    widget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);

    try {
      final finalDelta = _currentDelta ?? Offset.zero;
      if (finalDelta != Offset.zero && _initialCardX != null && _initialCardY != null) {
        if (widget.card.cardType == CardType.pdf && widget.allCards != null) {
          final masterId = widget.card.sourceMasterCardId ?? widget.card.id;
          final siblings = widget.allCards!.where((c) =>
              c.cardType == CardType.pdf &&
              (c.id == masterId || c.sourceMasterCardId == masterId));

          for (final s in siblings) {
            if (s.id == widget.card.id) {
              widget.onUpdateCard(widget.card.copyWith(
                x: _initialCardX! + finalDelta.dx,
                y: _initialCardY! + finalDelta.dy,
              ));
            } else {
              widget.onUpdateCard(s.copyWith(
                x: s.x + finalDelta.dx,
                y: s.y + finalDelta.dy,
              ));
            }
          }
        } else {
          widget.onUpdateCard(widget.card.copyWith(
            x: _initialCardX! + finalDelta.dx,
            y: _initialCardY! + finalDelta.dy,
          ));
        }
      }
    } finally {
      CardsTelemetryController.instance.endCardDrag();
      if (widget.card.cardType == CardType.pdf) {
        PdfFamilyLivePreviewController.instance.endInteraction();
      }
      _dragOffsetNotifier.value = Offset.zero;
      _dragStartPos = null;
      _currentMouseGlobalPos = null;
      _grabOffset = null;
      _currentDelta = null;
      _initialCardX = null;
      _initialCardY = null;
    }
  }

  void _onHeaderPanCancel() {
    widget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);
    try {
      if (widget.card.cardType == CardType.pdf) {
        PdfFamilyLivePreviewController.instance.endInteraction();
      }
    } finally {
      CardsTelemetryController.instance.endCardDrag();
      _dragOffsetNotifier.value = Offset.zero;
      _dragStartPos = null;
      _currentMouseGlobalPos = null;
      _grabOffset = null;
      _currentDelta = null;
      _initialCardX = null;
      _initialCardY = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alignY = (widget.card.height > 0)
        ? (60.0 / (widget.card.height + 60.0))
        : 0.0;

    return ValueListenableBuilder<Offset>(
      valueListenable: _dragOffsetNotifier,
      builder: (context, dragOffset, child) {
        return Transform.translate(
          offset: dragOffset,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragRotationNotifier,
            builder: (context, rotation, rotatedChild) {
              return Transform.rotate(
                angle: rotation,
                alignment: Alignment(0.0, alignY),
                child: rotatedChild,
              );
            },
            child: child,
          ),
        );
      },
      child: ListenableBuilder(
        listenable: MoscaroThemeController.instance,
        builder: (context, _) {
          final isLight = MoscaroTokens.isLight;
          final themeAccent = MoscaroTokens.auroraBlue;
          final textPrimary = MoscaroTokens.textPrimary;
          final textSecondary = MoscaroTokens.textSecondary;
          final glassTint = widget.card.customGlassColor ?? MoscaroTokens.glassTint;
          final isSelected = widget.isSelected;
          final isCollapsed = widget.card.isCollapsed;
          final isMediaCard = widget.card.cardType == CardType.media;
          final isPdfCard = widget.card.cardType == CardType.pdf;
          final isProcessing = widget.card.isProcessing;
          final showFloatingPill = widget.isPrimarySelected &&
              (isProcessing
                  ? false
                  : (isPdfCard
                      ? (isSelected && !isCollapsed)
                      : (isMediaCard
                          ? (isSelected && !isCollapsed)
                          : (isSelected && _isEditingBlock))));

          final cardBody = !isCollapsed
              ? (isProcessing
                  ? (widget.card.content.trim().isNotEmpty
                      ? CardStreamingPreviewView(content: widget.card.content)
                      : const CardProcessingView())
                  : (isPdfCard
                      ? CanvasCardPdfView(
                          card: widget.card,
                          isSelected: isSelected,
                          onUpdateCard: widget.onUpdateCard,
                          zoomScale: widget.zoomScale,
                          zoomNotifier: widget.zoomNotifier,
                          panNotifier: widget.panNotifier,
                          onSelectCard: () => widget.onSelectCard(widget.card.id),
                          onDeleteCard: () => widget.onDeleteCard(widget.card.id),
                          onDuplicateCard: widget.onDuplicateCard,
                          getAttachedStrokes: widget.getAttachedStrokes,
                          activeTool: widget.activeTool,
                          onSyncCardStrokes: widget.onSyncCardStrokes,
                          searchEngine: _pdfSearchEngine,
                        )
                      : (isMediaCard
                          ? CanvasCardMediaView(
                              card: widget.card,
                              isSelected: isSelected,
                              onUpdateCard: widget.onUpdateCard,
                              zoomScale: widget.zoomScale,
                              getAttachedStrokes: widget.getAttachedStrokes,
                              activeTool: widget.activeTool,
                              onSyncCardStrokes: widget.onSyncCardStrokes,
                            )
                          : MarkdownLatexBlockView(
                              key: _blockViewKey,
                              card: widget.card,
                              isSelected: isSelected,
                              onSelectCard: () => widget.onSelectCard(widget.card.id),
                              onEditingModeChanged: (editing) {
                                if (mounted && _isEditingBlock != editing) {
                                  setState(() => _isEditingBlock = editing);
                                }
                              },
                              onActiveStylesChanged: (styles) {
                                if (mounted) {
                                  setState(() => _activeStyles = styles);
                                }
                              },
                              onContentChanged: (newContent) {
                                final updatedCard = widget.card.copyWith(content: newContent);
                                final calculatedMin = updatedCard.calculateMinHeight();
                                final finalHeight = math.max(widget.card.height, calculatedMin);
                                widget.onUpdateCard(updatedCard.copyWith(height: finalHeight));
                              },
                            ))))
              : const SizedBox.shrink();

          Widget frameBuilder(BuildContext context, Size currentSize) {
            final isMasterPdfCard = isPdfCard && (widget.card.sourceMasterCardId == null || widget.card.isDetached);
            final cardBodyHeight = currentSize.height + (isMasterPdfCard ? 28.0 : 0.0);

            final cardMainBodyWidget = Positioned(
              key: const ValueKey('card_main_body'),
              top: 60.0,
              left: 0,
              width: currentSize.width,
              height: cardBodyHeight,
              child: TapRegion(
                  groupId: 'card_block_editor_${widget.card.id}',
                  onTapOutside: (_) {
                    if (globalIsHoveringFloatingPill || CardFormatFloatingPill.hasActivePopover) {
                      return;
                    }
                    if (_blockViewKey.currentState?.isEditing == true) {
                      _blockViewKey.currentState?.commitBlockEdit();
                    }
                  },
                  child: isPdfCard
                      ? RepaintBoundary(
                          child: _buildCardContainer(
                            isSelected: isSelected,
                            themeAccent: themeAccent,
                            isLight: isLight,
                            glassTint: glassTint,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isCollapsed: isCollapsed,
                            currentSize: currentSize,
                            child: cardBody,
                          ),
                        )
                      : ClipRRect(
                          key: _cardContainerKey,
                          borderRadius: BorderRadius.circular(14),
                          child: RepaintBoundary(
                            child: _buildCardContainer(
                              isSelected: isSelected,
                              themeAccent: themeAccent,
                              isLight: isLight,
                              glassTint: glassTint,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              isCollapsed: isCollapsed,
                              currentSize: currentSize,
                              child: cardBody,
                            ),
                          ),
                        ),
                ),
            );

              return ValueListenableBuilder<double>(
                valueListenable: _dragRotationNotifier,
                child: cardMainBodyWidget,
                builder: (context, currentRotation, staticCardBody) {
                  final theta = currentRotation;
                  final halfW = currentSize.width / 2.0;
                  final halfH = currentSize.height / 2.0;
                  final xc = halfW;
                  final yc = 60.0 + halfH;
                  final sinTheta = math.sin(theta);
                  final cosTheta = math.cos(theta);
                  final isSisterPdfPage = isPdfCard && widget.card.sourceMasterCardId != null && !widget.card.isDetached;
                  final halfBoundingH = halfW * sinTheta.abs() + halfH * cosTheta.abs();
                  final pageGap = widget.card.pdfPageGap > 0 ? widget.card.pdfPageGap : 56.0;
                  final d = halfBoundingH + (isSisterPdfPage ? ((pageGap / 2.0) + 6.0) : 46.0);

                  // Posição local da pílula para que, após a rotação do pai por theta,
                  // ela fique exatamente no topo da AABB do card em tela, horizontal e sem sobreposição
                  final localPillCenterX = xc - d * sinTheta;
                  final localPillCenterY = yc - d * cosTheta;

                  return InfiniteHitTestStack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. O Card Principal em Vidro Liquido Moscaro estático (sem rebuild no giro)
                      staticCardBody!,

                      // 2. Pílula Flutuante Superior (Pintada por cima do Card para prioridade de hit-testing)
                      if (showFloatingPill)
                        Positioned(
                          key: const ValueKey('floating_pill'),
                          left: localPillCenterX - 450.0,
                          top: localPillCenterY - 650.0,
                          width: 900.0,
                          height: 680.0,
                          child: TapRegion(
                            groupId: 'card_block_editor_${widget.card.id}',
                            behavior: HitTestBehavior.deferToChild,
                            child: ValueListenableBuilder<PdfFamilyLivePreviewState>(
                              valueListenable: PdfFamilyLivePreviewController.instance,
                              builder: (context, liveState, unscaledChild) {
                                final t = (liveState.isActive && liveState.cardTransforms != null)
                                    ? liveState.cardTransforms![widget.card.id]
                                    : null;
                                final s = t?.scale ?? 1.0;
                                if (s <= 0 || (s - 1.0).abs() < 0.0001) {
                                  return unscaledChild!;
                                }
                                final counterScale = 1.0 / s;
                                final dyCompensation = 16.0 * (1.0 - counterScale);
                                return Transform.translate(
                                  offset: Offset(0.0, dyCompensation),
                                  child: Transform.scale(
                                    scale: counterScale,
                                    alignment: Alignment.bottomCenter,
                                    child: unscaledChild,
                                  ),
                                );
                              },
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Transform.rotate(
                                  angle: -currentRotation,
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                child: isMediaCard
                                    ? ValueListenableBuilder<double>(
                                        valueListenable: widget.zoomNotifier ?? ValueNotifier(1.0),
                                        builder: (context, currentZoomVal, _) {
                                          return MediaCardFloatingPill(
                                            card: widget.card,
                                            zoomScale: currentZoomVal,
                                            onUpdateCard: widget.onUpdateCard,
                                            onDuplicateCard: () => widget.onDuplicateCard(widget.card),
                                            onDeleteCard: () => widget.onDeleteCard(widget.card.id),
                                            onSolveWithAi: widget.onSolveWithAi,
                                            onExtractLatex: widget.onExtractLatex,
                                            onOpenLightbox: () async {
                                              final attached = widget.getAttachedStrokes != null && widget.card.attachedStrokeIds.isNotEmpty
                                                  ? widget.getAttachedStrokes!(widget.card.attachedStrokeIds.toSet())
                                                  : <InkStroke>[];
                                              final finalStrokes = await MediaLightboxModal.show(
                                                context,
                                                mediaData: widget.card.mediaData,
                                                title: widget.card.title.isNotEmpty ? widget.card.title : 'Visualização de Mídia',
                                                initialStrokes: attached,
                                                cardX: widget.card.x,
                                                cardY: widget.card.y + 28.0,
                                                cardWidth: widget.card.width,
                                                cardHeight: math.max(1.0, widget.card.height - 28.0),
                                                parentCardId: widget.card.id,
                                              );
                                              if (finalStrokes != null && widget.onSyncCardStrokes != null) {
                                                widget.onSyncCardStrokes!(finalStrokes, widget.card.id);
                                              }
                                            },
                                          );
                                        },
                                      )
                                    : (isPdfCard
                                        ? ValueListenableBuilder<double>(
                                            valueListenable: widget.zoomNotifier ?? ValueNotifier(1.0),
                                            builder: (context, currentZoomVal, _) {
                                              final selIds = CanvasSelectionController.instance.state.selectedCardIds;
                                              return PdfCardFloatingPill(
                                                card: widget.card,
                                                allCards: widget.allCards,
                                                selectedPageIds: selIds,
                                                zoomScale: currentZoomVal,
                                                zoomNotifier: widget.zoomNotifier,
                                                onUpdateCard: widget.onUpdateCard,
                                                onPageChanged: _onPdfPageJump,
                                                onPageJump: _onPdfPageJump,
                                                onDeleteCard: _handleDeletePdfCard,
                                                onDuplicateCard: () => widget.onDuplicateCard(widget.card),
                                                onDuplicateMultipleCards: (cards) {
                                                  for (final c in cards) {
                                                    widget.onDuplicateCard(c);
                                                  }
                                                },
                                                onDeleteMultipleCards: (ids) {
                                                  for (final id in ids) {
                                                    widget.onDeleteCard(id);
                                                  }
                                                },
                                                getAttachedStrokes: widget.getAttachedStrokes,
                                                searchEngine: _pdfSearchEngine,
                                                isCardSelected: isSelected,
                                                totalPages: widget.card.totalPdfPages,
                                                activePageNumber: widget.card.currentPdfPage,
                                                activePages: _getPdfActivePages(),
                                                isSisterPage: isSisterPdfPage,
                                                onPanStart: _onHeaderPanStart,
                                                onPanUpdate: _onHeaderPanUpdate,
                                                onPanEnd: _onHeaderPanEnd,
                                                onPanCancel: _onHeaderPanCancel,
                                                onDetachCurrentPage: _handleDetachCurrentPage,
                                                onReattachPage: _handleReattachPage,
                                                onReattachToMaster: _handleReattachToMaster,
                                              );
                                            },
                                          )
                                        : CardFormatFloatingPill(
                                            card: widget.card,
                                            cardWidth: currentSize.width,
                                        activeStyles: _activeStyles,
                                        onUpdateCard: widget.onUpdateCard,
                                        onInsertSnippet: (snippet) {
                                          if (_blockViewKey.currentState != null) {
                                            _blockViewKey.currentState!.insertSnippetAtActive(snippet);
                                          } else {
                                            final updatedContent = '${widget.card.content}$snippet';
                                            widget.onUpdateCard(widget.card.copyWith(content: updatedContent));
                                          }
                                        },
                                        onWrapSelection: (prefix, suffix) {
                                          if (_blockViewKey.currentState != null) {
                                            _blockViewKey.currentState!.wrapSelection(prefix: prefix, suffix: suffix);
                                          } else {
                                            final updatedContent = '${widget.card.content}$prefix$suffix';
                                            widget.onUpdateCard(widget.card.copyWith(content: updatedContent));
                                          }
                                        },
                                        onApplyTextColor: (color) {
                                          if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                                            _blockViewKey.currentState!.applyTextColor(color);
                                          } else {
                                            widget.onUpdateCard(widget.card.copyWith(textColor: color));
                                          }
                                        },
                                        onApplyHighlightColor: (color) {
                                          if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                                            _blockViewKey.currentState!.applyHighlightColor(color);
                                          }
                                        },
                                        onApplyFontSize: (size) {
                                          if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                                            _blockViewKey.currentState!.applyFontSize(size);
                                          } else {
                                            widget.onUpdateCard(widget.card.copyWith(fontSize: size));
                                          }
                                        },
                                        onApplyFontFamily: (family) {
                                          if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                                            _blockViewKey.currentState!.applyFontFamily(family);
                                          } else {
                                            widget.onUpdateCard(widget.card.copyWith(fontFamily: family));
                                          }
                                        },
                                        onDeleteCard: () => widget.onDeleteCard(widget.card.id),
                                        onDuplicateCard: () => widget.onDuplicateCard(widget.card),
                                      )),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    ],
                  );
            },
          );
        }

        if (isPdfCard) {
          return PdfCornerResizeFrame(
            card: widget.card,
            isSelected: isSelected,
            zoomScale: widget.zoomScale,
            zoomNotifier: widget.zoomNotifier,
            onUpdateCard: widget.onUpdateCard,
            allCards: widget.allCards,
            builder: frameBuilder,
          );
        }

        return CardResizableFrame(
          card: widget.card,
          isSelected: isSelected,
          zoomScale: widget.zoomScale,
          zoomNotifier: widget.zoomNotifier,
          onUpdateCard: widget.onUpdateCard,
          builder: frameBuilder,
        );
      },
    ),
  );
}

  Widget _buildCardContainer({
    required bool isSelected,
    required Color themeAccent,
    required bool isLight,
    required Color glassTint,
    required Color textPrimary,
    required Color textSecondary,
    required bool isCollapsed,
    required Size currentSize,
    required Widget child,
  }) {
    final borderColor = isSelected
        ? themeAccent
        : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow);

    final cardShadows = [
      BoxShadow(
        color: isSelected
            ? themeAccent.withValues(alpha: 0.3)
            : (isLight ? const Color(0x180F172A) : Colors.black.withValues(alpha: 0.45)),
        blurRadius: isSelected ? 24 : 16,
        spreadRadius: isSelected ? 1 : 0,
        offset: const Offset(0, 8),
      ),
    ];

    if (widget.card.cardType == CardType.pdf) {
      final isSisterPage = widget.card.sourceMasterCardId != null && !widget.card.isDetached;
      if (isSisterPage) {
        return SizedBox(
          width: currentSize.width,
          height: currentSize.height,
          child: child,
        );
      }

      return SizedBox(
        width: currentSize.width,
        child: ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecalho de Arraste do PDF (Vidro Liquido Moscaro v2)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectCard(widget.card.id),
                onDoubleTap: () {
                  widget.onSelectCard(widget.card.id);
                  globalIsEditingText = true;
                  setState(() {
                    _isEditingTitle = true;
                    _titleController.text = widget.card.title;
                  });
                  _titleFocusNode.requestFocus();
                },
                onPanStart: _onHeaderPanStart,
                onPanUpdate: _onHeaderPanUpdate,
                onPanEnd: _onHeaderPanEnd,
                onPanCancel: _onHeaderPanCancel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        SvgIcon(name: 'pdf', size: 13, color: themeAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _isEditingTitle
                              ? Container(
                                  height: 20,
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _titleController,
                                    focusNode: _titleFocusNode,
                                    autofocus: true,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _submitTitle(),
                                    onTapOutside: (_) => _submitTitle(),
                                  ),
                                )
                              : Tooltip(
                                  message: 'Clique duas vezes para renomear',
                                  child: Text(
                                    widget.card.title.isNotEmpty ? widget.card.title : 'Documento PDF',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                        if (widget.card.totalPdfPages > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Pág. ${widget.card.currentPdfPage} / ${widget.card.totalPdfPages}',
                              style: TextStyle(
                                color: themeAccent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Corpo do PDF com as paginas renderizadas com largura completa
              child,
            ],
          ),
        ),
      );
    }

    if (widget.card.cardType == CardType.media) {
      return SizedBox(
        width: currentSize.width,
        height: currentSize.height,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecalho de Arraste da Midia (Vidro Liquido Moscaro v2)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectCard(widget.card.id),
                onDoubleTap: () {
                  widget.onSelectCard(widget.card.id);
                  globalIsEditingText = true;
                  setState(() {
                    _isEditingTitle = true;
                    _titleController.text = widget.card.title;
                  });
                  _titleFocusNode.requestFocus();
                },
                onPanStart: _onHeaderPanStart,
                onPanUpdate: _onHeaderPanUpdate,
                onPanEnd: _onHeaderPanEnd,
                onPanCancel: _onHeaderPanCancel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        SvgIcon(name: 'image', size: 13, color: themeAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _isEditingTitle
                              ? Container(
                                  height: 20,
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _titleController,
                                    focusNode: _titleFocusNode,
                                    autofocus: true,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _submitTitle(),
                                    onTapOutside: (_) => _submitTitle(),
                                  ),
                                )
                              : Tooltip(
                                  message: 'Clique duas vezes para renomear',
                                  child: Text(
                                    widget.card.title.isNotEmpty ? widget.card.title : 'Media',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Corpo da Mídia: NUNCA seleciona o card ao clicar na imagem (seleção exclusiva pelo cabeçalho)
              Expanded(
                child: child,
              ),
            ],
          ).moscaroV2(
            borderRadius: 14,
            backgroundColor: glassTint,
            borderColor: borderColor,
            borderWidth: isSelected ? 1.5 : 1.0,
            customShadows: cardShadows,
            padding: EdgeInsets.zero,
            enableBlur: MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0,
            blurSigma: MoscaroTokens.blurSigma,
          ),
        ),
      );
    }

    return SizedBox(
      width: currentSize.width,
      height: currentSize.height,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho de Arraste e Título do Card
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelectCard(widget.card.id),
              onDoubleTap: () {
                widget.onSelectCard(widget.card.id);
                globalIsEditingText = true;
                setState(() {
                  _isEditingTitle = true;
                  _titleController.text = widget.card.title;
                });
                _titleFocusNode.requestFocus();
              },
              onPanStart: _onHeaderPanStart,
              onPanUpdate: _onHeaderPanUpdate,
              onPanEnd: _onHeaderPanEnd,
              onPanCancel: _onHeaderPanCancel,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    SvgIcon(name: 'pin', size: 14, color: widget.card.isPinned ? const Color(0xFFFF007A) : themeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isEditingTitle
                          ? Container(
                              height: 24,
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                autofocus: true,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _submitTitle(),
                                onTapOutside: (_) => _submitTitle(),
                              ),
                            )
                          : Tooltip(
                              message: 'Clique duas vezes para renomear',
                              child: Text(
                                widget.card.title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                    if (widget.card.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SvgIcon(name: 'lock', size: 13, color: textSecondary),
                      ),
                  ],
                ),
              ),
            ),

            // Corpo do Card (Blocos de Conteúdo passado como child para evitar rebuild no resize)
            if (!isCollapsed) Expanded(child: child),
          ],
        ).moscaroV2(
          borderRadius: 14,
          backgroundColor: glassTint,
          borderColor: borderColor,
          borderWidth: isSelected ? 1.5 : 1.0,
          customShadows: cardShadows,
          padding: EdgeInsets.zero,
          enableBlur: MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0,
          blurSigma: MoscaroTokens.blurSigma,
        ),
      ),
    );
  }
}
