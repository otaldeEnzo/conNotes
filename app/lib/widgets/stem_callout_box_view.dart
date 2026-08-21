import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';

enum StemCalloutType {
  tip,
  theorem,
  warning,
  concept,
}

/// Renderizador Visual de Callouts STEM em Vidro Líquido com Cores Vinculadas ao Tema.
class StemCalloutBoxView extends StatelessWidget {
  final StemCalloutType type;
  final String title;
  final Widget content;
  final bool isLight;
  final double fontSize;

  const StemCalloutBoxView({
    super.key,
    required this.type,
    required this.title,
    required this.content,
    required this.isLight,
    required this.fontSize,
  });

  Color get _accentColor {
    switch (type) {
      case StemCalloutType.tip:
        return MoscaroTokens.calloutTipColor;
      case StemCalloutType.theorem:
        return MoscaroTokens.calloutTheoremColor;
      case StemCalloutType.warning:
        return MoscaroTokens.calloutWarningColor;
      case StemCalloutType.concept:
        return MoscaroTokens.calloutConceptColor;
    }
  }

  IconData get _icon {
    switch (type) {
      case StemCalloutType.tip:
        return Icons.lightbulb_outline_rounded;
      case StemCalloutType.theorem:
        return Icons.functions_rounded;
      case StemCalloutType.warning:
        return Icons.warning_amber_rounded;
      case StemCalloutType.concept:
        return Icons.menu_book_rounded;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case StemCalloutType.tip:
        return 'DICA / INSIGHT STEM';
      case StemCalloutType.theorem:
        return 'TEOREMA / FÓRMULA-CHAVE';
      case StemCalloutType.warning:
        return 'ATENÇÃO / ALERTA';
      case StemCalloutType.concept:
        return 'CONCEITO FUNDAMENTAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    final displayTitle = title.isNotEmpty ? title : _defaultTitle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLight ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isLight ? 0.35 : 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Barra de destaque lateral esquerda do Callout STEM
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: Container(
                color: color,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho do Callout
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 4),
                  child: Row(
                    children: [
                      Icon(
                        _icon,
                        size: 15,
                        color: color,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            fontSize: fontSize * 0.82,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Conteúdo Interno
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 12, 8),
                  child: content,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
