import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import '../widgets/selection_models.dart';
import '../widgets/ink_models.dart';
import '../widgets/note_models.dart';
import '../widgets/selection_overlay_painter.dart';
import '../widgets/canvas_layers.dart';
import '../widgets/canvas_card_widget.dart';

class SelectionInputHandler {
  final ValueNotifier<int> selectionUpdateNotifier;
  final VoidCallback onInteracting;
  final VoidCallback? onStrokesCommitted;
  final SelectedStrokesPictureCache dragPictureCache;

  Offset? selectionStartCanvasPoint;

  SelectionInputHandler({
    required this.selectionUpdateNotifier,
    required this.onInteracting,
    this.onStrokesCommitted,
    SelectedStrokesPictureCache? dragPictureCache,
  }) : dragPictureCache = dragPictureCache ?? SelectedStrokesPictureCache();

  static double getCardEffectiveHeight(CanvasCardModel c) {
    if (c.isCollapsed) return 36.0;
    return math.max(c.height, c.calculateMinHeight());
  }

  static double _getCardEffectiveHeight(CanvasCardModel c) => getCardEffectiveHeight(c);

  void startSelection({
    required Offset canvasPoint,
    required SelectionState selectionState,
    required SelectionType selectionType,
    required double zoomScale,
    required NoteDocument? currentNote,
    required Function(SelectionState) onUpdateState,
  }) {
    onInteracting();
    selectionStartCanvasPoint = canvasPoint;

    if (selectionState.hasSelection && currentNote != null) {
      final bounds = selectionState.bounds!;
      final handle = SelectionGeometry.getHandleAtPoint(
        canvasPoint,
        bounds,
        zoomScale,
        rotation: selectionState.rotationAngle,
      );

      if (handle != SelectionHandleType.none) {
        // Clicou em um manipulador de transformação
        dragPictureCache.update(currentNote, selectionState.selectedStrokeIds);
        onUpdateState(selectionState.copyWith(
          activeHandle: handle,
          transformPivot: bounds.center,
          transformBounds: bounds,
        ));
        selectionUpdateNotifier.value++;
        return;
      } else if (bounds.inflate(10 / zoomScale).contains(canvasPoint)) {
        // Clicou dentro do corpo da Bounding Box -> arrastar seleção
        dragPictureCache.update(currentNote, selectionState.selectedStrokeIds);
        onUpdateState(selectionState.copyWith(
          isDraggingSelection: true,
          dragOffset: Offset.zero,
        ));
        selectionUpdateNotifier.value++;
        return;
      }
    }

    // Iniciar seleção de área (retângulo ou laço)
    onUpdateState(SelectionState(
      type: selectionType,
      isSelectingArea: true,
      startPoint: canvasPoint,
      currentPoint: canvasPoint,
      lassoPoints: [canvasPoint],
    ));
    selectionUpdateNotifier.value++;
  }

  void updateSelection({
    required Offset canvasPoint,
    required SelectionState selectionState,
    required SelectionType selectionType,
    required double zoomScale,
    required Function(SelectionState) onUpdateState,
  }) {
    if (selectionStartCanvasPoint == null) return;
    onInteracting();

    if (selectionState.isDraggingSelection) {
      final delta = canvasPoint - selectionStartCanvasPoint!;
      onUpdateState(selectionState.copyWith(dragOffset: delta));
      selectionUpdateNotifier.value++;
      return;
    }

    if (selectionState.activeHandle != SelectionHandleType.none && selectionState.bounds != null) {
      final bounds = selectionState.bounds!;
      final delta = canvasPoint - selectionStartCanvasPoint!;
      double left = bounds.left;
      double top = bounds.top;
      double right = bounds.right;
      double bottom = bounds.bottom;

      switch (selectionState.activeHandle) {
        case SelectionHandleType.centerRight:
        case SelectionHandleType.topRight:
        case SelectionHandleType.bottomRight:
          right = math.max(left + 20.0, bounds.right + delta.dx);
          break;
        case SelectionHandleType.centerLeft:
        case SelectionHandleType.topLeft:
        case SelectionHandleType.bottomLeft:
          left = math.min(right - 20.0, bounds.left + delta.dx);
          break;
        default:
          break;
      }

      switch (selectionState.activeHandle) {
        case SelectionHandleType.bottomCenter:
        case SelectionHandleType.bottomLeft:
        case SelectionHandleType.bottomRight:
          bottom = math.max(top + 20.0, bounds.bottom + delta.dy);
          break;
        case SelectionHandleType.topCenter:
        case SelectionHandleType.topLeft:
        case SelectionHandleType.topRight:
          top = math.min(bottom - 20.0, bounds.top + delta.dy);
          break;
        default:
          break;
      }

      final newTransformBounds = Rect.fromLTRB(left, top, right, bottom);
      onUpdateState(selectionState.copyWith(transformBounds: newTransformBounds));
      selectionUpdateNotifier.value++;
      return;
    }

    // Seleção de área em andamento
    onUpdateState(selectionState.copyWith(
      isSelectingArea: true,
      currentPoint: canvasPoint,
      lassoPoints: selectionType == SelectionType.lasso
          ? [...selectionState.lassoPoints, canvasPoint]
          : selectionState.lassoPoints,
    ));
    selectionUpdateNotifier.value++;
  }

