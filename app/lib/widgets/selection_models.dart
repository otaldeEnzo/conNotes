import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ink_models.dart';

/// Tipos de Seleção suportados no Canvas
enum SelectionType {
  rectangle, // Caixa delimitadora retangular padrão
  lasso,     // Laço contínuo de formato livre (estilo Samsung Notes / OneNote)
}

/// Estado imutável ou reativo da Seleção no Canvas
class SelectionState {
  final SelectionType type;
  final bool isSelectingArea;      // Usuário está ativamente arrastando para selecionar (caixa ou laço)
  final bool isDraggingSelection;  // Usuário está arrastando os traços já selecionados para movê-los
  final Offset? startPoint;
  final Offset? currentPoint;
  final List<Offset> lassoPoints;
  final Set<String> selectedStrokeIds;
  final Rect? bounds;
  final Offset dragOffset;         // Deslocamento temporário dos traços durante o arraste

  const SelectionState({
    this.type = SelectionType.rectangle,
    this.isSelectingArea = false,
    this.isDraggingSelection = false,
    this.startPoint,
    this.currentPoint,
    this.lassoPoints = const [],
    this.selectedStrokeIds = const {},
    this.bounds,
    this.dragOffset = Offset.zero,
  });

  bool get hasSelection => selectedStrokeIds.isNotEmpty && bounds != null;

  SelectionState copyWith({
    SelectionType? type,
    bool? isSelectingArea,
    bool? isDraggingSelection,
    Offset? startPoint,
    Offset? currentPoint,
    List<Offset>? lassoPoints,
    Set<String>? selectedStrokeIds,
    Rect? bounds,
    Offset? dragOffset,
  }) {
    return SelectionState(
      type: type ?? this.type,
      isSelectingArea: isSelectingArea ?? this.isSelectingArea,
      isDraggingSelection: isDraggingSelection ?? this.isDraggingSelection,
      startPoint: startPoint ?? this.startPoint,
      currentPoint: currentPoint ?? this.currentPoint,
      lassoPoints: lassoPoints ?? this.lassoPoints,
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      bounds: bounds ?? this.bounds,
      dragOffset: dragOffset ?? this.dragOffset,
    );
  }

  static SelectionState empty() => const SelectionState();
}

/// Algoritmos de geometria computacional para detecção de seleção
class SelectionGeometry {
  /// Verifica se um clique simples (tap) atingiu um traço específico
  static bool isPointNearStroke(Offset point, InkStroke stroke, double tolerance) {
    // 1. Fast check de Bounding Box inflada (que já inclui o transform)
    final strokeBounds = stroke.boundingBox ?? computeStrokeBounds(stroke);
    if (!strokeBounds.inflate(tolerance + stroke.strokeWidth).contains(point)) {
      return false;
    }

    // 2. Verificação de distância ponto-a-segmento precisa no espaço local (sem transform)
    final localPoint = point - stroke.transform;
    final points = stroke.points;
    if (points.isEmpty) return false;
    if (points.length == 1) {
      return (points.first.point - localPoint).distance <= (tolerance + stroke.strokeWidth / 2);
    }

    final maxDist = tolerance + stroke.strokeWidth / 2;
    final maxDistSq = maxDist * maxDist;
    final px = localPoint.dx;
    final py = localPoint.dy;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i].point;
      final p2 = points[i + 1].point;

      // Early rejection rápido por AABB do segmento antes do dot product
      final minX = (p1.dx < p2.dx ? p1.dx : p2.dx) - maxDist;
      if (px < minX) continue;
      final maxX = (p1.dx > p2.dx ? p1.dx : p2.dx) + maxDist;
      if (px > maxX) continue;
      final minY = (p1.dy < p2.dy ? p1.dy : p2.dy) - maxDist;
      if (py < minY) continue;
      final maxY = (p1.dy > p2.dy ? p1.dy : p2.dy) + maxDist;
      if (py > maxY) continue;

      if (_distanceSqToSegment(localPoint, p1, p2) <= maxDistSq) {
        return true;
      }
    }

    return false;
  }

  /// Verifica se um traço intersecta ou está contido no retângulo de seleção
  static bool isStrokeInRect(InkStroke stroke, Rect rect) {
    final strokeBounds = stroke.boundingBox ?? computeStrokeBounds(stroke);
    // Se a bounding box nem se sobrepõe, descarta instantaneamente
    if (!rect.overlaps(strokeBounds)) {
      return false;
    }

    // Passar o retângulo para o espaço local do traço
    final localRect = rect.shift(-stroke.transform);

    // Se qualquer ponto do traço está contido no retângulo
    for (final p in stroke.points) {
      if (localRect.contains(p.point)) return true;
    }

    return false;
  }

  /// Verifica se um traço está dentro do polígono do laço (Lasso) via Ray Casting
  static bool isStrokeInLasso(InkStroke stroke, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    final strokeBounds = stroke.boundingBox ?? computeStrokeBounds(stroke);
    final polyBounds = computePolygonBounds(polygon);

    if (!polyBounds.overlaps(strokeBounds)) {
      return false;
    }

    // Teste 1: Se o centróide do traço está dentro (em world space)
    final center = strokeBounds.center;
    if (isPointInPolygon(center, polygon)) return true;

    // Teste 2: Se pelo menos um ponto do traço está dentro (convertendo local -> world)
    for (final p in stroke.points) {
      if (isPointInPolygon(p.point + stroke.transform, polygon)) return true;
    }

    return false;
  }

  /// Algoritmo Ray Casting (Point-in-Polygon) O(V)
  static bool isPointInPolygon(Offset p, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy + 0.000001) + pi.dx);

      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Calcula a Bounding Box combinada de uma lista de traços
  static Rect? computeCombinedBounds(Iterable<InkStroke> strokes) {
    if (strokes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      final bounds = stroke.boundingBox ?? computeStrokeBounds(stroke);
      if (bounds.left < minX) minX = bounds.left;
      if (bounds.top < minY) minY = bounds.top;
      if (bounds.right > maxX) maxX = bounds.right;
      if (bounds.bottom > maxY) maxY = bounds.bottom;
    }

    if (minX.isInfinite) return null;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Rect computeStrokeBounds(InkStroke stroke) {
    if (stroke.points.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final p in stroke.points) {
      if (p.point.dx < minX) minX = p.point.dx;
      if (p.point.dy < minY) minY = p.point.dy;
      if (p.point.dx > maxX) maxX = p.point.dx;
      if (p.point.dy > maxY) maxY = p.point.dy;
    }

    final pad = stroke.strokeWidth * 1.5;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad).shift(stroke.transform);
  }

  static Rect computePointsBounds(List<StrokePoint> points, double strokeWidth) {
    if (points.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final p in points) {
      if (p.point.dx < minX) minX = p.point.dx;
      if (p.point.dy < minY) minY = p.point.dy;
      if (p.point.dx > maxX) maxX = p.point.dx;
      if (p.point.dy > maxY) maxY = p.point.dy;
    }

    final pad = strokeWidth * 1.5;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  static Rect computePolygonBounds(List<Offset> polygon) {
    if (polygon.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _distanceSqToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distanceSquared;
    final t = math.max(0, math.min(1, ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2));
    final projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distanceSquared;
  }
}
