import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/stem_ink_theme_adapter.dart';
import 'canvas_dot_grid_painter.dart';
import 'svg_icon.dart';
import 'ink_models.dart';
import 'selection_models.dart';

/// Pílula Flutuante Principal contendo Desfazer, Refazer, Caneta Ativa, Borracha, Grid e IA.
class ToolbarPill extends StatefulWidget {
  final CanvasBackgroundType currentBackground;
  final ValueChanged<CanvasBackgroundType> onBackgroundChanged;
  final VoidCallback onSelectPen;
  final VoidCallback onSelectEraser;
  final VoidCallback onSelectShapes;
  final VoidCallback onSelectTool;
  final bool isSelectActive;
  final bool isShapesActive;
  final SelectionType selectionType;
  final VoidCallback onToggleAI;
  final bool isAIOpen;
  final bool isPenActive;
  final bool isEraserActive;
  final PenSlotPreset activePenPreset;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool isLaserActive;
  final VoidCallback onSelectLaser;
  final bool isRulerActive;
  final VoidCallback onToggleRuler;
  final bool isCardsActive;
  final VoidCallback onToggleCards;
  final bool isGridMenuOpen;
  final VoidCallback onToggleGridMenu;

  const ToolbarPill({
    super.key,
    required this.currentBackground,
    required this.onBackgroundChanged,
    required this.onSelectPen,
    required this.onSelectEraser,
    required this.onSelectShapes,
    required this.onSelectTool,
    required this.isSelectActive,
    this.isShapesActive = false,
    this.isLaserActive = false,
    required this.onSelectLaser,
    this.isRulerActive = false,
    required this.onToggleRuler,
    this.isCardsActive = false,
    required this.onToggleCards,
    required this.selectionType,
    required this.onToggleAI,
    required this.isAIOpen,
    required this.isPenActive,
    required this.isEraserActive,
    required this.activePenPreset,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    this.isGridMenuOpen = false,
    required this.onToggleGridMenu,
  });

  @override
  State<ToolbarPill> createState() => _ToolbarPillState();
}

class _ToolbarPillState extends State<ToolbarPill> {
  @override
  Widget build(BuildContext context) {
    const double iconSize = 20.0;
    final isLight = MoscaroTokens.isLight;
    final dividerColor = isLight ? Colors.black12 : Colors.white24;
    final displayPenColor = StemInkThemeAdapter.adaptStrokeColor(
      widget.activePenPreset.color,
      isLightTheme: isLight,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Desfazer (Undo)
        _ToolbarActionButton(
          assetName: 'undo',
          tooltip: 'Desfazer (Ctrl + Z)',
          onPressed: widget.onUndo,
          isEnabled: widget.canUndo,
          iconSize: 18,
        ),
        const SizedBox(width: 2),

        // 2. Refazer (Redo)
        _ToolbarActionButton(
          assetName: 'redo',
          tooltip: 'Refazer (Ctrl + Y)',
          onPressed: widget.onRedo,
          isEnabled: widget.canRedo,
          iconSize: 18,
        ),
        const SizedBox(width: 4),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 6),

        // 3. Caneta STEM (SVG) com indicador da cor ativa integrado
        _ToolbarActionButton(
          assetName: 'pen',
          tooltip: 'Caneta STEM (${widget.activePenPreset.name})',
          onPressed: widget.onSelectPen,
          iconSize: iconSize,
          customActiveColor: widget.isPenActive ? displayPenColor : null,
          badgeColor: displayPenColor,
        ),
        const SizedBox(width: 4),

        // 4. Borracha Inteligente (SVG)
        _ToolbarActionButton(
          assetName: 'eraser',
          tooltip: 'Borracha Inteligente',
          onPressed: widget.onSelectEraser,
          iconSize: iconSize,
          customActiveColor: widget.isEraserActive ? MoscaroTokens.auroraPink : null,
        ),
        const SizedBox(width: 4),

        // 4.1 Formas Geométricas (SVG)
        _ToolbarActionButton(
          assetName: 'shapes',
          tooltip: 'Formas Inteligentes',
          onPressed: widget.onSelectShapes,
          iconSize: iconSize,
          customActiveColor: widget.isShapesActive ? MoscaroTokens.auroraAmber : null,
        ),
        const SizedBox(width: 4),

        // 4.2 Seleção e Transformação (SVG)
        _ToolbarActionButton(
          assetName: widget.selectionType == SelectionType.rectangle ? 'select_rect' : 'select_lasso',
          tooltip: 'Seleção e Transformação (${widget.selectionType == SelectionType.rectangle ? "Retângulo" : "Laço"})',
          onPressed: widget.onSelectTool,
          iconSize: iconSize,
          customActiveColor: widget.isSelectActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 4.3 Ponteiro Laser STEM (SVG)
        _ToolbarActionButton(
          assetName: 'laser',
          tooltip: 'Ponteiro Laser Efêmero (Apresentação STEM)',
          onPressed: widget.onSelectLaser,
          iconSize: iconSize,
          customActiveColor: widget.isLaserActive ? MoscaroTokens.auroraPink : null,
        ),
        const SizedBox(width: 4),

        // 5. Régua & Transferidor STEM (SVG)
        _ToolbarActionButton(
          assetName: 'ruler',
          tooltip: 'Instrumentos de Medição STEM (Régua / Transferidor)',
          onPressed: widget.onToggleRuler,
          iconSize: iconSize,
          customActiveColor: widget.isRulerActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 5.1 Inserir Cards no Canvas (Card STEM)
        _ToolbarActionButton(
          assetName: 'card',
          tooltip: 'Inserir Cards (Texto, Markdown, LaTeX, Mermaid)',
          onPressed: widget.onToggleCards,
          iconSize: iconSize,
          customActiveColor: widget.isCardsActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 8),

        // 6. Grid / Fundo (SVG)
        _ToolbarActionButton(
          assetName: 'grid',
          tooltip: 'Fundo do Canvas',
          onPressed: widget.onToggleGridMenu,
          iconSize: iconSize,
          customActiveColor: widget.isGridMenuOpen ? MoscaroTokens.auroraBlue : null,
          rotateWhenActive: true,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 8),

        // 7. Botão IA (SVG)
        _ToolbarActionButton(
          assetName: 'ai',
          tooltip: widget.isAIOpen ? 'Fechar IA' : 'Assistente STEM IA',
          onPressed: widget.onToggleAI,
          iconSize: iconSize,
          customActiveColor: widget.isAIOpen ? MoscaroTokens.auroraPurple : null,
        ),
      ],
    );
  }
}