  void finishSelection({
    required SelectionState selectionState,
    required NoteDocument? currentNote,
    required Function(SelectionState) onUpdateState,
  }) {
    selectionStartCanvasPoint = null;
    if (currentNote == null) return;

    if (selectionState.activeHandle != SelectionHandleType.none &&
        selectionState.transformBounds != null &&
        selectionState.bounds != null) {
      final originalBounds = selectionState.bounds!;
      final newBounds = selectionState.transformBounds!;
      final scaleX = originalBounds.width > 0 ? (newBounds.width / originalBounds.width) : 1.0;
      final scaleY = originalBounds.height > 0 ? (newBounds.height / originalBounds.height) : 1.0;
      final geomScale = math.sqrt(scaleX.abs() * scaleY.abs());

      final updatedStrokes = <InkStroke>[];
      for (final id in selectionState.selectedStrokeIds) {
        final s = currentNote.getStroke(id);
        if (s != null) {
          final newPoints = <StrokePoint>[];
          for (final p in s.points) {
            final localP = p.point + s.transform;
            final u = (localP.dx - originalBounds.left) / originalBounds.width;
            final v = (localP.dy - originalBounds.top) / originalBounds.height;
            final newX = newBounds.left + u * newBounds.width;
            final newY = newBounds.top + v * newBounds.height;
            newPoints.add(StrokePoint(point: Offset(newX, newY), pressure: p.pressure, tilt: p.tilt));
          }

          final newStrokeWidth = (s.strokeWidth * geomScale).clamp(0.5, 50.0);
          final Path newCachedPath;
          if (s.toolType == InkToolType.fountain || s.enablePressure) {
            newCachedPath = FreehandOutlineRenderer.generateOutlinePath(
              newPoints,
              baseWidth: newStrokeWidth,
              isTapered: s.toolType == InkToolType.fountain,
            );
          } else {
            newCachedPath = InkStroke.buildCatmullRomPath(newPoints);
          }

          final transformed = InkStroke(
            id: s.id,
            points: newPoints,
            color: s.color,
            strokeWidth: newStrokeWidth,
            toolType: s.toolType,
            enablePressure: s.enablePressure,
            transform: Offset.zero,
            boundingBox: SelectionGeometry.computePointsBounds(newPoints, newStrokeWidth),
            cachedPath: newCachedPath,
          );

          updatedStrokes.add(transformed);
        }
      }

      if (updatedStrokes.isNotEmpty) {
        currentNote.updateAllStrokes(updatedStrokes);
        onStrokesCommitted?.call();
      }

      for (final cardId in selectionState.selectedCardIds) {
        final idx = currentNote.cards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          final card = currentNote.cards[idx];
          final u = (card.x - originalBounds.left) / originalBounds.width;
          final v = (card.y - originalBounds.top) / originalBounds.height;
          final newX = newBounds.left + u * newBounds.width;
          final newY = newBounds.top + v * newBounds.height;
          final newW = (card.width * scaleX).clamp(200.0, 1600.0);
          final effectiveH = _getCardEffectiveHeight(card);
          final newH = (effectiveH * scaleY).clamp(card.minHeight, 2400.0);
          currentNote.cards[idx] = card.copyWith(
            x: newX,
            y: newY,
            width: newW,
            height: newH,
          );
        }
      }

      dragPictureCache.invalidate();
      onUpdateState(selectionState.copyWith(
        activeHandle: SelectionHandleType.none,
        bounds: newBounds,
        clearTransformBounds: true,
      ));
      selectionUpdateNotifier.value++;
      return;
    }

