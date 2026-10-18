import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/ink_models.dart';
import '../widgets/canvas_layers.dart';
import '../widgets/smart_shapes.dart';
import '../widgets/stem_ruler_model.dart';
import '../widgets/stem_protractor_model.dart';

typedef _GetAsyncKeyStateNative = ffi.Int16 Function(ffi.Int32 vKey);
typedef _GetAsyncKeyStateDart = int Function(int vKey);

class InkInputHandler {
  static _GetAsyncKeyStateDart? _win32GetAsyncKeyState;
  static bool _win32InitAttempted = false;

  static bool _isWin32VirtualKeyPressed(int vKey) {
    if (!Platform.isWindows) return false;
    if (!_win32InitAttempted) {
      _win32InitAttempted = true;
      try {
        final user32 = ffi.DynamicLibrary.open('user32.dll');
        _win32GetAsyncKeyState = user32
            .lookupFunction<_GetAsyncKeyStateNative, _GetAsyncKeyStateDart>('GetAsyncKeyState');
      } catch (_) {}
    }
    final fn = _win32GetAsyncKeyState;
    if (fn == null) return false;
    return (fn(vKey) & 0x8000) != 0;
  }

  /// Verifica se Shift está pressionado (compatível com teclado físico e ExpressKeys/Stylus em mesas digitalizadoras)
  static bool isShiftModifierPressed() {
    if (HardwareKeyboard.instance.isShiftPressed) return true;
    // VK_SHIFT = 0x10, VK_LSHIFT = 0xA0, VK_RSHIFT = 0xA1
    return _isWin32VirtualKeyPressed(0x10) ||
        _isWin32VirtualKeyPressed(0xA0) ||
        _isWin32VirtualKeyPressed(0xA1);
  }

  /// Verifica se Ctrl está pressionado (compatível com teclado físico e ExpressKeys/Stylus em mesas digitalizadoras)
  static bool isCtrlModifierPressed() {
    if (HardwareKeyboard.instance.isControlPressed) return true;
    // VK_CONTROL = 0x11, VK_LCONTROL = 0xA2, VK_RCONTROL = 0xA3
    return _isWin32VirtualKeyPressed(0x11) ||
        _isWin32VirtualKeyPressed(0xA2) ||
        _isWin32VirtualKeyPressed(0xA3);
  }

  final ValueNotifier<int> activeStrokeUpdateNotifier;
  final VoidCallback onInteracting;

  bool isDrawing = false;
  InkStroke? activeStroke;
  Timer? drawAndHoldTimer;
  Offset? _holdAnchorPoint;

  bool isSmartShapeSnapped = false;
  ShapeType? snappedShapeType;
  ShapeType? activeModifierShapeType;
  Offset? smartShapeStartPoint;
  Offset? smartShapeInitialEndPoint;
  Offset? smartShapeSnapCursorPos;
  List<StrokePoint>? smartShapeOriginalPoints;
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
    activeModifierShapeType = null;
    _holdAnchorPoint = null;
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
    activeModifierShapeType = null;
    smartShapeStartPoint = canvasPoint;
    smartShapeInitialEndPoint = null;
    smartShapeSnapCursorPos = null;
    smartShapeOriginalPoints = null;
    smartShapeInitialBounds = null;
    smartShapeCenter = null;

    final snapped = (rulerState != null && rulerState.isVisible)
        ? rulerState.snapPoint(canvasPoint)
        : ((protractorState != null && protractorState.isVisible)
            ? protractorState.snapPoint(canvasPoint)
            : null);
    final effectiveStartPoint = snapped ?? canvasPoint;
    smartShapeStartPoint = effectiveStartPoint;
    _smoothedCursorPos = effectiveStartPoint;
    _smoothedPressure = pressure;

    isDrawing = true;
    final isShift = isShiftModifierPressed();
    final isCtrl = isCtrlModifierPressed();

    if (isShift || isCtrl) {
      final shapeType = isCtrl ? ShapeType.arrow : ShapeType.line;
      activeModifierShapeType = shapeType;
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

    _holdAnchorPoint = null;
    drawAndHoldTimer?.cancel();
  }

