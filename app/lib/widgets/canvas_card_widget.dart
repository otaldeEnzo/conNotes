import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import 'card_format_floating_pill.dart';
import 'markdown_latex_block_view.dart';
import 'svg_icon.dart';
import 'card_resizable_frame.dart';
import '../services/cards_telemetry_controller.dart';

/// Widget Completo do Card no Canvas Infinito (100% Moscaro Glass + Regiões Dinâmicas de Redimensionamento).
class CanvasCardWidget extends StatefulWidget {
  static final Map<String, double> actualHeights = {};

  final CanvasCardModel card;
  final bool isSelected;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ValueChanged<String> onSelectCard;
  final ValueChanged<String> onDeleteCard;
  final ValueChanged<CanvasCardModel> onDuplicateCard;

  const CanvasCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
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
  double? _initialCardX;
  double? _initialCardY;
  bool _isEditingTitle = false;
  bool _isEditingBlock = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey<MarkdownLatexBlockViewState> _blockViewKey = GlobalKey<MarkdownLatexBlockViewState>();
  CardActiveTextStyles _activeStyles = const CardActiveTextStyles();
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
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
  }

  @override
  void dispose() {
    CanvasCardWidget.actualHeights.remove(widget.card.id);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _dragOffsetNotifier.dispose();
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
    _dragStartPos = details.globalPosition;
    _initialCardX = widget.card.x;
    _initialCardY = widget.card.y;
    _dragOffsetNotifier.value = Offset.zero;
    CardsTelemetryController.instance.startCardDrag(cardId: widget.card.id);
  }

  void _onHeaderPanUpdate(DragUpdateDetails details) {
    if (_isEditingTitle || widget.card.isPinned || _dragStartPos == null) return;
    final delta = (details.globalPosition - _dragStartPos!) / _currentZoom;
    _dragOffsetNotifier.value = delta;
    CardsTelemetryController.instance.updateCardDragDelta(delta);
  }

  void _onHeaderPanEnd(DragEndDetails details) {
    CardsTelemetryController.instance.endCardDrag();
    if (_isEditingTitle || widget.card.isPinned || _dragStartPos == null) return;
    final finalDelta = _dragOffsetNotifier.value;
    _dragOffsetNotifier.value = Offset.zero;
    _dragStartPos = null;
    if (finalDelta != Offset.zero && _initialCardX != null && _initialCardY != null) {
      widget.onUpdateCard(widget.card.copyWith(
        x: _initialCardX! + finalDelta.dx,
        y: _initialCardY! + finalDelta.dy,
      ));
    }
  }

  void _onHeaderPanCancel() {
    CardsTelemetryController.instance.endCardDrag();
    _dragOffsetNotifier.value = Offset.zero;
    _dragStartPos = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _dragOffsetNotifier,
      builder: (context, dragOffset, child) {
        return Transform.translate(
          offset: dragOffset,
          child: child,
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
          final showFloatingPill = isSelected && _isEditingBlock;

          final cardBody = !isCollapsed
              ? MarkdownLatexBlockView(
                  key: _blockViewKey,
                  card: widget.card,
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
                )
              : const SizedBox.shrink();

          return CardResizableFrame(
            card: widget.card,
            isSelected: isSelected,
            zoomScale: widget.zoomScale,
            zoomNotifier: widget.zoomNotifier,
            onUpdateCard: widget.onUpdateCard,
            builder: (context, currentSize) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Pílula Flutuante Superior (Exibida SOMENTE durante a edição ativa de um bloco, Y = 6..52)
                  if (showFloatingPill)
                    Positioned(
                      top: 6.0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: CardFormatFloatingPill(
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
                          onApplyFontSize: (size) {
                            if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                              _blockViewKey.currentState!.applyFontSize(size);
                            } else {
                              widget.onUpdateCard(widget.card.copyWith(fontSize: size));
                            }
                          },
                          onDeleteCard: () => widget.onDeleteCard(widget.card.id),
                          onDuplicateCard: () => widget.onDuplicateCard(widget.card),
                        ),
                      ),
                    ),

                  // 2. O Card Principal em Vidro Líquido Moscaro (Y = 60.0)
                  Positioned(
                    top: 60.0,
                    left: 0,
                    width: currentSize.width,
                    height: currentSize.height,
                    child: TapRegion(
                      groupId: 'card_block_editor_${widget.card.id}',
                      onTapOutside: (_) {
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
                  ),
                ],
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
                  border: Border(
                    bottom: BorderSide(
                      color: isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
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
