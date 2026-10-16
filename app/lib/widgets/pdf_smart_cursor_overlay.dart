import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pdf_text_selection_models.dart';
import '../services/canvas_clipboard_service.dart';
import '../services/pdf_page_spatial_index.dart';
import '../theme/moscaro_theme_controller.dart';
import 'pdf_object_action_menu.dart';
import 'pdf_text_selection_painter.dart';

/// Overlay interativo para selecao universal de texto em paginas PDF.
/// Focado exclusivamente em selecao de texto (arraste, duplo/triplo-clique, atalhos).
/// Elementos visuais (imagens/tabelas/graficos) sao capturados exclusivamente pelo Crop.
/// 100% compativel com o padrao Moscaro v2 e politica estrita de zero emojis.
class PdfSmartCursorOverlay extends StatefulWidget {
  final int pageNumber;
  final double pageWidth;
  final double pageHeight;
  final double nativeWidth;
  final double nativeHeight;
  final PdfPageSpatialIndex? spatialIndex;
  final PdfTextSelectionState? activeTextSelection;
  final ValueChanged<PdfTextSelectionState?>? onTextSelectionChanged;
  final VoidCallback? onHighlightText;
  final VoidCallback? onDismissSelection;
  final ValueChanged<int>? onSelectPage;
  final VoidCallback? onGenerateStemCard;
  final VoidCallback? onAskAi;

  const PdfSmartCursorOverlay({
    super.key,
    required this.pageNumber,
    required this.pageWidth,
    required this.pageHeight,
    required this.nativeWidth,
    required this.nativeHeight,
    this.spatialIndex,
    this.activeTextSelection,
    this.onTextSelectionChanged,
    this.onHighlightText,
    this.onDismissSelection,
    this.onSelectPage,
    this.onGenerateStemCard,
    this.onAskAi,
  });

  @override
  State<PdfSmartCursorOverlay> createState() => _PdfSmartCursorOverlayState();
}

class _PdfSmartCursorOverlayState extends State<PdfSmartCursorOverlay> {
  final FocusNode _focusNode = FocusNode();
  int _dragStartCharIdx = -1;
  bool _isDraggingText = false;
  DateTime _lastClickTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _clickCount = 0;
  Offset? _lastClickPos;

  Offset? _dragStartPos;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTextSelection = widget.activeTextSelection != null &&
        widget.activeTextSelection!.isNotEmpty &&
        widget.activeTextSelection!.pageNumber == widget.pageNumber;

