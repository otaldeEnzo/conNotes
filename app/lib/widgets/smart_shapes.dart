import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ink_models.dart';

/// Categorias de Formas Geométricas
enum ShapeCategory {
  lines,     // Linhas & Vetores
  circles,   // Círculos & Elipses
  triangles, // Triângulos
  polygons,  // Polígonos
}

/// Tipos de Formas Geométricas
enum ShapeType {
  line,
  arrow,
  doubleArrow,
  circle,
  ellipse,
  triangle,
  triangleRight,
  rectangle,
  diamond,
  hexagon,
}

/// Motor de Reconhecimento e Geração Geométrica Exata (Smart Shapes)
class SmartShapeEngine {
  /// Gera o Path geométrico exato (com retas puras, arcos suaves e cantos nítidos)
  static Path generateShapePath(ShapeType type, Offset start, Offset end) {
    final path = Path();

    switch (type) {
      case ShapeType.line:
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
        break;

      case ShapeType.arrow:
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);

        final dist = (end - start).distance;
        if (dist > 2.0) {
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final arrowHeadLength = math.min(22.0, math.max(10.0, dist * 0.30));
          final wing1 = end - Offset(math.cos(angle - 0.45) * arrowHeadLength, math.sin(angle - 0.45) * arrowHeadLength);
          final wing2 = end - Offset(math.cos(angle + 0.45) * arrowHeadLength, math.sin(angle + 0.45) * arrowHeadLength);

          path.moveTo(wing1.dx, wing1.dy);
          path.lineTo(end.dx, end.dy);
          path.lineTo(wing2.dx, wing2.dy);
        }
        break;

      case ShapeType.doubleArrow:
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);

        final dist = (end - start).distance;
        if (dist > 4.0) {
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final arrowHeadLength = math.min(20.0, math.max(8.0, dist * 0.25));

          // Ponta em end
          final wing1 = end - Offset(math.cos(angle - 0.45) * arrowHeadLength, math.sin(angle - 0.45) * arrowHeadLength);
          final wing2 = end - Offset(math.cos(angle + 0.45) * arrowHeadLength, math.sin(angle + 0.45) * arrowHeadLength);
          path.moveTo(wing1.dx, wing1.dy);
          path.lineTo(end.dx, end.dy);
          path.lineTo(wing2.dx, wing2.dy);

          // Ponta em start
          final wing3 = start + Offset(math.cos(angle - 0.45) * arrowHeadLength, math.sin(angle - 0.45) * arrowHeadLength);
          final wing4 = start + Offset(math.cos(angle + 0.45) * arrowHeadLength, math.sin(angle + 0.45) * arrowHeadLength);
          path.moveTo(wing3.dx, wing3.dy);
          path.lineTo(start.dx, start.dy);
          path.lineTo(wing4.dx, wing4.dy);
        }
        break;

      case ShapeType.circle:
        final center = (start + end) / 2.0;
        final radius = (end - start).distance / 2.0;
        path.addOval(Rect.fromCircle(center: center, radius: math.max(1.0, radius)));
        break;

      case ShapeType.ellipse:
        final rect = Rect.fromPoints(start, end);
        path.addOval(rect);
        break;

      case ShapeType.triangle:
        final rect = Rect.fromPoints(start, end);
        final apexY = start.dy;
        final baseY = end.dy;
        path.moveTo(rect.center.dx, apexY);
        path.lineTo(rect.right, baseY);
        path.lineTo(rect.left, baseY);
        path.close();
        break;

      case ShapeType.triangleRight:
        path.moveTo(start.dx, start.dy);
        path.lineTo(start.dx, end.dy);
        path.lineTo(end.dx, end.dy);
        path.close();
        break;

      case ShapeType.rectangle:
        path.addRect(Rect.fromPoints(start, end));
        break;

      case ShapeType.diamond:
        final rect = Rect.fromPoints(start, end);
        path.moveTo(rect.center.dx, rect.top);
        path.lineTo(rect.right, rect.center.dy);
        path.lineTo(rect.center.dx, rect.bottom);
        path.lineTo(rect.left, rect.center.dy);
        path.close();
        break;

