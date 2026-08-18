import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estado e modelo geométrico do Transferidor STEM Interativo.
class StemProtractorState {
  final Offset center; // Posição do centro do transferidor (em coordenadas de Canvas)
  final double radius; // Raio do semi-círculo do transferidor (em pixels de canvas)
  final double angle;  // Ângulo de rotação da base em radianos
  final bool isVisible;

  const StemProtractorState({
    this.center = const Offset(400, 300),
    this.radius = 160.0,
    this.angle = 0.0,
    this.isVisible = false,
  });

  StemProtractorState copyWith({
    Offset? center,
    double? radius,
    double? angle,
    bool? isVisible,
  }) {
    return StemProtractorState(
      center: center ?? this.center,
      radius: (radius ?? this.radius).clamp(90.0, 480.0),
      angle: angle ?? this.angle,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  /// Vetor unitário ao longo da linha de base reta (do centro para a direita)
  Offset get uVector => Offset(math.cos(angle), math.sin(angle));

  /// Vetor unitário perpendicular apontando para o topo do arco semi-circular
  Offset get vVector => Offset(-math.sin(angle), math.cos(angle));

  /// Extremidade esquerda da linha de base
  Offset get leftEnd => center - uVector * radius;

  /// Extremidade direita da linha de base
  Offset get rightEnd => center + uVector * radius;

  /// Ponto do vértice superior do arco (alça de rotação)
  Offset get topHandle => center - vVector * radius;

  /// Verifica se um ponto no Canvas está dentro do corpo do transferidor
  bool containsPoint(Offset point) {
    if (!isVisible) return false;
    final d = point - center;
    final dist = d.distance;
    if (dist > radius + 12.0) return false;

    // Projeção perpendicular (lado do semi-círculo: vDist deve ser <= 16px abaixo da base)
    final vDist = d.dx * vVector.dx + d.dy * vVector.dy;
    // Permite tocar um pouco abaixo da base (margem de 18px) e dentro do semi-círculo
    return vDist >= -radius - 12.0 && vDist <= 18.0;
  }

  /// Verifica se o ponto está próximo do mostrador central de ângulo (para duplo clique)
  bool isNearCenterHUD(Offset point) {
    if (!isVisible) return false;
    return (point - center).distance <= 38.0;
  }

  /// Verifica se o ponto está próximo da alça superior de rotação
  bool isNearRotateHandle(Offset point) {
    if (!isVisible) return false;
    return (point - topHandle).distance <= 28.0;
  }

  /// Verifica se o ponto está próximo das extremidades da base para ajuste de raio
  bool isNearRadiusHandle(Offset point) {
    if (!isVisible) return false;
    final distRight = (point - rightEnd).distance;
    final distLeft = (point - leftEnd).distance;
    return distRight <= 24.0 || distLeft <= 24.0;
  }

  /// Retorna o ponto atraído magneticamente ao arco ou à base do transferidor
  /// Permite traçar arcos perfeitos e linhas de base com a caneta.
  Offset? snapPoint(Offset point, {double snapTolerance = 24.0}) {
    if (!isVisible) return null;

    final d = point - center;
    final dist = d.distance;

    // 1. Teste de atração para o Arco Circular Externo
    if ((dist - radius).abs() <= snapTolerance) {
      final vDist = d.dx * vVector.dx + d.dy * vVector.dy;
      // Garante que o ponto está no lado do semi-círculo (acima da base)
      if (vDist <= 8.0) {
        final dir = d / dist;
        return center + dir * radius;
      }
    }

    // 2. Teste de atração para a Linha de Base Reta
    final u = uVector;
    final v = vVector;
    final uDist = d.dx * u.dx + d.dy * u.dy;
    final vDist = d.dx * v.dx + d.dy * v.dy;

    if (uDist >= -radius - 12.0 && uDist <= radius + 12.0) {
      if (vDist.abs() <= snapTolerance) {
        final clampedU = uDist.clamp(-radius, radius);
        return center + u * clampedU;
      }
    }

    return null;
  }

  /// Retorna o valor do ângulo normalizado de 0° a 180° simétrico
  int get displayDegrees {
    int deg = (angle * 180.0 / math.pi).round().abs();
    deg = deg % 360;
    if (deg > 180) {
      deg = 360 - deg;
    }
    return deg;
  }

  /// Trava magnética em ângulos notáveis de engenharia/matemática (0°, 15°, 30°, 45°, 60°, 90°, 120°, 135°, 150°, 180°)
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
