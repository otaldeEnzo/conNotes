import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/ink_models.dart';
import '../widgets/canvas_layers.dart';
import '../widgets/smart_shapes.dart';
import '../widgets/stem_ruler_model.dart';
import '../widgets/stem_protractor_model.dart';

class InkInputHandler {
  final ValueNotifier<int> activeStrokeUpdateNotifier;
  final VoidCallback onInteracting;

  bool isDrawing = false;
  InkStroke? activeStroke;
  Timer? drawAndHoldTimer;

  bool isSmartShapeSnapped = false;
  ShapeType? snappedShapeType;
  Offset? smartShapeStartPoint;
  Rect? smartShapeInitialBounds;
  Offset? smartShapeCenter;
  Offset? shapeDragStartPoint;

  InkInputHandler({
    required this.activeStrokeUpdateNotifier,
    required this.onInteracting,
  });

  void cancelActiveStroke() {
    isDrawing = false;
    activeStroke = null;
    drawAndHoldTimer?.cancel();
    activeStrokeUpdateNotifier.value++;
  }

  Offset? _smoothedCursorPos;
  double _smoothedPressure = 0.6;

  void startStroke({
    required Offset canvasPoint,
    required double pressure,
    required PenSlotPreset preset,
    StemRulerState? rulerState,
    StemProtractorState? protractorState,
    int drawAndHoldDurationMs = 700,
  }) {
    onInteracting();
    isSmartShapeSnapped = false;
    snappedShapeType = null;
    smartShapeStartPoint = canvasPoint;
    smartShapeInitialBounds = null;
    smartShapeCenter = null;

    final snapped = (rulerState != null && rulerState.isVisible)
        ? rulerState.snapPoint(canvasPoint)
        : ((protractorState != null && protractorState.isVisible)
            ? protractorState.snapPoint(canvasPoint)
            : null);
    final effectiveStartPoint = snapped ?? canvasPoint;
    _smoothedCursorPos = effectiveStartPoint;
    _smoothedPressure = pressure;

    isDrawing = true;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isShift || isCtrl) {
      final shapeType = isCtrl ? ShapeType.arrow : ShapeType.line;
      final initialPath = SmartShapeEngine.generateShapePath(
        shapeType,
        effectiveStartPoint,
        effectiveStartPoint + const Offset(1, 1),
      );
      final initialPoints = SmartShapeEngine.samplePathPoints(initialPath, pressure: pressure);

      activeStroke = InkStroke(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        points: initialPoints,
        color: preset.color,
        strokeWidth: preset.strokeWidth,
        toolType: preset.toolType,
        enablePressure: preset.enablePressure,
        isShape: true,
        cachedPath: initialPath,
      );
      activeStrokeUpdateNotifier.value++;
      return;
    }

    activeStroke = InkStroke(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      points: [StrokePoint(point: effectiveStartPoint, pressure: pressure)],
      color: preset.color,
      strokeWidth: preset.strokeWidth,
      toolType: preset.toolType,
      enablePressure: preset.enablePressure,
    );
    activeStrokeUpdateNotifier.value++;

