import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Tipos Especializados de Ferramenta de Escrita (Padrão OneNote / Samsung Notes)
enum InkToolType {
  technical,   // Caneta Técnica / Esferográfica (com ou sem pressão)
  fountain,    // Caneta Tinteiro / Caligráfica (ponta chanfrada)
  pencil,      // Lápis Grafite (textura e opacidade leve)
  highlighter, // Marca-Texto (translúcido, não encobre o texto)
}

/// Modos de Funcionamento da Borracha
enum EraserMode {
  stroke,    // Borracha de Objeto (remove o traço inteiro em O(1))
  precision, // Borracha de Precisão (corta e divide o traço no ponto de contato)
}

/// Configuração da Borracha Ativa
class EraserConfig {
  final EraserMode mode;
  final double radius;
  final bool eraseHighlighterOnly;

  const EraserConfig({
    this.mode = EraserMode.stroke,
    this.radius = 24.0,
    this.eraseHighlighterOnly = false,
  });

  EraserConfig copyWith({
    EraserMode? mode,
    double? radius,
    bool? eraseHighlighterOnly,
  }) {
    return EraserConfig(
      mode: mode ?? this.mode,
      radius: radius ?? this.radius,
      eraseHighlighterOnly: eraseHighlighterOnly ?? this.eraseHighlighterOnly,
    );
  }
}

/// Ponto individual de um traço com pressão e timestamp
class StrokePoint {
  final Offset point;
  final double pressure;
  final double tilt;

  StrokePoint({
    required this.point,
    this.pressure = 1.0,
    this.tilt = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': point.dx,
      'y': point.dy,
      'p': pressure,
      'tilt': tilt,
    };
  }

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      point: Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
      pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
      tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Modelo de Dados do Traço desenhado
class InkStroke {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final InkToolType toolType;
  final bool enablePressure;
  final Offset transform; // Usado para Flyweight pattern (compartilha a geometria realocando apenas a posição visual)
  Rect? boundingBox; // Para Viewport Culling (BoundingBox final JÁ INCLUI o transform)
  Path? cachedPath; // Caminho pré-calculado (no espaço local, SEM transform) para renderização instantânea durante Pan/Zoom
  Float32List? cachedRawPoints; // Geometria compacta para drawRawPoints sem alocação no paint

  InkStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.toolType = InkToolType.technical,
    this.enablePressure = false,
    this.transform = Offset.zero,
    this.boundingBox,
    this.cachedPath,
    this.cachedRawPoints,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'strokeWidth': strokeWidth,
      'toolType': toolType.name,
      'enablePressure': enablePressure,
      'transform': {'x': transform.dx, 'y': transform.dy},
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    Color parseHex(String? hex) {
      if (hex == null) return Colors.white;
      try {
        final clean = hex.replaceAll('#', '').replaceAll('0x', '');
        if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
        if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      } catch (_) {}
      return Colors.white;
    }

    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final List<StrokePoint> pts = rawPoints
        .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
        .toList();

    Offset trans = Offset.zero;
    if (json['transform'] != null) {
      final t = json['transform'] as Map<String, dynamic>;
      trans = Offset((t['x'] as num?)?.toDouble() ?? 0.0, (t['y'] as num?)?.toDouble() ?? 0.0);
    }

    final toolName = json['toolType'] as String? ?? 'technical';
    final tool = InkToolType.values.firstWhere(
      (e) => e.name == toolName,
      orElse: () => InkToolType.technical,
    );

    return InkStroke(
      id: json['id'] as String? ?? 'stroke_${DateTime.now().microsecondsSinceEpoch}',
      points: pts,
      color: parseHex(json['color'] as String?),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      toolType: tool,
      enablePressure: json['enablePressure'] as bool? ?? false,
      transform: trans,
    );
  }

  /// Retorna uma representação compacta e reutilizável dos pontos para Skia.
  Float32List get rawPoints {
    return cachedRawPoints ??= Float32List.fromList([
      for (final point in points) ...[point.point.dx, point.point.dy],
    ]);
  }

  /// Constrói um caminho matematicamente suavizado através dos pontos usando Catmull-Rom Spline
  static Path buildCatmullRomPath(List<StrokePoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points[0].point, radius: 0.1));
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points[0].point.dx, points[0].point.dy);
      path.lineTo(points[1].point.dx, points[1].point.dy);
      return path;
    }

    path.moveTo(points[0].point.dx, points[0].point.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1].point : points[i].point;
      final p1 = points[i].point;
      final p2 = points[i + 1].point;
      final p3 = i < points.length - 2 ? points[i + 2].point : p2;

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6.0, p1.dy + (p2.dy - p0.dy) / 6.0);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6.0, p2.dy - (p3.dy - p1.dy) / 6.0);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// Aplica o algoritmo Ramer-Douglas-Peucker para simplificar o traço
  static List<StrokePoint> simplifyRDP(List<StrokePoint> points, double tolerance) {
    if (points.length <= 2) return points;

    double maxDistance = 0;
    int index = 0;
    final int last = points.length - 1;

    for (int i = 1; i < last; i++) {
      final double distance = _perpendicularDistance(points[i].point, points[0].point, points[last].point);
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance > tolerance) {
      final List<StrokePoint> left = simplifyRDP(points.sublist(0, index + 1), tolerance);
      final List<StrokePoint> right = simplifyRDP(points.sublist(index, last + 1), tolerance);
      
      right.removeAt(0); // Evitar duplicação do ponto conector
      return [...left, ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final double dx = lineEnd.dx - lineStart.dx;
    final double dy = lineEnd.dy - lineStart.dy;

    if (dx == 0 && dy == 0) {
      return (point - lineStart).distance;
    }

    final double t = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / (dx * dx + dy * dy);

    if (t < 0) {
      return (point - lineStart).distance;
    } else if (t > 1) {
      return (point - lineEnd).distance;
    }

    final Offset projection = Offset(lineStart.dx + t * dx, lineStart.dy + t * dy);
    return (point - projection).distance;
  }
}

/// Modelo de Preset de Caneta para os Slots da Sub-Barra
class PenSlotPreset {
  final String id;
  final String name;
  final Color color;
  final double strokeWidth;
  final InkToolType toolType;
  final bool enablePressure;

  const PenSlotPreset({
    required this.id,
    required this.name,
    required this.color,
    required this.strokeWidth,
    this.toolType = InkToolType.technical,
    this.enablePressure = false,
  });

  PenSlotPreset copyWith({
    String? name,
    Color? color,
    double? strokeWidth,
    InkToolType? toolType,
    bool? enablePressure,
  }) {
    return PenSlotPreset(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      toolType: toolType ?? this.toolType,
      enablePressure: enablePressure ?? this.enablePressure,
    );
  }
}
