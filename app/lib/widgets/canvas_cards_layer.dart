import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import 'canvas_card_widget.dart';
import 'selection_models.dart';
import 'ink_models.dart';
import 'infinite_hit_test_stack.dart';
import '../controllers/pdf_family_live_preview_controller.dart';
export 'infinite_hit_test_stack.dart';

/// Camada de Renderização e Viewport Culling dos Cards no Canvas Infinito.
/// 
/// Estratégia de Performance: Frozen Blur (O(0) durante interações)
/// 
/// Em vez de usar BackdropFilter (que recaptura e desfoca o framebuffer a cada frame),
/// usamos um glassTint semi-transparente escuro que simula o efeito de vidro líquido
/// sem custo de GPU. O blur real é aplicado apenas quando os cards estão parados
/// (idle), via snapshot congelado do fundo.
class CanvasCardsLayer extends StatefulWidget {
  final List<CanvasCardModel> cards;
  final String? selectedCardId;
  final SelectionState selectionState;
  final SelectionState Function()? getSelectionState;
  final ValueNotifier<int>? selectionUpdateNotifier;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<String?> onSelectCard;
  final ValueChanged<String> onDeleteCard;
  final ValueChanged<CanvasCardModel> onDuplicateCard;
  final ValueChanged<CanvasCardModel>? onAddCard;
  final double gridSpacing;
  final ValueChanged<CanvasCardModel>? onSolveWithAi;
  final ValueChanged<String>? onAskAiText;
  final ValueChanged<CanvasCardModel>? onExtractLatex;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;
  final void Function(String masterCardId, int pageNumber, String? text, [CanvasCardModel? sourceCard])? onJumpToPdfSource;

  const CanvasCardsLayer({
    super.key,
    required this.cards,
    this.getAttachedStrokes,
    this.activeTool = 'pen',
    this.onSyncCardStrokes,
    this.onJumpToPdfSource,
    required this.selectedCardId,
    this.selectionState = const SelectionState(),
    this.getSelectionState,
    this.selectionUpdateNotifier,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
    this.onAddCard,
    this.gridSpacing = 28.0,
    this.onSolveWithAi,
    this.onAskAiText,
    this.onExtractLatex,
  });

  @override
  State<CanvasCardsLayer> createState() => _CanvasCardsLayerState();
}

class _CanvasCardsLayerState extends State<CanvasCardsLayer> {
  final ValueNotifier<int> _selectionIdsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _cullNotifier = ValueNotifier<int>(0);
  Set<String>? _lastSelectedCardIds;
  String? _lastSelectedCardId;
  Set<String>? _visibleCardIds;
  Offset? _lastCullPan;
  double? _lastCullZoom;
  Size _viewportSize = Size.zero;
  bool _lastPreviewActive = false;
  String? _lastPreviewFamilyId;

  @override
  void initState() {
    super.initState();
    widget.selectionUpdateNotifier?.addListener(_onSelectionChanged);
    widget.panNotifier.addListener(_onPanOrZoomChanged);
    widget.zoomNotifier.addListener(_onPanOrZoomChanged);
    PdfFamilyLivePreviewController.instance.addListener(_onPreviewStateChanged);
  }

