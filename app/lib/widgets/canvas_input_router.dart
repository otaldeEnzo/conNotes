import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../controllers/canvas_input_context.dart';
import '../handlers/ink_input_handler.dart';
import '../handlers/selection_input_handler.dart';
import '../handlers/pan_zoom_input_handler.dart';
import '../widgets/ink_models.dart';
import '../widgets/selection_models.dart';
import '../widgets/stem_ruler_model.dart';
import '../widgets/stem_protractor_model.dart';
import '../widgets/card_format_floating_pill.dart';

typedef CanvasLayerBuilder = Widget Function(BuildContext context, InkStroke? Function() getActiveStroke);

class CanvasInputRouter extends StatefulWidget {
  final CanvasInputContext canvasContext;
  final Widget? child;
  final CanvasLayerBuilder? builder;
  final PenSlotPreset activePenPreset;
  final ValueNotifier<int> activeStrokeUpdateNotifier;
  final ValueNotifier<int> selectionUpdateNotifier;
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final Function(InkStroke) onCommitStroke;
  final VoidCallback onScheduleBounceCheck;

  const CanvasInputRouter({
    super.key,
    required this.canvasContext,
    this.child,
    this.builder,
    required this.activePenPreset,
    required this.activeStrokeUpdateNotifier,
    required this.selectionUpdateNotifier,
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onCommitStroke,
    required this.onScheduleBounceCheck,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided');

  @override
  State<CanvasInputRouter> createState() => _CanvasInputRouterState();
}

class _CanvasInputRouterState extends State<CanvasInputRouter> {
  late final InkInputHandler _inkHandler;
  late final SelectionInputHandler _selectionHandler;
  late final PanZoomInputHandler _panZoomHandler;

  bool _isDraggingRuler = false;
  bool _isRotatingRuler = false;
  Offset? _rulerDragStart;
  StemRulerState? _rulerInitialState;

  bool _isDraggingProtractor = false;
  bool _isRotatingProtractor = false;
  Offset? _protractorDragStart;
  StemProtractorState? _protractorInitialState;

  @override
  void initState() {
    super.initState();
    _inkHandler = InkInputHandler(
      activeStrokeUpdateNotifier: widget.activeStrokeUpdateNotifier,
      onInteracting: widget.canvasContext.setInteracting,
    );
    _selectionHandler = SelectionInputHandler(
      selectionUpdateNotifier: widget.selectionUpdateNotifier,
      onInteracting: widget.canvasContext.setInteracting,
    );
    _panZoomHandler = PanZoomInputHandler(
      panNotifier: widget.panNotifier,
      zoomNotifier: widget.zoomNotifier,
      onInteracting: widget.canvasContext.setInteracting,
      onScheduleBounceCheck: widget.onScheduleBounceCheck,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.canvasContext;
    final note = ctx.currentNote;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (globalIsHoveringFloatingPill) {
            return;
          }
          _panZoomHandler.handlePointerScroll(event);
        }
      },
      onPointerDown: (event) {
        ctx.updateMousePos(event.localPosition);
        final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
        final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));
        ctx.updatePointerInfo(event.timeStamp.inMilliseconds, canvasPoint);

        if (event.buttons == 4) {
          // Botão do meio
          return;
        }

        if (event.buttons == 1) {
          ctx.hideUIElementsOnInteraction();

          // Interação direta com a Régua STEM (Arrastar ou Rotacionar)
          if (ctx.rulerState.isVisible && ctx.rulerState.containsPoint(canvasPoint)) {
            final isCenter = ctx.rulerState.isNearCenterProtractor(canvasPoint);
            _isRotatingRuler = isCenter;
            _isDraggingRuler = !isCenter;
            _rulerDragStart = canvasPoint;
            _rulerInitialState = ctx.rulerState;
            ctx.setInteracting();
            return;
          }

          // Interação direta com o Transferidor STEM (Arrastar ou Rotacionar)
          if (ctx.protractorState.isVisible && ctx.protractorState.containsPoint(canvasPoint)) {
            final isRotate = ctx.protractorState.isNearRotateHandle(canvasPoint);
            _isRotatingProtractor = isRotate;
            _isDraggingProtractor = !isRotate;
            _protractorDragStart = canvasPoint;
            _protractorInitialState = ctx.protractorState;
            ctx.setInteracting();
            return;
          }

          // Interação e Seleção de Cards do Canvas
          final clickedCard = ctx.findCardAtPoint(canvasPoint);
          if (clickedCard != null) {
            if (ctx.selectedCardId != clickedCard.id) {
              ctx.selectCard(clickedCard.id);
              ctx.updateSelectionState(SelectionState.empty());
            }
            return;
          } else if (ctx.selectedCardId != null && ctx.selectionState.selectedCardIds.isEmpty) {
            FocusManager.instance.primaryFocus?.unfocus();
            ctx.selectCard(null);
          } else if (ctx.selectionState.selectedCardIds.isNotEmpty) {
            FocusManager.instance.primaryFocus?.unfocus();
            ctx.selectCard(null);
            ctx.updateSelectionState(SelectionState.empty());
          }

          if (note != null) {
            if (ctx.activeTool == 'card_insert') {
              ctx.insertCardAt(canvasPoint);
              return;
            } else if (ctx.activeTool == 'laser') {
              ctx.laserEngine.onPointerDown(canvasPoint);
              return;
            } else if (ctx.activeTool == 'select') {
              _selectionHandler.startSelection(
                canvasPoint: canvasPoint,
                selectionState: ctx.selectionState,
                selectionType: ctx.selectionType,
                zoomScale: ctx.zoomScale,
                currentNote: note,
                onUpdateState: ctx.updateSelectionState,
              );
              return;
            }

            if (ctx.activeTool == 'pen') {
              final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                  ? event.pressure
                  : 0.6;
              _inkHandler.startStroke(
                canvasPoint: canvasPoint,
                pressure: pressure,
                preset: widget.activePenPreset,
                rulerState: ctx.rulerState,
                protractorState: ctx.protractorState,
              );
            } else if (ctx.activeTool == 'shapes') {
              final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                  ? event.pressure
                  : 0.6;
              _inkHandler.startGeometricShape(
                shapeType: ctx.activeShapeType,
                canvasPoint: canvasPoint,
                pressure: pressure,
                preset: widget.activePenPreset,
              );
            } else if (ctx.activeTool == 'eraser') {
              ctx.eraseStrokesNear(canvasPoint);
            }
          }
        }
      },
      onPointerMove: (event) {
        ctx.updateMousePos(event.localPosition);

        if (event.buttons == 4) {
          _panZoomHandler.handlePanDelta(event.delta);
          return;
        }

        if (event.buttons == 1) {
          final rawCanvasPoint = (event.localPosition - ctx.panOffset) / ctx.zoomScale;
          final canvasPoint = Offset(math.max(0.0, rawCanvasPoint.dx), math.max(0.0, rawCanvasPoint.dy));

          if (ctx.activeTool == 'laser') {
            ctx.laserEngine.onPointerMove(canvasPoint);
            return;
          }

          // Movimentação / Rotação da Régua STEM
          if (_isDraggingRuler && _rulerDragStart != null && _rulerInitialState != null) {
            ctx.setInteracting();
            final delta = canvasPoint - _rulerDragStart!;
            ctx.updateRulerState(_rulerInitialState!.copyWith(
              center: _rulerInitialState!.center + delta,
            ));
            return;
          }

          if (_isRotatingRuler && _rulerInitialState != null && _rulerDragStart != null) {
            ctx.setInteracting();
            final center = _rulerInitialState!.center;
            final initialAngle = math.atan2(_rulerDragStart!.dy - center.dy, _rulerDragStart!.dx - center.dx);
            final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);

            double diff = currentAngle - initialAngle;
            while (diff > math.pi) diff -= 2 * math.pi;
            while (diff < -math.pi) diff += 2 * math.pi;

            final targetAngle = _rulerInitialState!.angle + diff;
            final snapped = StemRulerState.snapAngle(targetAngle);
            ctx.updateRulerState(_rulerInitialState!.copyWith(angle: snapped));
            return;
          }

          // Movimentação / Rotação do Transferidor STEM
          if (_isDraggingProtractor && _protractorDragStart != null && _protractorInitialState != null) {
            ctx.setInteracting();
            final delta = canvasPoint - _protractorDragStart!;
            ctx.updateProtractorState(_protractorInitialState!.copyWith(
              center: _protractorInitialState!.center + delta,
            ));
            return;
          }

          if (_isRotatingProtractor && _protractorInitialState != null && _protractorDragStart != null) {
            ctx.setInteracting();
            final center = _protractorInitialState!.center;
            final initialAngle = math.atan2(_protractorDragStart!.dy - center.dy, _protractorDragStart!.dx - center.dx);
            final currentAngle = math.atan2(canvasPoint.dy - center.dy, canvasPoint.dx - center.dx);

            double diff = currentAngle - initialAngle;
            while (diff > math.pi) diff -= 2 * math.pi;
            while (diff < -math.pi) diff += 2 * math.pi;

            final targetAngle = _protractorInitialState!.angle + diff;
            final snapped = StemProtractorState.snapAngle(targetAngle);
            ctx.updateProtractorState(_protractorInitialState!.copyWith(angle: snapped));
            return;
          }

          if (note != null) {
            if (ctx.activeTool == 'pen') {
              final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                  ? event.pressure
                  : 0.6;
              _inkHandler.appendPoint(
                canvasPoint: canvasPoint,
                pressure: pressure,
                preset: widget.activePenPreset,
                rulerState: ctx.rulerState,
                protractorState: ctx.protractorState,
              );
            } else if (ctx.activeTool == 'shapes') {
              final pressure = event.kind != PointerDeviceKind.mouse && event.pressure > 0.0
                  ? event.pressure
                  : 0.6;
              _inkHandler.updateGeometricShape(
                shapeType: ctx.activeShapeType,
                canvasPoint: canvasPoint,
                pressure: pressure,
                preset: widget.activePenPreset,
              );
            } else if (ctx.activeTool == 'eraser') {
              ctx.eraseStrokesNear(canvasPoint);
            } else if (ctx.activeTool == 'select') {
              _selectionHandler.updateSelection(
                canvasPoint: canvasPoint,
                selectionState: ctx.selectionState,
                selectionType: ctx.selectionType,
                zoomScale: ctx.zoomScale,
                onUpdateState: ctx.updateSelectionState,
              );
            }
          }
        }
      },
      onPointerUp: (event) {
        if (ctx.activeTool == 'laser') {
          ctx.laserEngine.onPointerUp();
          return;
        }

        if (_isDraggingRuler || _isRotatingRuler) {
          _isDraggingRuler = false;
          _isRotatingRuler = false;
          _rulerDragStart = null;
          _rulerInitialState = null;
          return;
        }

        if (_isDraggingProtractor || _isRotatingProtractor) {
          _isDraggingProtractor = false;
          _isRotatingProtractor = false;
          _protractorDragStart = null;
          _protractorInitialState = null;
          return;
        }

        if (ctx.activeTool == 'pen' || ctx.activeTool == 'shapes') {
          final finishedStroke = _inkHandler.finishStroke();
          if (finishedStroke != null) {
            widget.onCommitStroke(finishedStroke);
          }
        } else if (ctx.activeTool == 'eraser') {
          ctx.scheduleEraseCommit();
        } else if (ctx.activeTool == 'select') {
          _selectionHandler.finishSelection(
            selectionState: ctx.selectionState,
            currentNote: note,
            onUpdateState: ctx.updateSelectionState,
          );
        }
      },
      child: widget.builder != null 
          ? widget.builder!(context, () => _inkHandler.activeStroke) 
          : widget.child!,
    );
  }
}
