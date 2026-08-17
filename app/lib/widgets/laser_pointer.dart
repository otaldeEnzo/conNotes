import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Ponto temporal do rastro incandescente do Laser Pointer.
class LaserTrailPoint {
  final Offset point;
  final int timestampMs;
  final bool isSegmentStart;

  const LaserTrailPoint({
    required this.point,
    required this.timestampMs,
    this.isSegmentStart = false,
  });
}

/// Motor do Ponteiro Laser efêmero com decaimento suave de 1.5s e animação 144Hz.
class LaserPointerEngine {
  final List<LaserTrailPoint> _trail = [];
  Offset? _currentPosition;
  bool _isPointing = false;
  Ticker? _ticker;

  final ValueNotifier<int> repaintNotifier = ValueNotifier<int>(0);
  static const int maxLifetimeMs = 1500; // 1.5 segundos de persistência

  List<LaserTrailPoint> get trail => _trail;
  Offset? get currentPosition => _currentPosition;
  bool get isPointing => _isPointing;

  void init(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    repaintNotifier.dispose();
  }

  void updateHoverPosition(Offset? canvasPoint) {
    _currentPosition = canvasPoint;
    repaintNotifier.value++;
  }

  void onPointerDown(Offset canvasPoint) {
    _isPointing = true;
    _currentPosition = canvasPoint;
    _trail.add(LaserTrailPoint(
      point: canvasPoint,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      isSegmentStart: true,
    ));
    _ensureTickerRunning();
    repaintNotifier.value++;
  }

  void onPointerMove(Offset canvasPoint) {
    _currentPosition = canvasPoint;
    if (_isPointing) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_trail.isEmpty || (canvasPoint - _trail.last.point).distanceSquared >= 16.0) {
        _trail.add(LaserTrailPoint(
          point: canvasPoint,
          timestampMs: now,
          isSegmentStart: false,
        ));
        _ensureTickerRunning();
        repaintNotifier.value++;
      }
    } else {
      repaintNotifier.value++;
    }
  }

  void onPointerUp() {
    _isPointing = false;
    repaintNotifier.value++;
  }

  void _ensureTickerRunning() {
    if (_ticker != null && !_ticker!.isActive) {
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _trail.removeWhere((p) => now - p.timestampMs >= maxLifetimeMs);

    if (_trail.isEmpty && !_isPointing) {
      _ticker?.stop();
    }
    repaintNotifier.value++;
  }

  void clear() {
    _trail.clear();
    _currentPosition = null;
    _isPointing = false;
    _ticker?.stop();
    repaintNotifier.value++;
  }
}

/// Painter ultra-otimizado (Batched Path Chunks na GPU - Zero CPU/GPU Overhead)
class LaserPointerPainter extends CustomPainter {
  final LaserPointerEngine engine;
  final Offset panOffset;
  final double zoomScale;
  final Color laserColor;

  // Pool de Paint reutilizáveis com StrokeJoin suave (Zero Alocações por frame)
  final Paint _outerGlowPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _midGlowPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _neonPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _corePaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final Paint _headHaloOuterPaint = Paint()..style = PaintingStyle.fill;
  final Paint _headHaloMidPaint = Paint()..style = PaintingStyle.fill;
  final Paint _headNeonPaint = Paint()..style = PaintingStyle.fill;
  final Paint _headCorePaint = Paint()..style = PaintingStyle.fill;

  LaserPointerPainter({
    required this.engine,
    required this.panOffset,
    required this.zoomScale,
    this.laserColor = const Color(0xFFFF0055), // Rosa/Vermelho Neon Incandescente
  }) : super(repaint: engine.repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trail = engine.trail;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // 1. Agrupa os pontos do rastro em 4 baldes de tempo (Batched Paths)
    // Isso reduz de centenas de drawLine para apenas 4 chamadas GPU nativas contínuas!
    if (trail.length >= 2) {
      final double invZoom = 1.0 / zoomScale;
      final double outerW = 12.0 * invZoom;
      final double midW = 6.0 * invZoom;
      final double neonW = 3.2 * invZoom;
      final double coreW = 1.5 * invZoom;

      const int numBuckets = 4;
      final bucketPaths = List.generate(numBuckets, (_) => Path());
      final bucketAlphas = [1.0, 0.65, 0.35, 0.12];

      for (int i = 0; i < trail.length - 1; i++) {
        final p0 = trail[i];
        final p1 = trail[i + 1];

        if (p1.isSegmentStart) continue;

        final age = now - p1.timestampMs;
        int bucketIndex = (age / (LaserPointerEngine.maxLifetimeMs / numBuckets)).floor();
        bucketIndex = bucketIndex.clamp(0, numBuckets - 1);

        final targetPath = bucketPaths[bucketIndex];
        targetPath.moveTo(p0.point.dx, p0.point.dy);
        targetPath.lineTo(p1.point.dx, p1.point.dy);
      }

      // Desenha cada balde de tempo em lote na GPU
      for (int b = 0; b < numBuckets; b++) {
        final path = bucketPaths[b];
        final alpha = bucketAlphas[b];

        // Camada 1: Glow Difuso
        _outerGlowPaint
          ..color = laserColor.withValues(alpha: alpha * 0.15)
          ..strokeWidth = outerW;
        canvas.drawPath(path, _outerGlowPaint);

        // Camada 2: Glow Concentrado
        _midGlowPaint
          ..color = laserColor.withValues(alpha: alpha * 0.38)
          ..strokeWidth = midW;
        canvas.drawPath(path, _midGlowPaint);

        // Camada 3: Feixe Neon Vívido
        _neonPaint
          ..color = laserColor.withValues(alpha: alpha * 0.95)
          ..strokeWidth = neonW;
        canvas.drawPath(path, _neonPaint);

        // Camada 4: Filamento Central Branco
        _corePaint
          ..color = Colors.white.withValues(alpha: alpha * 0.90)
          ..strokeWidth = coreW;
        canvas.drawPath(path, _corePaint);
      }
    }

    // 2. Renderiza a cabeça luminosa do laser
    final currentPos = engine.currentPosition;
    if (currentPos != null) {
      final double baseRadius = (engine.isPointing ? 5.5 : 4.0) / zoomScale;

      // Halo externo
      _headHaloOuterPaint.color = laserColor.withValues(alpha: engine.isPointing ? 0.18 : 0.10);
      canvas.drawCircle(currentPos, baseRadius * 2.8, _headHaloOuterPaint);

      // Halo intermediário
      _headHaloMidPaint.color = laserColor.withValues(alpha: engine.isPointing ? 0.38 : 0.22);
      canvas.drawCircle(currentPos, baseRadius * 1.8, _headHaloMidPaint);

      // Círculo neon principal
      _headNeonPaint.color = laserColor;
      canvas.drawCircle(currentPos, baseRadius, _headNeonPaint);

      // Núcleo branco quente
      _headCorePaint.color = Colors.white;
      canvas.drawCircle(currentPos, baseRadius * 0.45, _headCorePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LaserPointerPainter oldDelegate) {
    return true;
  }
}
