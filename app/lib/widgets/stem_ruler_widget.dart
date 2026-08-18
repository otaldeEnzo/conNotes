import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'stem_ruler_model.dart';
import 'svg_icon.dart';

/// Componente visual e interativo da Régua STEM Moscaro v2.
/// Oferece translação (arraste do corpo), rotação 360° (anel central e pontas),
/// redimensionamento de comprimento e mostrador HUD de ângulos.
class StemRulerWidget extends StatefulWidget {
  final StemRulerState state;
  final Offset panOffset;
  final double zoomScale;
  final ValueChanged<StemRulerState> onStateChanged;
  final VoidCallback onClose;

  const StemRulerWidget({
    super.key,
    required this.state,
    required this.panOffset,
    required this.zoomScale,
    required this.onStateChanged,
    required this.onClose,
  });

  @override
  State<StemRulerWidget> createState() => _StemRulerWidgetState();
}

class _StemRulerWidgetState extends State<StemRulerWidget> {
  void _openAngleEditDialog() {
    final currentDegrees = widget.state.displayDegrees;
    final textController = TextEditingController(text: '$currentDegrees');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: MoscaroTokens.backgroundSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.5), width: 1.2),
          ),
          title: Row(
            children: [
              SvgIcon(assetName: 'rotate', size: 20, color: MoscaroTokens.auroraBlue),
              const SizedBox(width: 8),
              const Text(
                'Ajustar Ângulo da Régua',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Digite a inclinação exata (0° a 180°):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  suffixText: '°',
                  suffixStyle: TextStyle(color: MoscaroTokens.auroraBlue, fontSize: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
    const double protractorRadius = 38.0;

    final scaledLength = widget.state.length * widget.zoomScale;
    final scaledWidth = widget.state.width * widget.zoomScale;

    return Stack(
      children: [
        // 1. Corpo da Régua usando a mesma extensão moscaroV2 que funciona no resto do app
        Positioned(
          left: screenCenter.dx - scaledLength / 2.0,
          top: screenCenter.dy - scaledWidth / 2.0,
          width: scaledLength,
          height: scaledWidth,
          child: Transform.rotate(
            angle: widget.state.angle,
            child: Container(
              width: scaledLength,
              height: scaledWidth,
            ).moscaroV2(
              blurSigma: 25.0,
              enableBlur: MoscaroTokens.enableInstrumentsBlur,
              backgroundColor: const Color(0xFF0A0E18).withValues(alpha: 0.42),
              borderRadius: 12.0 * widget.zoomScale,
              borderWidth: 0,
              borderColor: Colors.transparent,
              padding: EdgeInsets.zero,
            ),
          ),
        ),

        // 2. Traços, Neon, Glow e Numeração (Desenhados via CustomPaint sobre o vidro)
        CustomPaint(
          size: Size.infinite,
          painter: StemRulerPainter(
            state: widget.state,
            panOffset: widget.panOffset,
            zoomScale: widget.zoomScale,
          ),
        ),

        // 3. Área invisível interativa com suporte a Double Tap sobre o mostrador central de graus
        Positioned(
          left: screenCenter.dx - protractorRadius,
          top: screenCenter.dy - protractorRadius,
          width: protractorRadius * 2,
          height: protractorRadius * 2,
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

/// Painter da Régua STEM em Vidro Líquido Moscaro com marcações milimétricas,
/// numeração em cm e transferidor central.
class StemRulerPainter extends CustomPainter {
  final StemRulerState state;
  final Offset panOffset;
  final double zoomScale;

  StemRulerPainter({
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

    // Mover origem para o centro da régua e rotacionar
    canvas.translate(state.center.dx, state.center.dy);
    canvas.rotate(state.angle);

    final halfL = state.length / 2.0;
    final halfW = state.width / 2.0;
    final rect = Rect.fromLTRB(-halfL, -halfW, halfL, halfW);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12.0));

    // O fundo Translúcido Dark Glass Moscaro agora é renderizado pelo BackdropFilter no Widget (Camada 1).
    // O CustomPainter desenha apenas o Glow, Bordas e as Informações.

    // 2. Halo Glow Ciano Suave
    final glowPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.18)
      ..strokeWidth = 2.5 / zoomScale
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0 / zoomScale);
    canvas.drawRRect(rrect, glowPaint);

    // 3. Borda Neon Principal
    final borderPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.65)
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // 4. Linha Central Eixo de Simetria
    final centerAxisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-halfL + 20, 0), Offset(halfL - 20, 0), centerAxisPaint);

    // 5. Transferidor Central / Anel de Rotação
    _drawProtractor(canvas, zoomScale);

    // 6. Graduações Métricas (Superior e Inferior)
    _drawMetricScales(canvas, halfL, halfW, zoomScale);

    // 7. HUD de Graus Central (SEMPRE reto/upright, nunca rotaciona ou fica de ponta-cabeça)
    _drawUprightAngleHUD(canvas, zoomScale);

    canvas.restore();
  }

  void _drawProtractor(Canvas canvas, double zoom) {
    const double radius = 32.0;

    final circleFill = Paint()
      ..color = MoscaroTokens.backgroundDeep.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, circleFill);

    final circleBorder = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.5)
      ..strokeWidth = 1.2 / zoom
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, radius, circleBorder);

    // Marcações angulares do anel (0° a 360° em passos de 30°)
    final tickPaint = Paint()
      ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.6)
      ..strokeWidth = 1.0 / zoom;

    for (int deg = 0; deg < 360; deg += 30) {
      final rad = deg * math.pi / 180.0;
      final p1 = Offset(math.cos(rad) * (radius - 5.0), math.sin(rad) * (radius - 5.0));
      final p2 = Offset(math.cos(rad) * radius, math.sin(rad) * radius);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  void _drawMetricScales(Canvas canvas, double halfL, double halfW, double zoom) {
    // 1 cm = 40.0 pixels de canvas (padrão métrico estável)
    const double pxPerCm = 40.0;
    const double pxPerMm = pxPerCm / 10.0;

    final mmPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 0.8 / zoom;

    final halfCmPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.0 / zoom;

    final cmPaint = Paint()
      ..color = MoscaroTokens.auroraBlue
      ..strokeWidth = 1.2 / zoom;

    final totalMarks = (halfL / pxPerMm).floor();

    for (int i = -totalMarks; i <= totalMarks; i++) {
      final x = i * pxPerMm;
      if (x < -halfL + 12 || x > halfL - 12) continue;

      final isCm = i % 10 == 0;
      final isHalfCm = i % 5 == 0 && !isCm;

      final double tickLengthTop = isCm ? 18.0 : (isHalfCm ? 12.0 : 6.0);
      final double tickLengthBottom = isCm ? 14.0 : (isHalfCm ? 9.0 : 5.0);

      // Borda Superior
      final paintTop = isCm ? cmPaint : (isHalfCm ? halfCmPaint : mmPaint);
      canvas.drawLine(Offset(x, -halfW), Offset(x, -halfW + tickLengthTop), paintTop);

      // Borda Inferior
      canvas.drawLine(Offset(x, halfW), Offset(x, halfW - tickLengthBottom), paintTop);

      // Numeração em cm (apenas na borda superior para elegância)
      if (isCm && i.abs() > 0) {
        final cmValue = (i / 10).abs().toInt();
        final textSpan = TextSpan(
          text: '$cmValue',
          style: TextStyle(
            color: MoscaroTokens.auroraBlue,
            fontSize: 10.0,
            fontWeight: FontWeight.w600,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final textCenter = Offset(x, -halfW + tickLengthTop + 3.0 + textPainter.height / 2.0);
        
        canvas.save();
        canvas.translate(textCenter.dx, textCenter.dy);
        canvas.rotate(-state.angle); // Desfaz a rotação da régua para que o número fique sempre de pé
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
        );
        canvas.restore();
      }
    }
  }

  void _drawUprightAngleHUD(Canvas canvas, double zoom) {
    // Salva o contexto atual (que está rotacionado com a régua) e desfaz a rotação no centro
    canvas.save();
    canvas.rotate(-state.angle);

    final deg = state.displayDegrees;
    final textSpan = TextSpan(
      text: '$deg°',
      style: TextStyle(
        color: MoscaroTokens.canvasTextColor,
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StemRulerPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale;
  }
}
