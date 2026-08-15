import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'ink_models.dart';
import 'selection_models.dart';

/// Gerenciador de Cache para o bloco de traços selecionados em movimento
class SelectedStrokesPictureCache {
  ui.Picture? _picture;
  Set<String>? _cachedIds;

  void update(List<InkStroke> allStrokes, Set<String> selectedIds) {
    if (_cachedIds != null &&
        _cachedIds!.length == selectedIds.length &&
        _cachedIds!.containsAll(selectedIds) &&
        _picture != null) {
      return;
    }

    _picture?.dispose();
    _picture = null;

    if (selectedIds.isEmpty) {
      _cachedIds = null;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final reusablePaint = Paint();

    for (var i = 0; i < allStrokes.length; i++) {
      final stroke = allStrokes[i];
      if (selectedIds.contains(stroke.id)) {
        SelectionOverlayPainter._drawStrokeDirectFast(canvas, stroke, reusablePaint);
      }
    }

    _picture = recorder.endRecording();
    _cachedIds = Set<String>.from(selectedIds);
  }

  void draw(Canvas canvas) {
    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _cachedIds = null;
  }
}

/// Painter isolado de alta performance para desenhar o Overlay de Seleção
/// (Caixa delimitadora, Laço dinâmico, Traços em arraste e Alças Moscaro v2).
class SelectionOverlayPainter extends CustomPainter {
  final SelectionState selectionState;
  final List<InkStroke> allStrokes;
  final Offset panOffset;
  final double zoomScale;
  final ValueNotifier<int>? repaintNotifier;
  final SelectedStrokesPictureCache dragCache;

  SelectionOverlayPainter({
    required this.selectionState,
    required this.allStrokes,
    required this.panOffset,
    required this.zoomScale,
    this.repaintNotifier,
    required this.dragCache,
  }) : super(repaint: repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // 1. Desenhar a área de seleção em andamento (Retângulo ou Laço)
    if (selectionState.isSelectingArea) {
      if (selectionState.type == SelectionType.rectangle &&
          selectionState.startPoint != null &&
          selectionState.currentPoint != null) {
        _drawSelectingRect(canvas, Rect.fromPoints(selectionState.startPoint!, selectionState.currentPoint!));
      } else if (selectionState.type == SelectionType.lasso && selectionState.lassoPoints.length > 1) {
        _drawSelectingLasso(canvas, selectionState.lassoPoints);
      }
    }

    // 2. Se houver traços selecionados, desenhar a Bounding Box e traços em arraste
    if (selectionState.hasSelection) {
      final bounds = selectionState.bounds!;
      final dragOffset = selectionState.dragOffset;
      final shiftedBounds = bounds.shift(dragOffset);

      // 2.1 Zero-Lag: Desenhar traços selecionados deslocados com 1 única draw call Picture nativa
      if (selectionState.isDraggingSelection && dragOffset != Offset.zero) {
        dragCache.update(allStrokes, selectionState.selectedStrokeIds);
        canvas.save();
        canvas.translate(dragOffset.dx, dragOffset.dy);
        dragCache.draw(canvas);
        canvas.restore();
      }

      // 2.2 Moldura da Bounding Box com Aurora Glow Moscaro v2
      _drawSelectionBox(canvas, shiftedBounds);
    }

    canvas.restore();
  }

  void _drawSelectingRect(Canvas canvas, Rect rect) {
    final fillPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, rect, borderPaint);
  }

  void _drawSelectingLasso(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedPath(canvas, path, borderPaint);
  }

  void _drawSelectionBox(Canvas canvas, Rect bounds) {
    final inflated = bounds.inflate(6.0 / zoomScale);
    final rrect = RRect.fromRectAndRadius(inflated, const Radius.circular(8.0));

    // Halo Glow de Seleção Ciano
    final glowPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withOpacity(0.25)
      ..strokeWidth = 3.0 / zoomScale
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect, glowPaint);

    // Borda Neon Principal
    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.6 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // Alças de Canto (Handles)
    final handlePaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2 / zoomScale
      ..style = PaintingStyle.stroke;

    final corners = [
      inflated.topLeft,
      inflated.topRight,
      inflated.bottomLeft,
      inflated.bottomRight,
    ];

    final handleRadius = 4.5 / zoomScale;
    for (final corner in corners) {
      canvas.drawCircle(corner, handleRadius, handlePaint);
      canvas.drawCircle(corner, handleRadius, handleBorder);
    }
  }

  static void _drawStrokeDirectFast(Canvas canvas, InkStroke stroke, Paint reusablePaint) {
    if (stroke.points.isEmpty) return;

    final bool hasTransform = stroke.transform != Offset.zero;
    if (hasTransform) {
      canvas.save();
      canvas.translate(stroke.transform.dx, stroke.transform.dy);
    }

    try {
      final color = stroke.toolType == InkToolType.highlighter
          ? stroke.color.withOpacity(0.35)
          : (stroke.toolType == InkToolType.pencil ? stroke.color.withOpacity(0.65) : stroke.color);

      reusablePaint
        ..color = color
        ..strokeWidth = stroke.strokeWidth * (stroke.toolType == InkToolType.highlighter ? 3.5 : 1.0)
        ..strokeCap = stroke.toolType == InkToolType.highlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = stroke.toolType == InkToolType.highlighter ? StrokeJoin.bevel : StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.toolType == InkToolType.technical && !stroke.enablePressure && stroke.points.length > 50) {
        final rawPoints = Float32List(stroke.points.length * 2);
        for (int i = 0; i < stroke.points.length; i++) {
          rawPoints[i * 2] = stroke.points[i].point.dx;
          rawPoints[i * 2 + 1] = stroke.points[i].point.dy;
        }
        canvas.drawRawPoints(ui.PointMode.polygon, rawPoints, reusablePaint);
      } else {
        final path = stroke.cachedPath ?? InkStroke.buildCatmullRomPath(stroke.points);
        canvas.drawPath(path, reusablePaint);
      }
    } finally {
      if (hasTransform) {
        canvas.restore();
      }
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final double dashWidth = 6.0 / zoomScale;
    final double dashSpace = 4.0 / zoomScale;
    final double step = dashWidth + dashSpace;

    // Otimização: Se houverem muitos dashes (excesso de drawPath calls), cai para linha sólida
    for (final metric in path.computeMetrics()) {
      if (metric.length / step > 300) {
        canvas.drawPath(path, paint);
        continue;
      }
      
      double distance = 0.0;
      while (distance < metric.length) {
        final double nextDistance = math.min(distance + dashWidth, metric.length);
        final extractPath = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extractPath, paint);
        distance += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) {
    return true; // Controlado pelo RepaintBoundary e notifiers
  }
}