    if (selectionState.isDraggingSelection &&
        selectionState.dragOffset != Offset.zero &&
        selectionState.bounds != null) {
      final offset = selectionState.dragOffset;
      final updatedStrokes = <InkStroke>[];

      for (final id in selectionState.selectedStrokeIds) {
        final s = currentNote.getStroke(id);
        if (s != null) {
          final newPoints = s.points.map((p) => StrokePoint(
            point: p.point + s.transform + offset,
            pressure: p.pressure,
            tilt: p.tilt,
          )).toList();

          final Path newCachedPath;
          if (s.toolType == InkToolType.fountain || s.enablePressure) {
            newCachedPath = FreehandOutlineRenderer.generateOutlinePath(
              newPoints,
              baseWidth: s.strokeWidth,
              isTapered: s.toolType == InkToolType.fountain,
            );
          } else {
            newCachedPath = InkStroke.buildCatmullRomPath(newPoints);
          }

          final shifted = InkStroke(
            id: s.id,
            points: newPoints,
            color: s.color,
            strokeWidth: s.strokeWidth,
            toolType: s.toolType,
            enablePressure: s.enablePressure,
            transform: Offset.zero,
            boundingBox: SelectionGeometry.computePointsBounds(newPoints, s.strokeWidth),
            cachedPath: newCachedPath,
          );
          updatedStrokes.add(shifted);
        }
      }

      if (updatedStrokes.isNotEmpty) {
        currentNote.updateAllStrokes(updatedStrokes);
        onStrokesCommitted?.call();
      }

      for (final cardId in selectionState.selectedCardIds) {
        final idx = currentNote.cards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          final card = currentNote.cards[idx];
          currentNote.cards[idx] = card.copyWith(
            x: card.x + offset.dx,
            y: card.y + offset.dy,
          );
        }
      }