class _ToolbarActionButton extends StatefulWidget {
  final String assetName;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final Color? customActiveColor;
  final bool isEnabled;
  final Color? badgeColor;
  final bool rotateWhenActive;

  const _ToolbarActionButton({
    required this.assetName,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 20,
    this.customActiveColor,
    this.isEnabled = true,
    this.badgeColor,
    this.rotateWhenActive = false,
  });

  @override
  State<_ToolbarActionButton> createState() => _ToolbarActionButtonState();
}

class _ToolbarActionButtonState extends State<_ToolbarActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final bool isActive = widget.customActiveColor != null;
    final Color activeColor = widget.customActiveColor ?? MoscaroTokens.auroraBlue;
    final Color defaultColor = isLight ? MoscaroTokens.iconInactive : Colors.white70;
    final Color disabledColor = isLight ? Colors.black26 : Colors.white24;

    final Color currentColor = !widget.isEnabled
        ? disabledColor
        : (isActive ? activeColor : (_isHovered ? activeColor : defaultColor));

    final double currentScale = !widget.isEnabled
        ? 1.0
        : (_isPressed ? 0.90 : (_isHovered ? 1.08 : 1.0));

    final double currentRotation = (widget.rotateWhenActive && isActive) ? 0.125 : 0.0;

    return MouseRegion(
      cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.isEnabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: widget.isEnabled && widget.onPressed != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.isEnabled && widget.onPressed != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel: () {
          if (_isPressed) setState(() => _isPressed = false);
        },
        onTap: widget.isEnabled ? widget.onPressed : null,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedScale(
            scale: currentScale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor.withValues(alpha: 0.18)
                    : (_isHovered && widget.isEnabled
                        ? (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08))
                        : Colors.transparent),
                border: Border.all(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.45)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedRotation(
                    turns: currentRotation,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: SvgIcon(
                        key: ValueKey(widget.assetName),
                        name: widget.assetName,
                        size: widget.iconSize,
                        color: currentColor,
                      ),
                    ),
                  ),
                  if (widget.badgeColor != null)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: widget.badgeColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isLight ? Colors.black45 : Colors.white,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.badgeColor!.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
