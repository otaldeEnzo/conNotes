import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

enum CardTypePreset {
  generalMarkdownLatex,
}

/// Sub-Barra de Criação de Cards no Canvas (100% Moscaro Glass).
class CardsSubBar extends StatelessWidget {
  final bool isVisible;
  final CardTypePreset? activePreset;
  final ValueChanged<CardTypePreset> onSelectPreset;

  const CardsSubBar({
    super.key,
    required this.isVisible,
    this.activePreset,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final themeAccent = MoscaroTokens.auroraBlue;
        final textPrimary = MoscaroTokens.textPrimary;
        final glassTint = MoscaroTokens.glassTint;
        final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
            ? MoscaroTokens.blurSigma
            : 0.0;

        final items = [
          {
            'preset': CardTypePreset.generalMarkdownLatex,
            'icon': 'card',
            'label': 'Card Markdown & LaTeX',
            'desc': 'Texto rico, equações e diagramas',
          },
        ];

        Widget content = Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isLight
                ? const Color(0xFFF8FAFC).withValues(alpha: 0.92)
                : glassTint,
            borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
            border: Border.all(
              color: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items) ...[
                    Builder(
                      builder: (ctx) {
                        final preset = item['preset'] as CardTypePreset;
                        final isSel = activePreset == preset;

                        return Tooltip(
                          message: '${item['label']}\n${item['desc']}\nClique no canvas para inserir.',
                          child: InkWell(
                            onTap: () => onSelectPreset(preset),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? themeAccent.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? themeAccent : Colors.transparent,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgIcon(
                                    name: item['icon'] as String,
                                    size: 16,
                                    color: isSel ? themeAccent : textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      color: isSel ? themeAccent : textPrimary,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (item != items.last) const SizedBox(width: 4),
                  ],
                ],
              ),
            );

        return ClipRRect(
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
          child: blur > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                  ),
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
