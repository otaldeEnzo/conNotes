import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/ink_models.dart';
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

    isDrawing = true;
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
      if (isDrawing && activeStroke != null && activeStroke!.points.length >= 20 && !isSmartShapeSnapped) {
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
    onInteracting();

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

    // 3. Desenho normal da caneta
    final snapped = (rulerState != null && rulerState.isVisible)
        ? rulerState.snapPoint(canvasPoint)
        : ((protractorState != null && protractorState.isVisible)
            ? protractorState.snapPoint(canvasPoint)
            : null);
    final effectivePoint = snapped ?? canvasPoint;

    final lastPoint = activeStroke!.points.last.point;
    if ((effectivePoint - lastPoint).distanceSquared >= 2.25) {
      activeStroke!.points.add(StrokePoint(point: effectivePoint, pressure: pressure));
      activeStroke!.cachedRawPoints = null;
      activeStroke!.cachedPath = null;
      activeStrokeUpdateNotifier.value++;

      // Reinicia o timer Draw & Hold enquanto a caneta estiver em movimento
      _scheduleDrawAndHold(drawAndHoldDurationMs, preset, pressure);
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

    final finished = activeStroke;
    isDrawing = false;
    activeStroke = null;
    isSmartShapeSnapped = false;
    snappedShapeType = null;
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
