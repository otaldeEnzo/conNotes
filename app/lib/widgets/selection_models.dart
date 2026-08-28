import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ink_models.dart';

/// Tipos de Seleção suportados no Canvas
enum SelectionType {
  rectangle, // Caixa delimitadora retangular padrão
  lasso,     // Laço contínuo de formato livre (estilo Samsung Notes / OneNote)
}

/// Manipuladores de Transformação (8 Alças de Redimensionamento + Alça Superior de Rotação)
enum SelectionHandleType {
  none,
  topLeft,
  topCenter,
  topRight,
  centerRight,
  bottomRight,
  bottomCenter,
  bottomLeft,
  centerLeft,
  rotation,
}

/// Estado imutável ou reativo da Seleção no Canvas
class SelectionState {
  final SelectionType type;
  final bool isSelectingArea;      // Usuário está ativamente arrastando para selecionar (caixa ou laço)
  final bool isDraggingSelection;  // Usuário está arrastando os traços já selecionados para movê-los
  final SelectionHandleType activeHandle; // Manipulador ativo sendo transformado
  final Offset? startPoint;
  final Offset? currentPoint;
  final List<Offset> lassoPoints;
  final Set<String> selectedStrokeIds;
  final Set<String> selectedCardIds;
  final Rect? bounds;
  final Offset dragOffset;         // Deslocamento temporário dos traços durante o arraste
  final double rotationAngle;      // Rotação acumulada em radianos
  final double scaleX;             // Escala acumulada no eixo X
  final double scaleY;             // Escala acumulada no eixo Y
  final Offset? transformPivot;    // Centro/âncora da transformação
  final Rect? transformBounds;   // Caixa delimitadora redimensionada em tempo real pelas alças

  const SelectionState({
    this.type = SelectionType.rectangle,
    this.isSelectingArea = false,
    this.isDraggingSelection = false,
    this.activeHandle = SelectionHandleType.none,
    this.startPoint,
    this.currentPoint,
    this.lassoPoints = const [],
    this.selectedStrokeIds = const {},
    this.selectedCardIds = const {},
    this.bounds,
    this.dragOffset = Offset.zero,
    this.rotationAngle = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.transformPivot,
    this.transformBounds,
  });

  bool get hasSelection => (selectedStrokeIds.isNotEmpty || selectedCardIds.isNotEmpty) && bounds != null;
  bool get isTransforming => activeHandle != SelectionHandleType.none;

  SelectionState copyWith({
    SelectionType? type,
    bool? isSelectingArea,
    bool? isDraggingSelection,
    SelectionHandleType? activeHandle,
    Offset? startPoint,
    Offset? currentPoint,
    List<Offset>? lassoPoints,
    Set<String>? selectedStrokeIds,
    Set<String>? selectedCardIds,
    Rect? bounds,
    Offset? dragOffset,
    double? rotationAngle,
    double? scaleX,
    double? scaleY,
    Offset? transformPivot,
    Rect? transformBounds,
    bool clearTransformBounds = false,
    bool clearTransformPivot = false,
    bool clearPoints = false,
  }) {
    return SelectionState(
      type: type ?? this.type,
      isSelectingArea: isSelectingArea ?? this.isSelectingArea,
      isDraggingSelection: isDraggingSelection ?? this.isDraggingSelection,
      activeHandle: activeHandle ?? this.activeHandle,
      startPoint: clearPoints ? null : (startPoint ?? this.startPoint),
      currentPoint: clearPoints ? null : (currentPoint ?? this.currentPoint),
      lassoPoints: lassoPoints ?? this.lassoPoints,
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      selectedCardIds: selectedCardIds ?? this.selectedCardIds,
      bounds: bounds ?? this.bounds,
      dragOffset: dragOffset ?? this.dragOffset,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      transformPivot: clearTransformPivot ? null : (transformPivot ?? this.transformPivot),
      transformBounds: clearTransformBounds ? null : (transformBounds ?? this.transformBounds),
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

  /// Calcula as posições dos 8 manipuladores de redimensionamento e rotação
  static Map<SelectionHandleType, Offset> getHandlePositions(Rect bounds, double zoomScale, {double rotation = 0.0, Offset? pivot}) {
    final center = pivot ?? bounds.center;
    final inflated = bounds.inflate(6.0 / zoomScale);

    Offset rotatePoint(Offset p) {
      if (rotation == 0.0) return p;
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      final cosA = math.cos(rotation);
      final sinA = math.sin(rotation);
      return Offset(center.dx + dx * cosA - dy * sinA, center.dy + dx * sinA + dy * cosA);
    }

    return {
      SelectionHandleType.topLeft: rotatePoint(inflated.topLeft),
      SelectionHandleType.topCenter: rotatePoint(Offset(inflated.center.dx, inflated.top)),
      SelectionHandleType.topRight: rotatePoint(inflated.topRight),
      SelectionHandleType.centerLeft: rotatePoint(Offset(inflated.left, inflated.center.dy)),
      SelectionHandleType.centerRight: rotatePoint(Offset(inflated.right, inflated.center.dy)),
      SelectionHandleType.bottomLeft: rotatePoint(inflated.bottomLeft),
      SelectionHandleType.bottomCenter: rotatePoint(Offset(inflated.center.dx, inflated.bottom)),
      SelectionHandleType.bottomRight: rotatePoint(inflated.bottomRight),
    };
  }

  /// Detecta se o ponto clicado atingiu um dos manipuladores da seleção
  static SelectionHandleType getHandleAtPoint(Offset point, Rect bounds, double zoomScale, {double rotation = 0.0, Offset? pivot}) {
    final handles = getHandlePositions(bounds, zoomScale, rotation: rotation, pivot: pivot);
    final hitTolerance = 18.0 / zoomScale;
    final hitToleranceSq = hitTolerance * hitTolerance;

    for (final entry in handles.entries) {
      if ((point - entry.value).distanceSquared <= hitToleranceSq) {
        return entry.key;
      }
    }
    return SelectionHandleType.none;
  }

  /// Trava magnética em ângulos notáveis (0°, 45°, 90°, 135°, 180°, etc.)
  static double snapAngle(double angleRadians) {
    double degrees = (angleRadians * 180.0 / math.pi) % 360.0;
    if (degrees < 0) degrees += 360.0;
    const notable = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 360.0];
    for (final n in notable) {
      if ((degrees - n).abs() <= 3.5 || (degrees - 360.0 - n).abs() <= 3.5) {
        return (n % 360.0) * math.pi / 180.0;
      }
    }
    return angleRadians;
  }
}
