import 'package:flutter/material.dart';

/// Ponto individual de um traço vetorial (Stylus/Mouse)
class StrokePoint {
  final Offset point;
  final double pressure;

  StrokePoint({
    required this.point,
    this.pressure = 1.0,
  });
}

/// Um traço de escrita manual ou desenho no Canvas Infinito
class InkStroke {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;

  InkStroke({
    required this.id,
    required this.points,
    this.color = Colors.white,
    this.strokeWidth = 3.0,
  });
}