  void _scheduleDrawAndHold(int durationMs, PenSlotPreset preset, double pressure) {
    drawAndHoldTimer?.cancel();
    drawAndHoldTimer = Timer(Duration(milliseconds: durationMs), () {
      if (isDrawing && activeStroke != null && activeStroke!.points.length >= 14 && !isSmartShapeSnapped) {
        final recognized = SmartShapeEngine.recognizeDrawnShape(activeStroke!.points);
        if (recognized != null) {
          final originalPts = List<StrokePoint>.from(activeStroke!.points);
          isSmartShapeSnapped = true;
          snappedShapeType = recognized;
          smartShapeOriginalPoints = originalPts;
          smartShapeStartPoint = originalPts.first.point;
          smartShapeSnapCursorPos = originalPts.last.point;

          if (recognized == ShapeType.arrow || recognized == ShapeType.doubleArrow) {
            smartShapeInitialEndPoint = SmartShapeEngine.findArrowTipPoint(originalPts);
          } else {
            smartShapeInitialEndPoint = originalPts.last.point;
          }

          double minX = double.infinity, minY = double.infinity;
          double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
          for (final p in originalPts) {
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
            originalPts,
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

    // 1. Teclas Modificadoras: Shift = Linha Reta, Ctrl = Seta STEM (suporta mouse e mesa digitalizadora)
    final isShift = isShiftModifierPressed();
    final isCtrl = isCtrlModifierPressed();

    if (isShift || isCtrl || activeModifierShapeType != null) {
      drawAndHoldTimer?.cancel();
      if (isCtrl) {
        activeModifierShapeType = ShapeType.arrow;
      } else if (isShift) {
        activeModifierShapeType = ShapeType.line;
      }
      final shapeType = activeModifierShapeType!;
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

    // 2. Se já fez o snap do Smart Shape, o arraste redimensiona/orienta a forma suavemente
    if (isSmartShapeSnapped && snappedShapeType != null && smartShapeStartPoint != null) {
      final recognized = snappedShapeType!;
      final Path shapePath;

      if (recognized == ShapeType.line ||
          recognized == ShapeType.arrow ||
          recognized == ShapeType.doubleArrow) {
        final snapOrigin = smartShapeSnapCursorPos ?? canvasPoint;
        final initialEnd = smartShapeInitialEndPoint ?? snapOrigin;
        final dragDelta = canvasPoint - snapOrigin;
        final newEnd = initialEnd + dragDelta;
        shapePath = SmartShapeEngine.generateShapePath(recognized, smartShapeStartPoint!, newEnd);
      } else {
        final Rect newBounds;
        if (smartShapeInitialBounds != null && smartShapeCenter != null) {
          final initBounds = smartShapeInitialBounds!;
          final center = smartShapeCenter!;
          final snapOrigin = smartShapeSnapCursorPos ?? smartShapeStartPoint!;
          final delta = canvasPoint - snapOrigin;

          final newWidth = math.max(12.0, initBounds.width + delta.dx * 2);
          final newHeight = math.max(12.0, initBounds.height + delta.dy * 2);
          newBounds = Rect.fromCenter(center: center, width: newWidth, height: newHeight);
        } else {
          newBounds = Rect.fromPoints(smartShapeStartPoint!, canvasPoint);
        }
        shapePath = SmartShapeEngine.generateRecognizedPath(
          recognized,
          smartShapeOriginalPoints ?? activeStroke!.points,
          newBounds,
        );
      }

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

      if (pts.length >= 12) {
        if (_holdAnchorPoint == null) {
          _holdAnchorPoint = effectivePoint;
          _scheduleDrawAndHold(drawAndHoldDurationMs, preset, _smoothedPressure);
        } else {
          final movedDist = (effectivePoint - _holdAnchorPoint!).distance;
          if (movedDist > 5.0) {
            _holdAnchorPoint = effectivePoint;
            drawAndHoldTimer?.cancel();
            _scheduleDrawAndHold(drawAndHoldDurationMs, preset, _smoothedPressure);
          }
        }
      } else {
        _holdAnchorPoint = null;
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
    _holdAnchorPoint = null;
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
    _holdAnchorPoint = null;
    isDrawing = false;
    activeStroke = null;
    isSmartShapeSnapped = false;
    snappedShapeType = null;
    shapeDragStartPoint = null;
    activeStrokeUpdateNotifier.value++;
  }
}
