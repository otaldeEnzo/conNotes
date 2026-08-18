import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tipo de instrumento de medição STEM ativo
enum MeasurementToolType {
  ruler,
  protractor,
}

/// Estado e geometria da Régua STEM Interativa.
class StemRulerState {
  final Offset center; // Posição do centro da régua em coordenadas do Canvas
  final double angle;  // Ângulo em radianos
  final double length; // Comprimento total da régua (em pixels de canvas)
  final double width;  // Largura da régua (ex: 80px)
  final bool isVisible;

  const StemRulerState({
    this.center = const Offset(400, 300),
    this.angle = 0.0,
    this.length = 600.0,
    this.width = 84.0,
    this.isVisible = false,
  });

  StemRulerState copyWith({
    Offset? center,
    double? angle,
    double? length,
    double? width,
    bool? isVisible,
  }) {
    return StemRulerState(
      center: center ?? this.center,
      angle: angle ?? this.angle,
      length: (length ?? this.length).clamp(300.0, 1800.0),
      width: width ?? this.width,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  /// Vetor unitário apontando ao longo do comprimento da régua
  Offset get uVector => Offset(math.cos(angle), math.sin(angle));

  /// Vetor unitário apontando perpendicularmente (da borda superior para a inferior)
  Offset get vVector => Offset(-math.sin(angle), math.cos(angle));

  /// Extremidade esquerda do eixo central
  Offset get leftEnd => center - uVector * (length / 2.0);

  /// Extremidade direita do eixo central
  Offset get rightEnd => center + uVector * (length / 2.0);

  /// Vértices dos 4 cantos da régua no espaço do Canvas
  List<Offset> get corners {
    final uHalf = uVector * (length / 2.0);
    final vHalf = vVector * (width / 2.0);
    return [
      center - uHalf - vHalf, // Top-Left
      center + uHalf - vHalf, // Top-Right
      center + uHalf + vHalf, // Bottom-Right
      center - uHalf + vHalf, // Bottom-Left
    ];
  }

  /// Verifica se um ponto está dentro do corpo da régua
  bool containsPoint(Offset point) {
    if (!isVisible) return false;
    final d = point - center;
    final u = uVector;
    final v = vVector;
    final uDist = (d.dx * u.dx + d.dy * u.dy).abs();
    final vDist = (d.dx * v.dx + d.dy * v.dy).abs();
    return uDist <= (length / 2.0) && vDist <= (width / 2.0);
  }

  /// Verifica se o ponto clicado está no transferidor central para rotação
  bool isNearCenterProtractor(Offset point) {
    if (!isVisible) return false;
    return (point - center).distance <= 36.0;
  }

  /// Retorna o ponto projetado na borda superior ou inferior caso o ponto esteja dentro da zona de atração magnética (snap distance).
  /// Retorna null se não houver snap.
  Offset? snapPoint(Offset point, {double snapTolerance = 24.0}) {
    if (!isVisible) return null;

    final d = point - center;
    final u = uVector;
    final v = vVector;

    final uDist = d.dx * u.dx + d.dy * u.dy; // Projeção ao longo da régua
    final vDist = d.dx * v.dx + d.dy * v.dy; // Projeção perpendicular

    final halfL = length / 2.0;
    final halfW = width / 2.0;

    // Se estiver fora do comprimento da régua (com margem de 16px), não atrai
    if (uDist < -halfL - 16.0 || uDist > halfL + 16.0) {
      return null;
    }

    final clampedU = uDist.clamp(-halfL, halfL);

    // Teste de atração para a borda superior (-halfW)
    final distToTopEdge = (vDist - (-halfW)).abs();
    if (distToTopEdge <= snapTolerance) {
      return center + u * clampedU + v * (-halfW);
    }

    // Teste de atração para a borda inferior (+halfW)
    final distToBottomEdge = (vDist - halfW).abs();
    if (distToBottomEdge <= snapTolerance) {
      return center + u * clampedU + v * halfW;
    }

    return null;
  }

  /// Retorna o valor do ângulo normalizado de 0° a 180° (geometria padrão de régua simétrica)
  int get displayDegrees {
    int deg = (angle * 180.0 / math.pi).round().abs();
    deg = deg % 360;
    if (deg > 180) {
      deg = 360 - deg;
    }
    return deg;
  }

  /// Trava magnética automática em ângulos notáveis de engenharia/matemática (0°, 15°, 30°, 45°, 60°, 90°, 120°, 135°, 150°, 180°)
  static double snapAngle(double angleRadians) {
    final degrees = angleRadians * 180.0 / math.pi;
    const step = 15.0;
    final nearest = (degrees / step).roundToDouble() * step;
    if ((degrees - nearest).abs() <= 2.5) {
      return nearest * math.pi / 180.0;
    }
    return angleRadians;
  }
}
