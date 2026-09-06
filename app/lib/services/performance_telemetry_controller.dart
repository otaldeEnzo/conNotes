import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Amostra de temporização de um quadro individual
class PerformanceFrameSample {
  final double buildMs;
  final double rasterMs;
  final double totalMs;
  final bool isJank;
  final DateTime timestamp;

  const PerformanceFrameSample({
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.isJank,
    required this.timestamp,
  });
}

/// Registro de um evento de Jank (engasgo perceptível)
class JankIncident {
  final DateTime timestamp;
  final double totalMs;
  final double buildMs;
  final double rasterMs;
  final String primaryCulprit;
  final String activeContext;
  final int memoryRssMb;

  const JankIncident({
    required this.timestamp,
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
    required this.primaryCulprit,
    required this.activeContext,
    required this.memoryRssMb,
  });
}

/// Motor de telemetria de alta frequência e diagnóstico de frames em tempo real
class PerformanceTelemetryController extends ChangeNotifier {
  static final PerformanceTelemetryController instance = PerformanceTelemetryController._internal();

  PerformanceTelemetryController._internal();

  bool _isHooked = false;

  // Buffer circular dos últimos 150 quadros para o gráfico de ondas
  static const int maxSamples = 150;
  final List<PerformanceFrameSample> _samples = [];
  List<PerformanceFrameSample> get samples => List.unmodifiable(_samples);

  // Registro dos últimos 40 janks
  static const int maxJankRecords = 40;
  final List<JankIncident> _janks = [];
  List<JankIncident> get janks => List.unmodifiable(_janks);

  // Métricas instantâneas
  double currentFps = 60.0;
  double averageFps = 60.0;
  double low1PercentFps = 60.0;
  double low01PercentFps = 60.0;
  double currentBuildMs = 2.0;
  double currentRasterMs = 4.0;
  double currentTotalMs = 6.0;
  int totalJankCount = 0;
  int totalSampledFrames = 0;
  int currentMemoryRssMb = 0;

  // Contexto ativo do app para correlação no momento do jank
  String currentContextAction = 'Idle / Repouso';

  DateTime _lastMetricsUpdate = DateTime.now();
  final List<double> _rollingTotalTimes = [];

  void setContextAction(String action) {
    currentContextAction = action;
  }

  /// Inicia o monitoramento conectando-se ao SchedulerBinding do Flutter
  void initialize() {
    if (_isHooked) return;
    _isHooked = true;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    try {
      currentMemoryRssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {}
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;

    final now = DateTime.now();

    for (final timing in timings) {
      totalSampledFrames++;

      final bMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

      // Jank é considerado qualquer frame que exceda o orçamento de 120 FPS (8.33ms) ou 60 FPS (16.66ms)
      final bool isJank = totalMs > 16.66 || (bMs > 12.0 || rMs > 12.0);

      final sample = PerformanceFrameSample(
        buildMs: bMs,
        rasterMs: rMs,
        totalMs: totalMs,
        isJank: isJank,
        timestamp: now,
      );

      _samples.add(sample);
      if (_samples.length > maxSamples) {
        _samples.removeAt(0);
      }

      _rollingTotalTimes.add(totalMs);
      if (_rollingTotalTimes.length > 120) {
        _rollingTotalTimes.removeAt(0);
      }

      // Registrar incidente de Jank
      if (totalMs >= 18.0) {
        totalJankCount++;
        String culprit = 'Misto (CPU + GPU)';
        if (bMs > rMs * 1.5) {
          culprit = 'CPU (Dart Build/Layout)';
        } else if (rMs > bMs * 1.5) {
          culprit = 'GPU (Raster/BackdropFilter)';
        }

        int mem = currentMemoryRssMb;
        try {
          mem = ProcessInfo.currentRss ~/ (1024 * 1024);
          currentMemoryRssMb = mem;
        } catch (_) {}

        final jank = JankIncident(
          timestamp: now,
          totalMs: totalMs,
          buildMs: bMs,
          rasterMs: rMs,
          primaryCulprit: culprit,
          activeContext: currentContextAction,
          memoryRssMb: mem,
        );

        _janks.insert(0, jank);
        if (_janks.length > maxJankRecords) {
          _janks.removeLast();
        }
      }
    }

    // Atualização de métricas agregadas a cada ~120ms (para não onerar a UI)
    final elapsedMs = now.difference(_lastMetricsUpdate).inMilliseconds;
    if (elapsedMs >= 120 && _rollingTotalTimes.isNotEmpty) {
      final lastSample = _samples.last;
      currentBuildMs = lastSample.buildMs;
      currentRasterMs = lastSample.rasterMs;
      currentTotalMs = lastSample.totalMs;

      // FPS instantâneo
      currentFps = currentTotalMs > 0 ? (1000.0 / currentTotalMs).clamp(0.0, 240.0) : 60.0;

      // Média móvel
      double sum = 0;
      for (final t in _rollingTotalTimes) {
        sum += t;
      }
      final avgTime = sum / _rollingTotalTimes.length;
      averageFps = avgTime > 0 ? (1000.0 / avgTime).clamp(0.0, 240.0) : 60.0;

      // 1% Low FPS (Pior 1% dos tempos de quadro convertidos em FPS)
      final sortedTimes = List<double>.from(_rollingTotalTimes)..sort();
      final p99Index = math.min((sortedTimes.length * 0.99).floor(), sortedTimes.length - 1);
      final p999Index = math.min((sortedTimes.length * 0.999).floor(), sortedTimes.length - 1);

      final p99Time = sortedTimes[p99Index];
      final p999Time = sortedTimes[p999Index];

      low1PercentFps = p99Time > 0 ? (1000.0 / p99Time).clamp(0.0, 240.0) : 60.0;
      low01PercentFps = p999Time > 0 ? (1000.0 / p999Time).clamp(0.0, 240.0) : 60.0;

      _lastMetricsUpdate = now;

      notifyListeners();
    }
  }

  void clearJanks() {
    _janks.clear();
    totalJankCount = 0;
    notifyListeners();
  }
}
