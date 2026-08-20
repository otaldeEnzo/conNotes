import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import '../models/canvas_card_model.dart';
import 'card_format_floating_pill.dart';
import 'markdown_latex_block_view.dart';
import 'svg_icon.dart';

enum CardResizeHandle {
  right,
  bottom,
  bottomRight,
}

/// Widget Completo do Card no Canvas Infinito (100% Moscaro Glass + 3 Alças de Seleção).
class CanvasCardWidget extends StatefulWidget {
  static final Map<String, double> actualHeights = {};

  final CanvasCardModel card;
  final bool isSelected;
  final double zoomScale;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final VoidCallback onSelectCard;
  final VoidCallback onDeleteCard;
  final VoidCallback onDuplicateCard;

  const CanvasCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    this.zoomScale = 1.0,
    required this.onUpdateCard,
    required this.onSelectCard,
    required this.onDeleteCard,
    required this.onDuplicateCard,
  });

  @override
  State<CanvasCardWidget> createState() => _CanvasCardWidgetState();
}

class _CanvasCardWidgetState extends State<CanvasCardWidget> {
  Offset? _dragStartPos;
  double? _initialWidth;
  double? _initialHeight;
  double? _initialCardX;
  double? _initialCardY;
  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  final GlobalKey<MarkdownLatexBlockViewState> _blockViewKey = GlobalKey<MarkdownLatexBlockViewState>();
  CardActiveTextStyles _activeStyles = const CardActiveTextStyles();

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
  }

  @override
  void dispose() {
    CanvasCardWidget.actualHeights.remove(widget.card.id);
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.size.height > 20.0) {
          CanvasCardWidget.actualHeights[widget.card.id] = box.size.height;
        }
      }
    });

    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final themeAccent = MoscaroTokens.auroraBlue;
        final textPrimary = MoscaroTokens.textPrimary;
        final textSecondary = MoscaroTokens.textSecondary;
        final glassTint = widget.card.customGlassColor ?? MoscaroTokens.glassTint;
        final isBlurEnabled = MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0;
        final blur = isBlurEnabled ? MoscaroTokens.blurSigma : 0.0;

        final isSelected = widget.isSelected;
        final isCollapsed = widget.card.isCollapsed;

        return SizedBox(
          width: widget.card.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Pílula Flutuante Superior
              SizedBox(
                height: 48.0,
                child: isSelected
                    ? OverflowBox(
                        maxHeight: 500,
                        alignment: Alignment.bottomCenter,
                        child: TapRegion(
                          groupId: 'card_block_editor_${widget.card.id}',
                          child: CardFormatFloatingPill(
                            card: widget.card,
                            cardWidth: widget.card.width,
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
                              final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                              if (_blockViewKey.currentState != null) {
                                _blockViewKey.currentState!.wrapSelection(
                                  prefix: '<span style="color: $hex">',
                                  suffix: '</span>',
                                );
                              } else {
                                widget.onUpdateCard(widget.card.copyWith(textColor: color));
                              }
                            },
                            onApplyFontSize: (size) {
                              if (_blockViewKey.currentState != null && _blockViewKey.currentState!.isEditing) {
                                _blockViewKey.currentState!.wrapSelection(
                                  prefix: '<span style="font-size: ${size}px">',
                                  suffix: '</span>',
                                );
                              } else {
                                widget.onUpdateCard(widget.card.copyWith(fontSize: size));
                              }
                            },
                            onDeleteCard: widget.onDeleteCard,
                            onDuplicateCard: widget.onDuplicateCard,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // 2. O Card Principal em Vidro Líquido Moscaro
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSelectCard,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: isBlurEnabled
                          ? BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: blur,
                                sigmaY: blur,
                              ),
                              child: _buildCardContainer(
                                isSelected: isSelected,
                                themeAccent: themeAccent,
                                isLight: isLight,
                                glassTint: glassTint,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                isCollapsed: isCollapsed,
                              ),
                            )
                          : _buildCardContainer(
                              isSelected: isSelected,
                              themeAccent: themeAccent,
                              isLight: isLight,
                              glassTint: glassTint,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              isCollapsed: isCollapsed,
                            ),
                    ),
                  ),

                  // 3. Moldura de Seleção com as 3 Alças Padrão (Direita, Baixo, Canto Inferior Direito)
                  if (isSelected && !widget.card.isPinned && !isCollapsed) ...[
                    // 1. Alça Lateral Direita (Resize Horizontal - Perfeitamente Centralizada)
                    Positioned(
                      right: -8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildResizeHandle(
                          handle: CardResizeHandle.right,
                          cursor: SystemMouseCursors.resizeLeftRight,
                          themeAccent: themeAccent,
                          isLight: isLight,
                        ),
                      ),
                    ),

                    // 2. Alça Inferior (Resize Vertical - Perfeitamente Centralizada)
                    Positioned(
                      bottom: -8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _buildResizeHandle(
                          handle: CardResizeHandle.bottom,
                          cursor: SystemMouseCursors.resizeUpDown,
                          themeAccent: themeAccent,
                          isLight: isLight,
                        ),
                      ),
                    ),

                    // 3. Alça do Vértice Inferior Direito (Resize em Escala Diagonal)
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: _buildResizeHandle(
                        handle: CardResizeHandle.bottomRight,
                        cursor: SystemMouseCursors.resizeUpLeftDownRight,
                        themeAccent: themeAccent,
                        isLight: isLight,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
  }) {
    return Container(
      width: widget.card.width,
      constraints: BoxConstraints(
        minHeight: widget.card.height != 200.0 ? widget.card.height : 0.0,
        minWidth: 200,
      ),
      decoration: BoxDecoration(
        color: glassTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? themeAccent
              : (isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? themeAccent.withValues(alpha: 0.25)
                : (isLight ? const Color(0x180F172A) : Colors.black.withValues(alpha: 0.45)),
            blurRadius: isSelected ? 24 : 16,
            spreadRadius: isSelected ? 1 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho de Arraste do Card
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              widget.onSelectCard();
              if (widget.card.isPinned) return;
              _dragStartPos = details.globalPosition;
              _initialCardX = widget.card.x;
              _initialCardY = widget.card.y;
            },
            onPanUpdate: (details) {
              if (widget.card.isPinned || _dragStartPos == null) return;
              final delta = (details.globalPosition - _dragStartPos!) / widget.zoomScale;
              widget.onUpdateCard(widget.card.copyWith(
                x: _initialCardX! + delta.dx,
                y: _initialCardY! + delta.dy,
              ));
            },
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
                              onSubmitted: (val) {
                                globalIsEditingText = false;
                                final clean = val.trim();
                                widget.onUpdateCard(widget.card.copyWith(title: clean.isNotEmpty ? clean : 'Card STEM'));
                                setState(() => _isEditingTitle = false);
                              },
                              onTapOutside: (_) {
                                globalIsEditingText = false;
                                final clean = _titleController.text.trim();
                                widget.onUpdateCard(widget.card.copyWith(title: clean.isNotEmpty ? clean : 'Card STEM'));
                                setState(() => _isEditingTitle = false);
                              },
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () {
                              globalIsEditingText = true;
                              setState(() {
                                _isEditingTitle = true;
                                _titleController.text = widget.card.title;
                              });
                            },
                            child: Tooltip(
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

          // Corpo do Card (Blocos de Conteúdo)
          if (!isCollapsed)
            MarkdownLatexBlockView(
              key: _blockViewKey,
              card: widget.card,
              onActiveStylesChanged: (styles) {
                if (mounted) {
                  setState(() => _activeStyles = styles);
                }
              },
              onContentChanged: (newContent) {
                widget.onUpdateCard(widget.card.copyWith(content: newContent));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle({
    required CardResizeHandle handle,
    required MouseCursor cursor,
    required Color themeAccent,
    required bool isLight,
  }) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _dragStartPos = details.globalPosition;
          _initialWidth = widget.card.width;
          _initialHeight = widget.card.height;
        },
        onPanUpdate: (details) {
          if (_dragStartPos == null) return;
          final delta = (details.globalPosition - _dragStartPos!) / widget.zoomScale;

          double newWidth = widget.card.width;
          double newHeight = widget.card.height;

          if (handle == CardResizeHandle.right || handle == CardResizeHandle.bottomRight) {
            newWidth = (_initialWidth! + delta.dx).clamp(200.0, 1600.0);
          }
          if (handle == CardResizeHandle.bottom || handle == CardResizeHandle.bottomRight) {
            newHeight = (_initialHeight! + delta.dy).clamp(widget.card.minHeight, 2400.0);
          }

          widget.onUpdateCard(widget.card.copyWith(
            width: newWidth,
            height: newHeight,
          ));
        },
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF0D1117),
              shape: BoxShape.circle,
              border: Border.all(color: themeAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: themeAccent.withValues(alpha: 0.7),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
