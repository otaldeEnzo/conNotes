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
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;

  const CanvasCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
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
    super.dispose();
  }

  void _submitTitle() {
    globalIsEditingText = false;
    final clean = _titleController.text.trim();
    widget.onUpdateCard(widget.card.copyWith(title: clean.isNotEmpty ? clean : 'Card STEM'));
    setState(() => _isEditingTitle = false);
  }

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
    CardsTelemetryController.instance.startCardDrag(cardId: widget.card.id);
    widget.panNotifier?.addListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.addListener(_onCanvasTransformDuringDrag);
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
    _dragOffsetNotifier.value = delta;
    CardsTelemetryController.instance.updateCardDragDelta(delta);
  }

  void _onHeaderPanEnd(DragEndDetails details) {
    widget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);
    CardsTelemetryController.instance.endCardDrag();
    final finalDelta = _dragOffsetNotifier.value;
    _dragOffsetNotifier.value = Offset.zero;
    _dragStartPos = null;
    _currentMouseGlobalPos = null;
    _grabOffset = null;
    if (finalDelta != Offset.zero && _initialCardX != null && _initialCardY != null) {
      widget.onUpdateCard(widget.card.copyWith(
        x: _initialCardX! + finalDelta.dx,
        y: _initialCardY! + finalDelta.dy,
      ));
    }
  }

  void _onHeaderPanCancel() {
    widget.panNotifier?.removeListener(_onCanvasTransformDuringDrag);
    widget.zoomNotifier?.removeListener(_onCanvasTransformDuringDrag);
    CardsTelemetryController.instance.endCardDrag();
    _dragOffsetNotifier.value = Offset.zero;
    _dragStartPos = null;
    _currentMouseGlobalPos = null;
    _grabOffset = null;
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
          final isProcessing = widget.card.isProcessing;
          final showFloatingPill = isProcessing
              ? false
              : (isMediaCard
                  ? (isSelected && !isCollapsed)
                  : (isSelected && _isEditingBlock));

          final cardBody = !isCollapsed
              ? (isProcessing
                  ? (widget.card.content.trim().isNotEmpty
                      ? CardStreamingPreviewView(content: widget.card.content)
                      : const CardProcessingView())
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
                        )))
              : const SizedBox.shrink();

          return CardResizableFrame(
            card: widget.card,
            isSelected: isSelected,
            zoomScale: widget.zoomScale,
            zoomNotifier: widget.zoomNotifier,
            onUpdateCard: widget.onUpdateCard,
            builder: (context, currentSize) {
              final cardMainBodyWidget = Positioned(
                key: const ValueKey('card_main_body'),
                top: 60.0,
                left: 0,
                width: currentSize.width,
                height: currentSize.height,
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
                    child: ClipRRect(
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
                  final halfBoundingH = halfW * sinTheta.abs() + halfH * cosTheta.abs();
                  final d = halfBoundingH + 46.0;

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
                            behavior: HitTestBehavior.opaque,
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
        },
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