  @override
  void didUpdateWidget(covariant CanvasCardsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionUpdateNotifier != widget.selectionUpdateNotifier) {
      oldWidget.selectionUpdateNotifier?.removeListener(_onSelectionChanged);
      widget.selectionUpdateNotifier?.addListener(_onSelectionChanged);
    }
    if (oldWidget.panNotifier != widget.panNotifier) {
      oldWidget.panNotifier.removeListener(_onPanOrZoomChanged);
      widget.panNotifier.addListener(_onPanOrZoomChanged);
    }
    if (oldWidget.zoomNotifier != widget.zoomNotifier) {
      oldWidget.zoomNotifier.removeListener(_onPanOrZoomChanged);
      widget.zoomNotifier.addListener(_onPanOrZoomChanged);
    }
    if (oldWidget.cards != widget.cards ||
        oldWidget.selectedCardId != widget.selectedCardId ||
        oldWidget.selectionState != widget.selectionState) {
      _recomputeVisibleCards(force: true);
    }
  }

  @override
  void dispose() {
    widget.selectionUpdateNotifier?.removeListener(_onSelectionChanged);
    widget.panNotifier.removeListener(_onPanOrZoomChanged);
    widget.zoomNotifier.removeListener(_onPanOrZoomChanged);
    PdfFamilyLivePreviewController.instance.removeListener(_onPreviewStateChanged);
    _selectionIdsNotifier.dispose();
    _cullNotifier.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    final sel = widget.getSelectionState?.call() ?? widget.selectionState;
    final ids = sel.selectedCardIds;
    final cardId = widget.selectedCardId;
    if (cardId != _lastSelectedCardId ||
        _lastSelectedCardIds?.length != ids.length ||
        (_lastSelectedCardIds != null && !_lastSelectedCardIds!.containsAll(ids))) {
      _lastSelectedCardId = cardId;
      _lastSelectedCardIds = Set<String>.from(ids);
      _selectionIdsNotifier.value++;
      _recomputeVisibleCards(force: true);
    }
  }

  void _onPreviewStateChanged() {
    final preview = PdfFamilyLivePreviewController.instance.value;
    if (preview.isActive != _lastPreviewActive || preview.activeFamilyId != _lastPreviewFamilyId) {
      _lastPreviewActive = preview.isActive;
      _lastPreviewFamilyId = preview.activeFamilyId;
      _recomputeVisibleCards(force: true);
    }
  }

  void _onPanOrZoomChanged() {
    final pan = widget.panNotifier.value;
    final zoom = widget.zoomNotifier.value;
    if (_lastCullPan == null || _lastCullZoom == null) {
      _recomputeVisibleCards(pan: pan, zoom: zoom);
      return;
    }
    final panDelta = (pan - _lastCullPan!).distance;
    final zoomDelta = (zoom - _lastCullZoom!).abs();
    if (panDelta > 250.0 || zoomDelta > 0.05) {
      _recomputeVisibleCards(pan: pan, zoom: zoom);
    }
  }

  void _recomputeVisibleCards({Offset? pan, double? zoom, bool force = false}) {
    final currentPan = pan ?? widget.panNotifier.value;
    final currentZoom = zoom ?? widget.zoomNotifier.value;
    final newVisibleIds = _computeVisibleCardIds(_viewportSize, currentPan, currentZoom);
    if (force || _visibleCardIds == null || !_setEquals(_visibleCardIds!, newVisibleIds)) {
      _visibleCardIds = newVisibleIds;
      _lastCullPan = currentPan;
      _lastCullZoom = currentZoom;
      if (mounted) {
        _cullNotifier.value++;
      }
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  Set<String> _computeVisibleCardIds(Size viewportSize, Offset pan, double zoom) {
    final effectiveSize = (viewportSize.width > 0 && viewportSize.height > 0)
        ? viewportSize
        : const Size(1920, 1080);
    final z = zoom.clamp(0.01, 10.0);
    final cullRect = Rect.fromLTWH(
      -pan.dx / z,
      -pan.dy / z,
      effectiveSize.width / z,
      effectiveSize.height / z,
    ).inflate(800.0);

    final currentSelectionState = widget.getSelectionState != null
        ? widget.getSelectionState!()
        : widget.selectionState;

    final activePreviewFamilyId = PdfFamilyLivePreviewController.instance.value.activeFamilyId;
    final selectedPdfFamilyIds = <String>{};
    if (activePreviewFamilyId != null) {
      selectedPdfFamilyIds.add(activePreviewFamilyId);
    }

    for (final card in widget.cards) {
      final isSelected = widget.selectedCardId == card.id ||
          currentSelectionState.selectedCardIds.contains(card.id);
      if (isSelected && card.cardType == CardType.pdf) {
        selectedPdfFamilyIds.add(card.sourceMasterCardId ?? card.id);
      }
    }

    final visibleIds = <String>{};
    for (final card in widget.cards) {
      final isSelected = widget.selectedCardId == card.id ||
          currentSelectionState.selectedCardIds.contains(card.id);
      final isPdfActiveFamily = card.cardType == CardType.pdf &&
          selectedPdfFamilyIds.contains(card.sourceMasterCardId ?? card.id);

      if (isSelected || isPdfActiveFamily) {
        visibleIds.add(card.id);
        continue;
      }

      final cardRect = Rect.fromLTWH(
        card.x,
        card.y - 60.0,
        card.width,
        card.height + 60.0,
      );

      if (cullRect.overlaps(cardRect)) {
        visibleIds.add(card.id);
      }
    }
    return visibleIds;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewportSize != newSize) {
            _viewportSize = newSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _recomputeVisibleCards(force: true);
            });
          }
        }
        if (_visibleCardIds == null) {
          _recomputeVisibleCards(force: true);
        }

        return SizedBox.expand(
          child: ClipRect(
            child: ValueListenableBuilder<Offset>(
              valueListenable: widget.panNotifier,
              builder: (context, pan, child) {
                return Transform.translate(
                  offset: pan,
                  child: child,
                );
              },
              child: ValueListenableBuilder<double>(
                valueListenable: widget.zoomNotifier,
                builder: (context, zoom, child) {
                  return Transform.scale(
                    scale: zoom,
                    alignment: Alignment.topLeft,
                    child: child,
                  );
                },
                child: ListenableBuilder(
                  listenable: Listenable.merge([_selectionIdsNotifier, _cullNotifier]),
                  builder: (context, _) => _buildCardsStack(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardsStack() {
    final currentSelectionState = widget.getSelectionState != null
        ? widget.getSelectionState!()
        : widget.selectionState;

    final unselectedCards = <CanvasCardModel>[];
    final otherSelectedCards = <CanvasCardModel>[];
    CanvasCardModel? activeSelectedCard;

    for (final card in widget.cards) {
      if (card.id == widget.selectedCardId) {
        activeSelectedCard = card;
      } else if (currentSelectionState.selectedCardIds.contains(card.id)) {
        otherSelectedCards.add(card);
      } else {
        unselectedCards.add(card);
      }
    }
    final sortedCards = [
      ...unselectedCards,
      ...otherSelectedCards,
      if (activeSelectedCard != null) activeSelectedCard,
    ];

    // Determine primary selected card IDs:
    // For PDF cards in the same PDF family (sourceMasterCardId ?? id), only the first selected page
    // (lowest currentPdfPage, or lowest y) gets isPrimarySelected = true, ensuring only 1 floating pill appears above it.
    final primarySelectedCardIds = <String>{};
    final pdfFamilySelectedCards = <String, List<CanvasCardModel>>{};
    final standaloneSelectedCards = <CanvasCardModel>[];

    for (final card in widget.cards) {
      final isSelected = widget.selectedCardId == card.id ||
          currentSelectionState.selectedCardIds.contains(card.id);
      if (!isSelected) continue;

      if (card.cardType == CardType.pdf) {
        final familyId = card.sourceMasterCardId ?? card.id;
        pdfFamilySelectedCards.putIfAbsent(familyId, () => []).add(card);
      } else {
        standaloneSelectedCards.add(card);
      }
    }

    for (final family in pdfFamilySelectedCards.values) {
      if (family.isEmpty) continue;
      family.sort((a, b) {
        final pageCompare = a.currentPdfPage.compareTo(b.currentPdfPage);
        if (pageCompare != 0) return pageCompare;
        return a.y.compareTo(b.y);
      });
      primarySelectedCardIds.add(family.first.id);
    }

    if (widget.selectedCardId != null && !pdfFamilySelectedCards.containsKey(widget.selectedCardId)) {
      primarySelectedCardIds.add(widget.selectedCardId!);
    } else if (standaloneSelectedCards.isNotEmpty) {
      standaloneSelectedCards.sort((a, b) => a.y.compareTo(b.y));
      primarySelectedCardIds.add(standaloneSelectedCards.first.id);
    }

    final visibleSet = _visibleCardIds;
    final cardsToRender = visibleSet != null
        ? sortedCards.where((c) => visibleSet.contains(c.id)).toList()
        : sortedCards;

    return InfiniteHitTestStack(
      clipBehavior: Clip.none,
      unconstrainedPositionedLayout: true,
      children: cardsToRender.map((card) {
        final isSelected = widget.selectedCardId == card.id ||
            currentSelectionState.selectedCardIds.contains(card.id);
        final isPrimarySelected = isSelected && primarySelectedCardIds.contains(card.id);

        Widget cardChild = CanvasCardWidget(
          key: ValueKey('card_${card.id}'),
          card: card,
          isSelected: isSelected,
          isPrimarySelected: isPrimarySelected,
          zoomNotifier: widget.zoomNotifier,
          panNotifier: widget.panNotifier,
          onUpdateCard: widget.onUpdateCard,
          onSelectCard: widget.onSelectCard,
          onDeleteCard: widget.onDeleteCard,
          onDuplicateCard: widget.onDuplicateCard,
          onAddCard: widget.onAddCard,
          allCards: widget.cards,
          gridSpacing: widget.gridSpacing,
          onSolveWithAi: widget.onSolveWithAi != null ? () => widget.onSolveWithAi!(card) : null,
          onSolveCardWithAi: widget.onSolveWithAi,
          onAskAiText: widget.onAskAiText,
          onExtractLatex: widget.onExtractLatex != null ? () => widget.onExtractLatex!(card) : null,
          getAttachedStrokes: widget.getAttachedStrokes,
          activeTool: widget.activeTool,
          onSyncCardStrokes: widget.onSyncCardStrokes,
          onJumpToPdfSource: widget.onJumpToPdfSource,
        );

        if (widget.selectionUpdateNotifier != null) {
          cardChild = ListenableBuilder(
            key: ValueKey('card_sel_listen_${card.id}'),
            listenable: widget.selectionUpdateNotifier!,
            builder: (context, child) {
              final sel = widget.getSelectionState?.call() ?? widget.selectionState;
              final isDragging = isSelected && sel.isDraggingSelection;
              final offset = isDragging ? sel.dragOffset : Offset.zero;
              if (offset == Offset.zero) return child!;
              return Transform.translate(offset: offset, child: child);
            },
            child: cardChild,
          );
        }

        Widget positionChild;
        if (card.cardType == CardType.pdf) {
          positionChild = ValueListenableBuilder<PdfFamilyLivePreviewState>(
            valueListenable: PdfFamilyLivePreviewController.instance,
            builder: (context, liveState, child) {
              final t = (liveState.isActive) ? liveState.cardTransforms![card.id] : null;
              final s = t?.scale ?? 1.0;
              final tr = t?.translation ?? Offset.zero;
              return Transform(
                transform: Matrix4.translationValues(tr.dx, tr.dy, 0.0)..scaleByDouble(s, s, 1.0, 1.0),
                origin: const Offset(0, 60.0),
                child: child,
              );
            },
            child: cardChild,
          );
        } else {
          positionChild = cardChild;
        }

        return Positioned(
          key: ValueKey('pos_${card.id}'),
          left: card.x,
          top: card.y - 60.0,
          child: positionChild,
        );
      }).toList(),
    );
  }
}