      dragPictureCache.invalidate();
      onUpdateState(selectionState.copyWith(
        isDraggingSelection: false,
        dragOffset: Offset.zero,
        bounds: selectionState.bounds?.shift(offset),
      ));
      selectionUpdateNotifier.value++;
      return;
    }

    if (selectionState.isSelectingArea) {
      Rect? selectionBox;
      final isLasso = selectionState.type == SelectionType.lasso && selectionState.lassoPoints.length > 2;

      if (selectionState.startPoint != null && selectionState.currentPoint != null) {
        selectionBox = Rect.fromPoints(selectionState.startPoint!, selectionState.currentPoint!);
      } else if (selectionState.lassoPoints.isNotEmpty) {
        selectionBox = SelectionGeometry.computePointsBounds(
          selectionState.lassoPoints.map((p) => StrokePoint(point: p)).toList(),
          0.0,
        );
      }

      final isBoxDrag = selectionBox != null && (selectionBox.width > 5 || selectionBox.height > 5);

      if (isBoxDrag) {
        final selectedIds = <String>{};
        final selectedCards = <String>{};

        if (isLasso) {
          final poly = selectionState.lassoPoints;
          for (final stroke in currentNote.strokes) {
            if (SelectionGeometry.isStrokeInLasso(stroke, poly)) {
              selectedIds.add(stroke.id);
            }
          }
          for (final card in currentNote.cards) {
            final cardH = _getCardEffectiveHeight(card);
            final cardRect = Rect.fromLTWH(card.x, card.y, card.width, cardH);
            if (SelectionGeometry.isPointInPolygon(cardRect.center, poly) ||
                SelectionGeometry.isPointInPolygon(cardRect.topLeft, poly) ||
                SelectionGeometry.isPointInPolygon(cardRect.bottomRight, poly)) {
              selectedCards.add(card.id);
            }
          }
        } else {
          for (final stroke in currentNote.strokes) {
            if (SelectionGeometry.isStrokeInRect(stroke, selectionBox)) {
              selectedIds.add(stroke.id);
            }
          }
          for (final card in currentNote.cards) {
            final cardH = _getCardEffectiveHeight(card);
            final cardRect = Rect.fromLTWH(card.x, card.y, card.width, cardH);
            if (selectionBox.overlaps(cardRect)) {
              selectedCards.add(card.id);
            }
          }
        }

        if (selectedIds.isNotEmpty || selectedCards.isNotEmpty) {
          final selectedStrokesList = currentNote.strokes.where((s) => selectedIds.contains(s.id)).toList();
          Rect? combinedBounds = SelectionGeometry.computeCombinedBounds(selectedStrokesList);

          if (selectedCards.isNotEmpty) {
            double minX = double.infinity, minY = double.infinity;
            double maxX = -double.infinity, maxY = -double.infinity;
            for (final cardId in selectedCards) {
              final c = currentNote.cards.firstWhere((card) => card.id == cardId);
              final cardH = _getCardEffectiveHeight(c);
              if (c.x < minX) minX = c.x;
              if (c.y < minY) minY = c.y;
              if (c.x + c.width > maxX) maxX = c.x + c.width;
              if (c.y + cardH > maxY) maxY = c.y + cardH;
            }
            final cardsRect = Rect.fromLTRB(minX, minY, maxX, maxY);
            combinedBounds = combinedBounds != null ? combinedBounds.expandToInclude(cardsRect) : cardsRect;
          }

          onUpdateState(SelectionState(
            type: selectionState.type,
            selectedStrokeIds: selectedIds,
            selectedCardIds: selectedCards,
            bounds: combinedBounds,
          ));
        } else {
          onUpdateState(SelectionState.empty());
        }
      } else {
        // Clique único (tap): Seleciona o traço ou card clicado diretamente
        final tapPoint = selectionState.startPoint ?? selectionState.currentPoint;
        if (tapPoint != null) {
          String? hitStrokeId;
          final tolerance = 14.0 / (currentNote.zoomScale > 0 ? currentNote.zoomScale : 1.0);

          // Percorre traços de cima para baixo (z-index invertido)
          for (int i = currentNote.strokes.length - 1; i >= 0; i--) {
            final s = currentNote.strokes[i];
            if (SelectionGeometry.isPointNearStroke(tapPoint, s, tolerance)) {
              hitStrokeId = s.id;
              break;
            }
          }

          if (hitStrokeId != null) {
            final s = currentNote.getStroke(hitStrokeId);
            final bounds = s != null ? (s.boundingBox ?? SelectionGeometry.computeStrokeBounds(s)) : null;
            onUpdateState(SelectionState(
              type: selectionState.type,
              selectedStrokeIds: {hitStrokeId},
              bounds: bounds,
            ));
          } else {
            String? hitCardId;
            for (int i = currentNote.cards.length - 1; i >= 0; i--) {
              final c = currentNote.cards[i];
              final cardH = _getCardEffectiveHeight(c);
              final r = Rect.fromLTWH(c.x, c.y, c.width, cardH);
              if (r.contains(tapPoint)) {
                hitCardId = c.id;
                break;
              }
            }

            if (hitCardId != null) {
              final c = currentNote.cards.firstWhere((card) => card.id == hitCardId);
              final cardH = _getCardEffectiveHeight(c);
              final bounds = Rect.fromLTWH(c.x, c.y, c.width, cardH);
              onUpdateState(SelectionState(
                type: selectionState.type,
                selectedCardIds: {hitCardId},
                bounds: bounds,
              ));
            } else {
              onUpdateState(SelectionState.empty());
            }
          }
        } else {
          onUpdateState(SelectionState.empty());
        }
      }
      selectionUpdateNotifier.value++;
    }
  }
}
