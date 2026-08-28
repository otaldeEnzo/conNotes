import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';

typedef ResizableFrameBuilder = Widget Function(
  BuildContext context,
  Size currentSize,
);

class CardResizableFrame extends StatefulWidget {
  final CanvasCardModel card;
  final bool isSelected;
  final double zoomScale;
  final ValueNotifier<double>? zoomNotifier;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final ResizableFrameBuilder builder;

  const CardResizableFrame({
    super.key,
    required this.card,
    required this.isSelected,
    this.zoomScale = 1.0,
    this.zoomNotifier,
    required this.onUpdateCard,
    required this.builder,
  });

  @override
  State<CardResizableFrame> createState() => _CardResizableFrameState();
}

class _CardResizableFrameState extends State<CardResizableFrame> {
  double get _currentZoom {
    final z = widget.zoomNotifier?.value ?? widget.zoomScale;
    return z > 0 ? z : 1.0;
  }

  Offset? _dragStartPos;
  double? _initialWidth;
  double? _initialHeight;
  double? _cachedDragMinHeight;
  double? _lastDragMeasuredWidth;
  double? _cachedStaticMinHeight;

  final ValueNotifier<Size?> _dragSizeNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _cachedStaticMinHeight = widget.card.calculateMinHeight();
  }

  @override
  void didUpdateWidget(CardResizableFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.content != widget.card.content ||
        oldWidget.card.width != widget.card.width ||
        oldWidget.card.fontSize != widget.card.fontSize ||
        oldWidget.card.fontFamily != widget.card.fontFamily ||
        oldWidget.card.isCollapsed != widget.card.isCollapsed) {
      _cachedStaticMinHeight = widget.card.calculateMinHeight();
    }
  }

  @override
  void dispose() {
    _dragSizeNotifier.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, {bool isRight = false, bool isBottom = false, bool isCorner = false}) {
    _dragStartPos = details.globalPosition;
    _initialWidth = widget.card.width;
    _cachedDragMinHeight = _cachedStaticMinHeight ?? widget.card.calculateMinHeight();
    _lastDragMeasuredWidth = widget.card.width;
    _initialHeight = math.max(widget.card.height, _cachedDragMinHeight!);
    _dragSizeNotifier.value = Size(_initialWidth!, _initialHeight!);
  }

  void _onPanUpdate(DragUpdateDetails details, {bool isRight = false, bool isBottom = false, bool isCorner = false}) {
    if (_dragStartPos == null || _initialWidth == null || _initialHeight == null) return;
    final delta = (details.globalPosition - _dragStartPos!) / _currentZoom;

    double newWidth = _initialWidth!;
    double newHeight = _initialHeight!;

    if (isRight || isCorner) {
      newWidth = (_initialWidth! + delta.dx).clamp(200.0, 1600.0);
      if (_lastDragMeasuredWidth == null || (newWidth - _lastDragMeasuredWidth!).abs() >= 4.0) {
        _cachedDragMinHeight = widget.card.copyWith(width: newWidth).calculateMinHeight();
        _lastDragMeasuredWidth = newWidth;
      }
    }
    final dynamicMinHeight = _cachedDragMinHeight ?? _cachedStaticMinHeight ?? widget.card.calculateMinHeight();
    final dynamicMinArea = widget.card.minArea;

    if (isBottom || isCorner) {
      newHeight = (_initialHeight! + delta.dy).clamp(dynamicMinHeight, 2400.0);
    } else {
      newHeight = math.max(newHeight, dynamicMinHeight);
    }

    if (newWidth * newHeight < dynamicMinArea) {
      if (isRight && !isCorner) {
        newHeight = math.max(newHeight, dynamicMinArea / newWidth);
      } else if (isBottom && !isCorner) {
        newWidth = math.max(newWidth, dynamicMinArea / newHeight);
      } else {
        newHeight = math.max(newHeight, dynamicMinArea / newWidth);
      }
    }

    _dragSizeNotifier.value = Size(newWidth, newHeight);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragSizeNotifier.value != null) {
      final finalWidth = _dragSizeNotifier.value!.width;
      final dynamicMin = widget.card.copyWith(width: finalWidth).calculateMinHeight();
      final dynamicMinArea = widget.card.minArea;
      double finalHeight = math.max(_dragSizeNotifier.value!.height, dynamicMin);
      if (finalWidth * finalHeight < dynamicMinArea) {
        finalHeight = math.max(finalHeight, dynamicMinArea / finalWidth);
      }
      _cachedStaticMinHeight = dynamicMin;
      widget.onUpdateCard(widget.card.copyWith(
        width: finalWidth,
        height: finalHeight,
      ));
      _dragSizeNotifier.value = null;
    }
    _dragStartPos = null;
    _initialWidth = null;
    _initialHeight = null;
    _cachedDragMinHeight = null;
    _lastDragMeasuredWidth = null;
  }

  void _onPanCancel() {
    _dragSizeNotifier.value = null;
    _dragStartPos = null;
    _initialWidth = null;
    _initialHeight = null;
    _cachedDragMinHeight = null;
    _lastDragMeasuredWidth = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Size?>(
      valueListenable: _dragSizeNotifier,
      builder: (context, dragSize, child) {
        final currentWidth = dragSize?.width ?? widget.card.width;
        final effectiveMinHeight = dragSize != null
            ? (_cachedDragMinHeight ?? _cachedStaticMinHeight ?? widget.card.calculateMinHeight())
            : (_cachedStaticMinHeight ?? widget.card.calculateMinHeight());
        final currentHeight = math.max(dragSize?.height ?? widget.card.height, effectiveMinHeight);
        
        final showHandles = widget.isSelected && !widget.card.isPinned && !widget.card.isCollapsed;
        const cornerSize = 24.0;
        const edgeThickness = 12.0;

        return SizedBox(
          width: currentWidth,
          height: currentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. O filho encapsulado recebe as restrições completas
              Positioned.fill(
                child: widget.builder(context, Size(currentWidth, currentHeight)),
              ),
              
              // 2. Regiões dinâmicas de borda (Invisíveis)
              if (showHandles) ...[
                // Borda Direita (Vertical)
                Positioned(
                  right: -edgeThickness / 2,
                  top: 0,
                  width: edgeThickness,
                  height: currentHeight - cornerSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    hitTestBehavior: HitTestBehavior.opaque,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _onPanStart(details, isRight: true),
                      onPanUpdate: (details) => _onPanUpdate(details, isRight: true),
                      onPanEnd: _onPanEnd,
                      onPanCancel: _onPanCancel,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // Borda Inferior (Horizontal)
                Positioned(
                  left: 0,
                  bottom: -edgeThickness / 2,
                  width: currentWidth - cornerSize,
                  height: edgeThickness,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    hitTestBehavior: HitTestBehavior.opaque,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _onPanStart(details, isBottom: true),
                      onPanUpdate: (details) => _onPanUpdate(details, isBottom: true),
                      onPanEnd: _onPanEnd,
                      onPanCancel: _onPanCancel,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // Canto Inferior Direito (Diagonal)
                Positioned(
                  right: -edgeThickness / 2,
                  bottom: -edgeThickness / 2,
                  width: cornerSize + edgeThickness / 2,
                  height: cornerSize + edgeThickness / 2,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    hitTestBehavior: HitTestBehavior.opaque,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _onPanStart(details, isCorner: true),
                      onPanUpdate: (details) => _onPanUpdate(details, isCorner: true),
                      onPanEnd: _onPanEnd,
                      onPanCancel: _onPanCancel,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
