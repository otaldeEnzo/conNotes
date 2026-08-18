import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'stem_protractor_model.dart';
import 'svg_icon.dart';

/// Componente visual e interativo do Transferidor STEM Moscaro v2.
/// Oferece translação, rotação 0-180°, mostrador HUD de ângulo com duplo clique,
/// escalas angulares duplas (0-180° e 180-0°) com numeração sempre upright
/// e guias magnéticas de arco e base.
class StemProtractorWidget extends StatefulWidget {
  final StemProtractorState state;
  final Offset panOffset;
  final double zoomScale;
  final ValueChanged<StemProtractorState> onStateChanged;
  final VoidCallback onClose;

  const StemProtractorWidget({
    super.key,
    required this.state,
    required this.panOffset,
    required this.zoomScale,
    required this.onStateChanged,
    required this.onClose,
  });

  @override
  State<StemProtractorWidget> createState() => _StemProtractorWidgetState();
}

class _StemProtractorWidgetState extends State<StemProtractorWidget> {
  void _openAngleEditDialog() {
    final textController = TextEditingController(text: '${widget.state.displayDegrees}');
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D121F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: MoscaroTokens.auroraBlue, width: 1.5),
          ),
          title: Row(
            children: [
              SvgIcon(assetName: 'protractor', size: 20, color: MoscaroTokens.auroraBlue),
              const SizedBox(width: 8),
              const Text(
                'Ajustar Ângulo do Transferidor',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Digite a inclinação da base (0° a 180°):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  suffixText: '°',
                  suffixStyle: TextStyle(color: MoscaroTokens.auroraBlue, fontSize: 16),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: MoscaroTokens.auroraBlue, width: 1.5),
                  ),
                ),
                onSubmitted: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) {
                    final normalized = parsed.clamp(0.0, 180.0);
                    widget.onStateChanged(widget.state.copyWith(angle: normalized * math.pi / 180.0));
                  }
                  Navigator.of(dialogCtx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                foregroundColor: MoscaroTokens.auroraBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: MoscaroTokens.auroraBlue),
                ),
              ),
              onPressed: () {
                final parsed = double.tryParse(textController.text);
                if (parsed != null) {
                  final normalized = parsed.clamp(0.0, 180.0);
                  widget.onStateChanged(widget.state.copyWith(angle: normalized * math.pi / 180.0));
                }
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isVisible) return const SizedBox.shrink();

    final screenCenter = widget.state.center * widget.zoomScale + widget.panOffset;
    final scaledRadius = widget.state.radius * widget.zoomScale;
    const double protractorHUDSize = 40.0;

    return Stack(
      children: [
        // 1. Corpo do Transferidor com Vidro Líquido Moscaro v2
        Positioned(
          left: screenCenter.dx - scaledRadius,
          top: screenCenter.dy - scaledRadius,
          width: scaledRadius * 2,
          height: scaledRadius * 2,
          child: Transform.rotate(
            angle: widget.state.angle,
            child: ClipPath(
              clipper: _SemiCircleClipper(),
              child: Container(
                width: scaledRadius * 2,
                height: scaledRadius * 2,
              ).moscaroV2(
                blurSigma: 25.0,
                enableBlur: MoscaroTokens.enableInstrumentsBlur,
                backgroundColor: const Color(0xFF0A0E18).withValues(alpha: 0.42),
                borderRadius: scaledRadius,
                borderWidth: 0,
                borderColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // 2. Traços, Graduações Angulares e Escala Neon desenhados via CustomPaint
        CustomPaint(
          size: Size.infinite,
          painter: StemProtractorPainter(
            state: widget.state,
            panOffset: widget.panOffset,
            zoomScale: widget.zoomScale,
          ),
        ),

        // 3. Área invisível interativa com suporte a Double Tap sobre o mostrador central de graus
        Positioned(
          left: screenCenter.dx - protractorHUDSize / 2,
          top: screenCenter.dy - protractorHUDSize / 2,
          width: protractorHUDSize,
          height: protractorHUDSize,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: _openAngleEditDialog,
            child: const MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Clipper para a metade superior do círculo (semi-círculo do transferidor)
class _SemiCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = size.width / 2.0;
    // Semi-círculo no topo (de -180° a 0°)
    path.moveTo(0, radius);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Painter do Transferidor STEM em Vidro Líquido Moscaro com marcações de graus,
/// dupla escala e mostrador de graus upright.
class StemProtractorPainter extends CustomPainter {
  final StemProtractorState state;
  final Offset panOffset;
  final double zoomScale;

  StemProtractorPainter({
    required this.state,
    required this.panOffset,
    required this.zoomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!state.isVisible) return;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // Mover origem para o centro da base do transferidor e rotacionar
    canvas.translate(state.center.dx, state.center.dy);
    canvas.rotate(state.angle);

    final r = state.radius;

    // 1. Halo Glow Ciano no Arco e na Base
    final glowPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.18)
      ..strokeWidth = 2.5 / zoomScale
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0 / zoomScale);

    final arcPath = Path()
      ..moveTo(-r, 0)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: false)
      ..close();

    canvas.drawPath(arcPath, glowPaint);

    // 2. Borda Neon Principal (Arco Semi-Circular e Linha de Base)
    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.75)
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.drawPath(arcPath, borderPaint);

    // 3. Arco Interno Guia
    final innerArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    final innerRadius = r * 0.72;
    final innerArcPath = Path()
      ..moveTo(-innerRadius, 0)
      ..arcToPoint(Offset(innerRadius, 0), radius: Radius.circular(innerRadius), clockwise: false);

    canvas.drawPath(innerArcPath, innerArcPaint);

    // 4. Cruz / Mira no Ponto de Origem Central
    final originPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.8)
      ..strokeWidth = 1.2 / zoomScale;

    canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), originPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -10), originPaint);
    canvas.drawCircle(Offset.zero, 3.0 / zoomScale, originPaint..style = PaintingStyle.fill);

    // 5. Graduações Angulares (0° a 180°)
    _drawDegreeGraduations(canvas, r, innerRadius, zoomScale);

    // 6. HUD Central de Ângulo (Sempre Upright)
    _drawUprightAngleHUD(canvas, zoomScale);

    // 7. Alça de Rotação Superior no Topo do Arco
    final handlePaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, -r), 4.5 / zoomScale, handlePaint);

    canvas.restore();
  }

  void _drawDegreeGraduations(Canvas canvas, double r, double innerR, double zoom) {
    final tickPaint1Deg = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8 / zoom;

    final tickPaint5Deg = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.0 / zoom;

    final tickPaint10Deg = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.3 / zoom;

    for (int deg = 0; deg <= 180; deg++) {
      // Ângulo em radianos relativo à horizontal (0° na direita, 180° na esquerda, subindo no semicírculo)
      final rad = deg * math.pi / 180.0;
      final cosVal = math.cos(rad);
      final sinVal = -math.sin(rad); // Negativo para subir no Canvas Y

      final is10 = deg % 10 == 0;
      final is5 = deg % 5 == 0 && !is10;

      final double tickLen = is10 ? 14.0 : (is5 ? 9.0 : 5.0);
      final paint = is10 ? tickPaint10Deg : (is5 ? tickPaint5Deg : tickPaint1Deg);

      final pOuter = Offset(cosVal * r, sinVal * r);
      final pInner = Offset(cosVal * (r - tickLen), sinVal * (r - tickLen));
      canvas.drawLine(pOuter, pInner, paint);

      // Linhas radiais guias suaves a cada 30° e 45°
      if (deg == 30 || deg == 45 || deg == 60 || deg == 90 || deg == 120 || deg == 135 || deg == 150) {
        final rayPaint = Paint()
          ..color = (deg == 90 || deg == 45 || deg == 135)
              ? MoscaroTokens.auroraBlue.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.9 / zoom;
        final pRayStart = Offset(cosVal * (innerR + 4.0), sinVal * (innerR + 4.0));
        canvas.drawLine(pRayStart, pInner, rayPaint);
      }

      // Numeração Angular Dupla (Escala Externa 0°-180° e Escala Interna 180°-0°)
      if (is10 && deg > 0 && deg < 180) {
        // 1. Escala Externa (0° na direita até 180° na esquerda)
        final numR = r - tickLen - 10.0;
        final textPosOuter = Offset(cosVal * numR, sinVal * numR);
        _drawUprightText(canvas, '$deg', textPosOuter, MoscaroTokens.auroraBlue, 9.0);

        // 2. Escala Interna (180° na direita até 0° na esquerda)
        if (deg % 30 == 0) {
          final innerDeg = 180 - deg;
          final numRInner = innerR + 10.0;
          final textPosInner = Offset(cosVal * numRInner, sinVal * numRInner);
          _drawUprightText(canvas, '$innerDeg', textPosInner, Colors.white60, 8.0);
        }
      }
    }
  }

  void _drawUprightText(Canvas canvas, String text, Offset centerPos, Color color, double fontSize) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(centerPos.dx, centerPos.dy);
    canvas.rotate(-state.angle); // Cancela a rotação para manter o texto sempre de pé
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );
    canvas.restore();
  }

  void _drawUprightAngleHUD(Canvas canvas, double zoom) {
    const double radius = 22.0;

    // Fundo circular do HUD
    final hudBg = Paint()
      ..color = const Color(0xFF080D18).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, hudBg);

    final hudBorder = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.6)
      ..strokeWidth = 1.2 / zoom
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, radius, hudBorder);

    // Texto de graus upright
    final textSpan = TextSpan(
      text: '${state.displayDegrees}°',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.rotate(-state.angle); // Upright absoluto
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(StemProtractorPainter oldDelegate) {
    return state != oldDelegate.state ||
        panOffset != oldDelegate.panOffset ||
        zoomScale != oldDelegate.zoomScale;
  }
}