    if (hasTextSelection) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    }

    final MouseCursor cursor = (widget.spatialIndex != null && widget.spatialIndex!.lines.isNotEmpty)
        ? SystemMouseCursors.text
        : SystemMouseCursors.basic;

    final themeAccent = MoscaroThemeController.instance.currentTheme.accentPrimary;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isCtrl = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
            if (hasTextSelection) {
              CanvasClipboardService.instance.clearInternal();
              Clipboard.setData(ClipboardData(text: widget.activeTextSelection!.selectedText));
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onDismissSelection?.call();
            widget.onTextSelectionChanged?.call(null);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camada de interacao do texto do PDF (captura gestos e desenha selecao)
          Positioned.fill(
            child: MouseRegion(
              cursor: cursor,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: hasTextSelection
                    ? IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: PdfTextSelectionPainter(
                              rects: widget.activeTextSelection!.rects,
                              isSelecting: widget.activeTextSelection!.isSelecting,
                              accentColor: themeAccent,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),

          // 2. Menu de acao flutuante Moscaro sobre o texto selecionado (fora do Listener para nao interceptar cliques)
          if (hasTextSelection && !widget.activeTextSelection!.isSelecting)
            _buildTextMenu(widget.activeTextSelection!),
        ],
      ),
    );
  }

  bool _isInsideMenu(Offset pos) {
    final sel = widget.activeTextSelection;
    if (sel == null || sel.isEmpty || sel.isSelecting) return false;
    // Se o clique está dentro dos limites da seleção do texto, pertence à interação com o texto (ex: triplo clique)
    if (sel.bounds.inflate(4.0).contains(pos)) return false;
    final bounds = sel.bounds;
    final menuTop = math.max(6.0, bounds.top - 42.0);
    final menuLeft = (bounds.left + (bounds.width / 2.0) - 130.0)
        .clamp(10.0, math.max(10.0, widget.pageWidth - 300.0))
        .toDouble();
    final menuRect = Rect.fromLTWH(menuLeft, menuTop, 280.0, 36.0);
    return menuRect.contains(pos);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isInsideMenu(event.localPosition)) return;
    if (event.buttons != 1 && (event.buttons & kPrimaryMouseButton == 0)) return;
    _focusNode.requestFocus();

    final now = DateTime.now();
    final pos = event.localPosition;
    final diff = now.difference(_lastClickTime).inMilliseconds;

    if (diff < 650 && _lastClickPos != null && (pos - _lastClickPos!).distance < 28.0) {
      _clickCount++;
      if (_clickCount > 3) {
        _clickCount = 3;
      }
    } else {
      _clickCount = 1;
    }

    _lastClickTime = now;
    _lastClickPos = pos;
    _dragStartPos = pos;

    if (_clickCount == 2) {
      // Duplo-clique: seleciona palavra inteira
      _isDraggingText = false;
      _dragStartCharIdx = -1;
      if (widget.spatialIndex != null) {
        final charIdx = widget.spatialIndex!.findNearestCharIndex(
          displayPos: pos,
          displayWidth: widget.pageWidth,
          displayHeight: widget.pageHeight,
        );
        final range = widget.spatialIndex!.findWordBoundaries(charIdx);
        if (range.isValid && !range.isCollapsed) {
          final sel = widget.spatialIndex!.buildSelectionState(
            charA: range.start,
            charB: range.end,
            displayWidth: widget.pageWidth,
            displayHeight: widget.pageHeight,
          );
          widget.onTextSelectionChanged?.call(sel);
        }
      }
    } else if (_clickCount >= 3) {
      // Triplo-clique: seleciona paragrafo ou bloco inteiro
      _isDraggingText = false;
      _dragStartCharIdx = -1;
      if (widget.spatialIndex != null) {
        final charIdx = widget.spatialIndex!.findNearestCharIndex(
          displayPos: pos,
          displayWidth: widget.pageWidth,
          displayHeight: widget.pageHeight,
        );
        final range = widget.spatialIndex!.findParagraphBoundaries(charIdx);
        if (range.isValid && !range.isCollapsed) {
          final sel = widget.spatialIndex!.buildSelectionState(
            charA: range.start,
            charB: range.end,
            displayWidth: widget.pageWidth,
            displayHeight: widget.pageHeight,
          );
          widget.onTextSelectionChanged?.call(sel);
        }
      }
    } else {
      // Clique simples: prepara ancoragem para selecao por arraste
      if (widget.spatialIndex != null) {
        _dragStartCharIdx = widget.spatialIndex!.findNearestCharIndex(
          displayPos: pos,
          displayWidth: widget.pageWidth,
          displayHeight: widget.pageHeight,
        );
      } else {
        _dragStartCharIdx = -1;
      }
      _isDraggingText = false;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isInsideMenu(event.localPosition) && !_isDraggingText) return;
    if (_dragStartCharIdx < 0 || widget.spatialIndex == null || _dragStartPos == null) return;
    if (event.buttons != 1 && (event.buttons & kPrimaryMouseButton == 0)) return;

    final pos = event.localPosition;
    if (!_isDraggingText) {
      final dragThreshold = _clickCount >= 2 ? 14.0 : 4.0;
      if ((pos - _dragStartPos!).distance >= dragThreshold) {
        _clickCount = 0;
        _isDraggingText = true;
      }
    }

    if (_isDraggingText) {
      final currentCharIdx = widget.spatialIndex!.findNearestCharIndex(
        displayPos: pos,
        displayWidth: widget.pageWidth,
        displayHeight: widget.pageHeight,
      );
      final selection = widget.spatialIndex!.buildSelectionState(
        charA: _dragStartCharIdx,
        charB: currentCharIdx,
        displayWidth: widget.pageWidth,
        displayHeight: widget.pageHeight,
        isSelecting: true,
      );
      widget.onTextSelectionChanged?.call(selection);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isInsideMenu(event.localPosition) && !_isDraggingText) return;
    if (_isDraggingText) {
      if (widget.spatialIndex != null && _dragStartCharIdx >= 0) {
        final endCharIdx = widget.spatialIndex!.findNearestCharIndex(
          displayPos: event.localPosition,
          displayWidth: widget.pageWidth,
          displayHeight: widget.pageHeight,
        );
        final finalSelection = widget.spatialIndex!.buildSelectionState(
          charA: _dragStartCharIdx,
          charB: endCharIdx,
          displayWidth: widget.pageWidth,
          displayHeight: widget.pageHeight,
          isSelecting: false,
        );
        if (finalSelection.isNotEmpty) {
          widget.onTextSelectionChanged?.call(finalSelection);
        } else {
          widget.onTextSelectionChanged?.call(null);
        }
      } else if (widget.activeTextSelection != null && widget.activeTextSelection!.isNotEmpty) {
        widget.onTextSelectionChanged?.call(
          widget.activeTextSelection!.copyWith(isSelecting: false),
        );
      }
    } else if (_clickCount == 1) {
      // Clique simples sem arraste
      if (widget.activeTextSelection != null && widget.activeTextSelection!.isNotEmpty) {
        widget.onDismissSelection?.call();
        widget.onTextSelectionChanged?.call(null);
      } else {
        widget.onSelectPage?.call(widget.pageNumber);
      }
    }
    _isDraggingText = false;
    _dragStartCharIdx = -1;
    _dragStartPos = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _isDraggingText = false;
    _dragStartCharIdx = -1;
    _dragStartPos = null;
  }

  Widget _buildTextMenu(PdfTextSelectionState selection) {
    final bounds = selection.bounds;
    final menuTop = math.max(6.0, bounds.top - 42.0);
    final menuLeft = (bounds.left + (bounds.width / 2.0) - 130.0)
        .clamp(10.0, math.max(10.0, widget.pageWidth - 300.0))
        .toDouble();

    return Positioned(
      top: menuTop,
      left: menuLeft,
      child: PdfObjectActionMenu(
        selectedText: selection.selectedText,
        onSpawnCard: () => widget.onGenerateStemCard?.call(),
        onHighlight: widget.onHighlightText,
        onCopy: () {
          CanvasClipboardService.instance.clearInternal();
          Clipboard.setData(ClipboardData(text: selection.selectedText));
        },
        onAskAi: () => widget.onAskAi?.call(),
        onDismiss: () {
          widget.onDismissSelection?.call();
          widget.onTextSelectionChanged?.call(null);
        },
      ),
    );
  }
}