      case ShapeType.hexagon:
        final center = (start + end) / 2.0;
        final radius = (end - start).distance / 2.0;
        for (int i = 0; i < 6; i++) {
          final theta = (i / 6.0) * 2.0 * math.pi - (math.pi / 6.0);
          final pt = Offset(center.dx + radius * math.cos(theta), center.dy + radius * math.sin(theta));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        break;
    }

    return path;
  }

  /// Gera os pontos vetoriais discretos para uma forma geométrica
  static List<StrokePoint> samplePathPoints(Path path, {double spacing = 5.0, double pressure = 1.0}) {
    final points = <StrokePoint>[];
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) continue;
      double dist = 0.0;
      while (dist <= length) {
        final tangent = metric.getTangentForOffset(dist);
        if (tangent != null) {
          points.add(StrokePoint(point: tangent.position, pressure: pressure));
        }
        dist += spacing;
      }
      final lastTangent = metric.getTangentForOffset(length);
      if (lastTangent != null && (points.isEmpty || points.last.point != lastTangent.position)) {
        points.add(StrokePoint(point: lastTangent.position, pressure: pressure));
      }
    }
    return points;
  }

  /// Gera o Path perfeito para uma forma reconhecida a partir do traço livre e de sua orientação original
  static Path generateRecognizedPath(ShapeType type, List<StrokePoint> strokePoints, Rect bounds) {
    if (strokePoints.isEmpty) {
      return generateShapePath(type, bounds.topLeft, bounds.bottomRight);
    }

    if (type == ShapeType.line || type == ShapeType.arrow || type == ShapeType.doubleArrow) {
      return generateShapePath(type, strokePoints.first.point, strokePoints.last.point);
    }

    final rawOffsets = strokePoints.map((p) => p.point).toList();
    final cornerIndices = _detectCornerIndices(rawOffsets);

    if (type == ShapeType.triangleRight) {
      // Localiza o vértice do ângulo reto (90 graus)
      Offset rightAngleVertex = bounds.bottomLeft;
      if (cornerIndices.length == 3) {
        final c0 = rawOffsets[cornerIndices[0]];
        final c1 = rawOffsets[cornerIndices[1]];
        final c2 = rawOffsets[cornerIndices[2]];

        if (_isRightAngle(c0, c1, c2)) {
          rightAngleVertex = c1;
        } else if (_isRightAngle(c1, c2, c0)) {
          rightAngleVertex = c2;
        } else if (_isRightAngle(c2, c0, c1)) {
          rightAngleVertex = c0;
        } else {
          // Escolhe o vértice mais próximo de um dos 4 cantos do bounds
          final corners = [bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight];
          double minDist = double.infinity;
          for (final c in [c0, c1, c2]) {
            for (final corner in corners) {
              final d = (c - corner).distance;
              if (d < minDist) {
                minDist = d;
                rightAngleVertex = corner;
              }
            }
          }
        }
      }

      // Constrói start e end baseados no quadrante do ângulo reto
      if (rightAngleVertex.dx >= bounds.center.dx && rightAngleVertex.dy >= bounds.center.dy) {
        // Ângulo reto no canto inferior direito -> hipotenusa apontando para a esquerda
        return generateShapePath(type, bounds.topRight, bounds.bottomLeft);
      } else if (rightAngleVertex.dx < bounds.center.dx && rightAngleVertex.dy < bounds.center.dy) {
        // Ângulo reto no canto superior esquerdo
        return generateShapePath(type, bounds.bottomLeft, bounds.topRight);
      } else if (rightAngleVertex.dx >= bounds.center.dx && rightAngleVertex.dy < bounds.center.dy) {
        // Ângulo reto no canto superior direito
        return generateShapePath(type, bounds.bottomRight, bounds.topLeft);
      } else {
        // Ângulo reto no canto inferior esquerdo (padrão) -> hipotenusa apontando para a direita
        return generateShapePath(type, bounds.topLeft, bounds.bottomRight);
      }
    }

    if (type == ShapeType.triangle) {
      // Determina se o ápice do triângulo aponta para cima ou para baixo
      bool pointsUp = true;
      if (cornerIndices.length == 3) {
        final c = cornerIndices.map((i) => rawOffsets[i]).toList();
        final minY = c.map((p) => p.dy).reduce(math.min);
        final maxY = c.map((p) => p.dy).reduce(math.max);
        final topCornersCount = c.where((p) => (p.dy - minY).abs() < (maxY - minY) * 0.35).length;
        if (topCornersCount >= 2) {
          pointsUp = false; // 2 cantos no topo e 1 na base -> aponta para baixo
        }
      }

      if (pointsUp) {
        return generateShapePath(type, bounds.topLeft, bounds.bottomRight);
      } else {
        return generateShapePath(type, bounds.bottomLeft, bounds.topRight);
      }
    }

    return generateShapePath(type, bounds.topLeft, bounds.bottomRight);
  }

  /// Gera os pontos para qualquer forma geométrica
  static List<StrokePoint> generateShapePoints(
    ShapeType type,
    Offset start,
    Offset end, {
    double pressure = 1.0,
  }) {
    final path = generateShapePath(type, start, end);
    return samplePathPoints(path, pressure: pressure);
  }

  /// Reconhece automaticamente com alta precisão se um traço corresponde a uma forma geométrica
  static ShapeType? recognizeDrawnShape(List<StrokePoint> strokePoints) {
    if (strokePoints.length < 8) return null;

    final first = strokePoints.first.point;
    final last = strokePoints.last.point;

    // 1. Calcula o comprimento percorrido e bounding box
    double pathLength = 0.0;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (int i = 0; i < strokePoints.length - 1; i++) {
      final p0 = strokePoints[i].point;
      final p1 = strokePoints[i + 1].point;
      pathLength += (p1 - p0).distance;

      if (p0.dx < minX) minX = p0.dx;
      if (p0.dy < minY) minY = p0.dy;
      if (p0.dx > maxX) maxX = p0.dx;
      if (p0.dy > maxY) maxY = p0.dy;
    }

    if (pathLength < 16.0) return null;

    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    final directDist = (last - first).distance;
    final isClosed = directDist < pathLength * 0.32;

    // 2. Traço Aberto: Linha Reta vs Seta vs Seta Dupla
    if (!isClosed) {
      final directRatio = directDist / pathLength;

      if (strokePoints.length > 12) {
        final endShaftIdx = (strokePoints.length * 0.70).round();
        final endShaft = strokePoints[endShaftIdx].point;
        final shaftVec = endShaft - first;
        final endHeadVec = last - endShaft;

        final isEndArrow = shaftVec.distance > 8.0 &&
            endHeadVec.distance > 4.0 &&
            (shaftVec.dx * endHeadVec.dx + shaftVec.dy * endHeadVec.dy) / (shaftVec.distance * endHeadVec.distance) < -0.20;

        if (isEndArrow) {
          final startShaftIdx = (strokePoints.length * 0.30).round();
          final startShaft = strokePoints[startShaftIdx].point;
          final startHeadVec = first - startShaft;
          final isStartArrow = startHeadVec.distance > 4.0 &&
              (shaftVec.dx * startHeadVec.dx + shaftVec.dy * startHeadVec.dy) / (shaftVec.distance * startHeadVec.distance) > 0.20;

          if (isStartArrow) {
            return ShapeType.doubleArrow;
          }
          return ShapeType.arrow;
        }
      }

      if (directRatio > 0.75) {
        return ShapeType.line;
      }
      return null;
    }

    // 3. Traço Fechado: Classificação por Detecção de Cantos Vivos (Corner Curvature Peaks)
    final rawOffsets = strokePoints.map((p) => p.point).toList();
    final cornerIndices = _detectCornerIndices(rawOffsets);
    final cornerCount = cornerIndices.length;

    // 3.1 Zero ou 1 canto -> Círculo ou Elipse Suave
    if (cornerCount <= 1) {
      final ratio = bounds.width / (bounds.height + 0.001);
      if (ratio >= 0.80 && ratio <= 1.25) {
        return ShapeType.circle;
      }
      return ShapeType.ellipse;
    }

    // 3.2 Exatamente 3 cantos -> Triângulo
    if (cornerCount == 3) {
      final c0 = rawOffsets[cornerIndices[0]];
      final c1 = rawOffsets[cornerIndices[1]];
      final c2 = rawOffsets[cornerIndices[2]];

      if (_isRightAngle(c0, c1, c2) || _isRightAngle(c1, c2, c0) || _isRightAngle(c2, c0, c1)) {
        return ShapeType.triangleRight;
      }
      return ShapeType.triangle;
    }

    // 3.3 Exatamente 4 cantos -> Retângulo, Quadrado ou Losango
    if (cornerCount == 4) {
      final c = cornerIndices.map((idx) => rawOffsets[idx]).toList();
      final center = (c[0] + c[1] + c[2] + c[3]) / 4.0;
      final topMost = c.reduce((a, b) => a.dy < b.dy ? a : b);
      final bottomMost = c.reduce((a, b) => a.dy > b.dy ? a : b);

      if ((topMost.dx - center.dx).abs() < bounds.width * 0.16 &&
          (bottomMost.dx - center.dx).abs() < bounds.width * 0.16) {
        return ShapeType.diamond;
      }
      return ShapeType.rectangle;
    }

    // 3.4 5 ou 6 cantos -> Hexágono ou Retângulo
    if (cornerCount == 6) {
      return ShapeType.hexagon;
    }

    if (cornerCount == 5) {
      return ShapeType.rectangle;
    }

    // 3.5 Mais de 6 cantos ou contorno irregular -> Testa circularidade
    final area = bounds.width * bounds.height * 0.785;
    final circularity = (4.0 * math.pi * area) / (pathLength * pathLength);
    if (circularity > 0.65) {
      final ratio = bounds.width / (bounds.height + 0.001);
      if (ratio >= 0.80 && ratio <= 1.25) {
        return ShapeType.circle;
      }
      return ShapeType.ellipse;
    }

    return ShapeType.rectangle;
  }

  /// Detecta os índices dos cantos vivos (sharp corners) ao longo do contorno fechado
  static List<int> _detectCornerIndices(List<Offset> pts) {
    if (pts.length < 10) return [];

    final int n = pts.length;
    final int window = math.max(2, (n / 16).round());
    final List<double> turnAngles = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final prevIdx = (i - window + n) % n;
      final nextIdx = (i + window) % n;

      final v1 = pts[i] - pts[prevIdx];
      final v2 = pts[nextIdx] - pts[i];
      final d1 = v1.distance;
      final d2 = v2.distance;

      if (d1 > 1.0 && d2 > 1.0) {
        final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (d1 * d2);
        final clampedDot = dot.clamp(-1.0, 1.0);
        turnAngles[i] = math.acos(clampedDot);
      }
    }

    const minCornerAngle = 0.85; // ~48.7 graus de deflexão angular (evita falsos cantos em traços ondulados)
    final minDistanceBetweenCorners = n / 8.0;
    final List<int> cornerIndices = [];

    for (int i = 0; i < n; i++) {
      final angle = turnAngles[i];
      if (angle < minCornerAngle) continue;

      bool isPeak = true;
      for (int w = 1; w <= window; w++) {
        final pIdx = (i - w + n) % n;
        final nIdx = (i + w) % n;
        if (turnAngles[pIdx] > angle || turnAngles[nIdx] > angle) {
          isPeak = false;
          break;
        }
      }

      if (isPeak) {
        bool tooClose = false;
        for (final existing in cornerIndices) {
          final diff = (i - existing).abs();
          final cyclicDiff = math.min(diff, n - diff);
          if (cyclicDiff < minDistanceBetweenCorners) {
            tooClose = true;
            break;
          }
        }
        if (!tooClose) {
          cornerIndices.add(i);
        }
      }
    }

    return cornerIndices;
  }

  /// Verifica se o ângulo no vértice B entre (A-B) e (C-B) é aproximadamente 90° (70° a 110°)
  static bool _isRightAngle(Offset a, Offset b, Offset c) {
    final v1 = a - b;
    final v2 = c - b;
    final d1 = v1.distance;
    final d2 = v2.distance;
    if (d1 < 2.0 || d2 < 2.0) return false;

    final cosTheta = (v1.dx * v2.dx + v1.dy * v2.dy) / (d1 * d2);
    return cosTheta.abs() <= 0.35;
  }
}
