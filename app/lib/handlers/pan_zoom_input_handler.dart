import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PanZoomInputHandler {
  final ValueNotifier<Offset> panNotifier;
  final ValueNotifier<double> zoomNotifier;
  final VoidCallback onInteracting;
  final VoidCallback onScheduleBounceCheck;

  PanZoomInputHandler({
    required this.panNotifier,
    required this.zoomNotifier,
    required this.onInteracting,
    required this.onScheduleBounceCheck,
  });

  void handlePointerScroll(PointerScrollEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
      if (resolvedEvent is! PointerScrollEvent) return;
      final rawDy = resolvedEvent.scrollDelta.dy;
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isCtrlPressed) {
        final clampedDelta = rawDy.clamp(-80.0, 80.0);
        final delta = -clampedDelta * 0.0015;
        onInteracting();
        handleZoomDelta(delta, resolvedEvent.localPosition);
      } else if (isShiftPressed) {
        final clampedDelta = rawDy.clamp(-150.0, 150.0);
        handlePanDelta(Offset(-clampedDelta, 0.0));
        onScheduleBounceCheck();
      } else {
        final clampedDelta = rawDy.clamp(-150.0, 150.0);
        handlePanDelta(Offset(0.0, -clampedDelta));
        onScheduleBounceCheck();
      }
    });
  }

  void handlePanDelta(Offset delta) {
    onInteracting();
    final current = panNotifier.value;
    double newX = current.dx + delta.dx;
    double newY = current.dy + delta.dy;

    // Resistência elástica (rubberband) caso ultrapasse o limite do 4º quadrante (0, 0)
    if (newX > 0) {
      newX = current.dx + delta.dx * 0.12;
    }
    if (newY > 0) {
      newY = current.dy + delta.dy * 0.12;
    }

    panNotifier.value = Offset(newX, newY);
  }

  void handleZoomDelta(double delta, Offset focalPoint) {
    final double currentZoom = zoomNotifier.value;
    final Offset currentPan = panNotifier.value;
    final double newScale = (currentZoom + delta).clamp(0.25, 4.0);
    if (newScale == currentZoom) return;

    final Offset focalInCanvas = (focalPoint - currentPan) / currentZoom;
    zoomNotifier.value = newScale;
    final rawPan = focalPoint - (focalInCanvas * newScale);
    panNotifier.value = Offset(math.min(0.0, rawPan.dx), math.min(0.0, rawPan.dy));
  }
}
