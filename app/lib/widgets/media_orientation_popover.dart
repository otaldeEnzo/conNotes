import 'package:flutter/material.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

/// Popover Flutuante Moscaro v2 para Orientação e Espelhamento de Mídia.
/// Visual 100% idêntico à barra principal (mesmo fundo Moscaro Glass v2, mesmo raio, mesma borda e estilo de botões).
/// Livre de emojis (regras de design estritas com ícones vetoriais SVG padronizados).
class MediaOrientationPopover extends StatelessWidget {
  final VoidCallback onRotateCw;
  final VoidCallback onRotateCcw;
  final VoidCallback onFlipH;
  final VoidCallback onFlipV;

  const MediaOrientationPopover({
    super.key,
    required this.onRotateCw,
    required this.onRotateCcw,
    required this.onFlipH,
    required this.onFlipV,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final dividerColor = isLight ? Colors.black12 : Colors.white12;

        final popoverContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopoverActionButton(
                iconName: 'rotate_cw',
                tooltip: 'Girar 90° horário',
                onPressed: onRotateCw,
              ),
              _PopoverActionButton(
                iconName: 'rotate_ccw',
                tooltip: 'Girar 90° anti-horário',
                onPressed: onRotateCcw,
              ),
              Container(
                width: 1.0,
                height: 18.0,
                color: dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
              ),
              _PopoverActionButton(
                iconName: 'flip_h',
                tooltip: 'Espelhar horizontal',
                onPressed: onFlipH,
              ),
              _PopoverActionButton(
                iconName: 'flip_v',
                tooltip: 'Espelhar vertical',
                onPressed: onFlipV,
              ),
            ],
          ),
        ).moscaroV2(
          borderRadius: 24.0,
          padding: EdgeInsets.zero,
        );

        return popoverContent;
      },
    );
  }
}

class _PopoverActionButton extends StatelessWidget {
  final String iconName;
  final String tooltip;
  final VoidCallback onPressed;

  const _PopoverActionButton({
    required this.iconName,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final themeAccent = theme.accentPrimary;
    final isLight = MoscaroTokens.isLight;
    final defaultColor = isLight ? MoscaroTokens.textSecondary : Colors.white70;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            hoverColor: themeAccent.withValues(alpha: 0.15),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: SvgIcon(
                name: iconName,
                size: 16,
                color: defaultColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
