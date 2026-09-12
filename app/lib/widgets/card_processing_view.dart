import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Widget de aviso não-editável exibido dentro do Card enquanto o LaTeX / OCR está sendo processado.
/// Apresenta o texto "Extraindo Latex, aguarde um instante..." com animação cíclica dos três pontinhos.
class CardProcessingView extends StatefulWidget {
  final String message;

  const CardProcessingView({
    super.key,
    this.message = 'Extraindo Latex, aguarde um instante',
  });

  @override
  State<CardProcessingView> createState() => _CardProcessingViewState();
}

class _CardProcessingViewState extends State<CardProcessingView> with SingleTickerProviderStateMixin {
  int _dotCount = 1;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final dots = '.' * _dotCount;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulseScale = 1.0 + (_pulseController.value * 0.04);
            final glowAlpha = 0.25 + (_pulseController.value * 0.25);

            return Transform.scale(
              scale: pulseScale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : MoscaroTokens.glassTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MoscaroTokens.auroraBlue.withValues(alpha: glowAlpha),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MoscaroTokens.auroraBlue.withValues(alpha: glowAlpha * 0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIcon(
                      name: 'ai',
                      size: 16,
                      color: MoscaroTokens.auroraBlue,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.message}$dots',
                      style: TextStyle(
                        color: isLight ? Colors.black87 : MoscaroTokens.textPrimary,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
