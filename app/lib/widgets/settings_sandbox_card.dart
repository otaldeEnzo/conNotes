import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'ink_models.dart';

/// Mini-Canvas de Teste Interativo (Sandbox) no padrão Moscaro v2 Pro Max.
class SettingsSandboxCard extends StatefulWidget {
  final double smoothingTolerance;
  final double pressureSensitivity;

  const SettingsSandboxCard({
    super.key,
    required this.smoothingTolerance,
    required this.pressureSensitivity,
  });

  @override
  State<SettingsSandboxCard> createState() => _SettingsSandboxCardState();
}

class _SettingsSandboxCardState extends State<SettingsSandboxCard> {
  final List<List<StrokePoint>> _strokes = [];
  List<StrokePoint>? _currentStroke;
  bool _isClearHovered = false;

  void _clearSandbox() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MoscaroTokens.auroraBlue.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // 1. Grid sutil de precisão com crosshairs nos cantos
            CustomPaint(
              size: Size.infinite,
              painter: _SandboxGridPainter(),
            ),

            // 2. Traços desenhados na Sandbox
            CustomPaint(
              size: Size.infinite,
              painter: _SandboxStrokePainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
              ),
            ),

            // 3. Captura de eventos de toque e ponteiro
            Positioned.fill(
              child: Listener(
                onPointerDown: (event) {
                  final rawPressure = event.pressure > 0 ? event.pressure : 0.6;
                  final effectivePressure = (rawPressure * widget.pressureSensitivity).clamp(0.2, 1.8);
                  setState(() {
                    _currentStroke = [
                      StrokePoint(point: event.localPosition, pressure: effectivePressure),
                    ];
                  });
                },
                onPointerMove: (event) {
                  if (_currentStroke != null) {
                    final rawPressure = event.pressure > 0 ? event.pressure : 0.6;
                    final effectivePressure = (rawPressure * widget.pressureSensitivity).clamp(0.2, 1.8);
                    final lastPoint = _currentStroke!.last.point;
                    if ((event.localPosition - lastPoint).distanceSquared >= 2.0) {
                      setState(() {
                        _currentStroke!.add(
                          StrokePoint(point: event.localPosition, pressure: effectivePressure),
                        );
                      });
                    }
                  }
                },
                onPointerUp: (event) {
                  if (_currentStroke != null && _currentStroke!.isNotEmpty) {
                    final simplified = InkStroke.simplifyRDP(
                      _currentStroke!,
                      widget.smoothingTolerance,
                    );
                    setState(() {
                      _strokes.add(simplified);
                      _currentStroke = null;
                    });
                  }
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: SizedBox.expand(),
                ),
              ),
            ),

            // 4. Header da Sandbox com Badges e botão Limpar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: MoscaroTokens.auroraBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MoscaroTokens.auroraBlue.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Área de Teste Interativa (Sandbox)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'RDP ${widget.smoothingTolerance.toStringAsFixed(2)} | Sens ${widget.pressureSensitivity.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_strokes.isNotEmpty || _currentStroke != null)
                    MouseRegion(
                      onEnter: (_) => setState(() => _isClearHovered = true),
                      onExit: (_) => setState(() => _isClearHovered = false),
                      child: GestureDetector(
                        onTap: _clearSandbox,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isClearHovered
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isClearHovered
                                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Text(
                            'Limpar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SandboxGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    const spacing = 22.0;
    for (double x = 12; x < size.width; x += spacing) {
      for (double y = 12; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SandboxStrokePainter extends CustomPainter {
  final List<List<StrokePoint>> strokes;
  final List<StrokePoint>? currentStroke;

  _SandboxStrokePainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawPts(List<StrokePoint> pts) {
      if (pts.length < 2) {
        if (pts.length == 1) {
          canvas.drawCircle(pts.first.point, 2.5 * pts.first.pressure, paint..style = PaintingStyle.fill);
        }
        return;
      }
      for (int i = 0; i < pts.length - 1; i++) {
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final w = math.max(1.5, 3.5 * ((p1.pressure + p2.pressure) / 2.0));
        paint.strokeWidth = w;
        canvas.drawLine(p1.point, p2.point, paint..style = PaintingStyle.stroke);
      }
    }

    for (final s in strokes) {
      drawPts(s);
    }
    if (currentStroke != null) {
      drawPts(currentStroke!);
    }
  }

  @override
  bool shouldRepaint(_SandboxStrokePainter oldDelegate) => true;
}
