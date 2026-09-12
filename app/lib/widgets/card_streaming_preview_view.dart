import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Visualizador em tempo real para cards de LaTeX durante streaming da IA (Gemini Flash).
///
/// Apresenta o código LaTeX sendo transmitido caractere a caractere com
/// tipografia monospace profissional, cursor pulsante e estética Moscaro liquid glass.
class CardStreamingPreviewView extends StatefulWidget {
  final String content;

  const CardStreamingPreviewView({
    super.key,
    required this.content,
  });

  @override
  State<CardStreamingPreviewView> createState() => _CardStreamingPreviewViewState();
}

class _CardStreamingPreviewViewState extends State<CardStreamingPreviewView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CardStreamingPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final cyan = MoscaroTokens.auroraBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.03)
            : MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cyan.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: cyan.withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header discreto indicando o streaming ao vivo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                name: 'ai',
                size: 13,
                color: cyan,
              ),
              const SizedBox(width: 6),
              Text(
                'Gemini Flash • Digitando LaTeX...',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bloco com o código sendo transmitido ao vivo
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.45,
                        color: isLight
                            ? Colors.black87
                            : MoscaroTokens.textPrimary,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: AnimatedBuilder(
                        animation: _cursorController,
                        builder: (context, _) => Opacity(
                          opacity: _cursorController.value > 0.4 ? 1.0 : 0.0,
                          child: Container(
                            width: 7,
                            height: 14,
                            margin: const EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(
                              color: cyan,
                              borderRadius: BorderRadius.circular(1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: cyan.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