    _scheduleDrawAndHold(drawAndHoldDurationMs, preset, pressure);
  }

  void _scheduleDrawAndHold(int durationMs, PenSlotPreset preset, double pressure) {
    drawAndHoldTimer?.cancel();
    drawAndHoldTimer = Timer(Duration(milliseconds: durationMs), () {
      if (isDrawing && activeStroke != null && activeStroke!.points.length >= 14 && !isSmartShapeSnapped) {
        final recognized = SmartShapeEngine.recognizeDrawnShape(activeStroke!.points);
        if (recognized != null) {
          isSmartShapeSnapped = true;
          snappedShapeType = recognized;

          double minX = double.infinity, minY = double.infinity;
          double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
          for (final p in activeStroke!.points) {
            if (p.point.dx < minX) minX = p.point.dx;
            if (p.point.dy < minY) minY = p.point.dy;
            if (p.point.dx > maxX) maxX = p.point.dx;
            if (p.point.dy > maxY) maxY = p.point.dy;
          }
          final drawnBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
          smartShapeInitialBounds = drawnBounds;
          smartShapeCenter = drawnBounds.center;

          final shapePath = SmartShapeEngine.generateRecognizedPath(
            recognized,
            activeStroke!.points,
            drawnBounds,
          );
          final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

          activeStroke = InkStroke(
            id: activeStroke!.id,
            points: shapePoints,
            color: activeStroke!.color,
            strokeWidth: activeStroke!.strokeWidth,
            toolType: preset.toolType,
            enablePressure: preset.enablePressure,
            isShape: true,
            cachedPath: shapePath,
          );
          activeStrokeUpdateNotifier.value++;
        }
      }
    });
  }

  void appendPoint({
    required Offset canvasPoint,
    required double pressure,
    required PenSlotPreset preset,
    StemRulerState? rulerState,
    StemProtractorState? protractorState,
    int drawAndHoldDurationMs = 700,
  }) {
    if (!isDrawing || activeStroke == null) return;

    // 1. Teclas Modificadoras: Shift = Linha Reta, Ctrl = Seta STEM
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isShift || isCtrl) {
      drawAndHoldTimer?.cancel();
      final shapeType = isCtrl ? ShapeType.arrow : ShapeType.line;
      final startPoint = smartShapeStartPoint ?? activeStroke!.points.first.point;
      final shapePath = SmartShapeEngine.generateShapePath(shapeType, startPoint, canvasPoint);
      final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

      activeStroke = InkStroke(
        id: activeStroke!.id,
        points: shapePoints,
        color: activeStroke!.color,
        strokeWidth: activeStroke!.strokeWidth,
        toolType: preset.toolType,
        enablePressure: preset.enablePressure,
        isShape: true,
        cachedPath: shapePath,
      );
      activeStrokeUpdateNotifier.value++;
      return;
    }

    // 2. Se já fez o snap do Smart Shape, o arraste redimensiona a forma a partir do centro
    if (isSmartShapeSnapped && snappedShapeType != null && smartShapeStartPoint != null) {
      final recognized = snappedShapeType!;
      final Rect newBounds;
      if (smartShapeInitialBounds != null && smartShapeCenter != null) {
        final initBounds = smartShapeInitialBounds!;
        final center = smartShapeCenter!;
        final delta = canvasPoint - smartShapeStartPoint!;

        final newWidth = math.max(12.0, initBounds.width + delta.dx * 2);
        final newHeight = math.max(12.0, initBounds.height + delta.dy * 2);
        newBounds = Rect.fromCenter(center: center, width: newWidth, height: newHeight);
      } else {
        newBounds = Rect.fromPoints(smartShapeStartPoint!, canvasPoint);
      }

      final shapePath = SmartShapeEngine.generateRecognizedPath(recognized, activeStroke!.points, newBounds);
      final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

      activeStroke = InkStroke(
        id: activeStroke!.id,
        points: shapePoints,
        color: activeStroke!.color,
        strokeWidth: activeStroke!.strokeWidth,
        toolType: preset.toolType,
        enablePressure: preset.enablePressure,
        isShape: true,
        cachedPath: shapePath,
      );
      activeStrokeUpdateNotifier.value++;
      return;
    }

    // 3. Desenho normal da caneta com Estabilização Adaptativa de Velocidade (Estilo 1€ Filter / GoodNotes)
    final isSnappedToTool = (rulerState != null && rulerState.isVisible) ||
        (protractorState != null && protractorState.isVisible);
    final snapped = (rulerState != null && rulerState.isVisible)
        ? rulerState.snapPoint(canvasPoint)
        : ((protractorState != null && protractorState.isVisible)
            ? protractorState.snapPoint(canvasPoint)
            : null);
    final rawPoint = snapped ?? canvasPoint;

    final prevSmoothed = _smoothedCursorPos ?? rawPoint;
    final rawDelta = rawPoint - prevSmoothed;
    final rawDist = rawDelta.distance;

    // Quando não está preso à régua/transferidor, aplica filtro adaptativo anti-tremor (jitter)
    // Em baixa velocidade (< 8px), filtra intensamente o tremor da mão/digitalizador (alpha ~0.36).
    // Em alta velocidade, reduz a inércia (alpha até 0.85) para zero input-lag.
    final Offset effectivePoint;
    if (isSnappedToTool && snapped != null) {
      effectivePoint = snapped;
      _smoothedCursorPos = snapped;
    } else {
      final velocityFactor = (rawDist / 10.0).clamp(0.0, 1.0);
      final alpha = 0.36 + 0.49 * velocityFactor;
      effectivePoint = Offset(
        prevSmoothed.dx + rawDelta.dx * alpha,
        prevSmoothed.dy + rawDelta.dy * alpha,
      );
      _smoothedCursorPos = effectivePoint;
    }

    _smoothedPressure = _smoothedPressure * 0.45 + pressure * 0.55;

    final pts = activeStroke!.points;
    final lastPoint = pts.last.point;
    final distSq = (effectivePoint - lastPoint).distanceSquared;

    // Limiar mínimo de espaçamento (1.35px, distSq >= 1.8) para evitar acúmulo de micro-vértices
    // que causam instabilidade de tangente/normal e serrilhado no contorno.
    if (distSq >= 1.8) {
      pts.add(StrokePoint(point: effectivePoint, pressure: _smoothedPressure));
      activeStroke!.cachedPath = null;
      activeStrokeUpdateNotifier.value++;

      if (distSq < 16.0) {
        _scheduleDrawAndHold(drawAndHoldDurationMs, preset, _smoothedPressure);
      } else {
        drawAndHoldTimer?.cancel();
      }
    }
  }

  void startGeometricShape({
    required ShapeType shapeType,
    required Offset canvasPoint,
    required double pressure,
    required PenSlotPreset preset,
  }) {
    onInteracting();
    shapeDragStartPoint = canvasPoint;
    isDrawing = true;

    final initialPath = SmartShapeEngine.generateShapePath(
      shapeType,
      canvasPoint,
      canvasPoint + const Offset(1, 1),
    );
    final initialPoints = SmartShapeEngine.samplePathPoints(initialPath, pressure: pressure);

    activeStroke = InkStroke(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      points: initialPoints,
      color: preset.color,
      strokeWidth: preset.strokeWidth,
      toolType: preset.toolType,
      enablePressure: preset.enablePressure,
      isShape: true,
      cachedPath: initialPath,
    );
    activeStrokeUpdateNotifier.value++;
  }

  void updateGeometricShape({
    required ShapeType shapeType,
    required Offset canvasPoint,
    required double pressure,
    required PenSlotPreset preset,
  }) {
    if (!isDrawing || shapeDragStartPoint == null || activeStroke == null) return;
    onInteracting();

    final shapePath = SmartShapeEngine.generateShapePath(
      shapeType,
      shapeDragStartPoint!,
      canvasPoint,
    );
    final shapePoints = SmartShapeEngine.samplePathPoints(shapePath, pressure: pressure);

    activeStroke = InkStroke(
      id: activeStroke!.id,
      points: shapePoints,
      color: preset.color,
      strokeWidth: preset.strokeWidth,
      toolType: preset.toolType,
      enablePressure: preset.enablePressure,
      isShape: true,
      cachedPath: shapePath,
    );
    activeStrokeUpdateNotifier.value++;
  }

  InkStroke? finishStroke() {
    drawAndHoldTimer?.cancel();
    shapeDragStartPoint = null;
    if (!isDrawing || activeStroke == null) return null;

    final finished = activeStroke!;
    isDrawing = false;
    activeStroke = null;
    isSmartShapeSnapped = false;
    snappedShapeType = null;

    // Garante que o caminho cachedPath definitivo seja construído com 100% dos pontos finais
    if (!finished.isShape && finished.points.isNotEmpty) {
      if ((finished.toolType == InkToolType.fountain || finished.enablePressure)) {
        finished.cachedPath = FreehandOutlineRenderer.generateOutlinePath(
          finished.points,
          baseWidth: finished.strokeWidth,
          isTapered: finished.toolType == InkToolType.fountain,
          isLive: false,
        );
      } else {
        finished.cachedPath = StrokePictureCache.buildSmoothCatmullRomPath(finished.points);
      }
    }

    activeStrokeUpdateNotifier.value++;
    return finished;
  }

  void cancel() {
    drawAndHoldTimer?.cancel();
    isDrawing = false;
    activeStroke = null;
    isSmartShapeSnapped = false;
    snappedShapeType = null;
    shapeDragStartPoint = null;
    activeStrokeUpdateNotifier.value++;
  }
}
