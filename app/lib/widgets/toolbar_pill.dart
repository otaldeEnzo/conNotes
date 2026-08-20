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
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    const double iconSize = 22.0;
    final isLight = MoscaroTokens.isLight;
    final iconColor = MoscaroTokens.iconInactive;
    final dividerColor = isLight ? Colors.black12 : Colors.white24;
    final displayPenColor = StemInkThemeAdapter.adaptStrokeColor(
      widget.activePenPreset.color,
      isLightTheme: isLight,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Desfazer (Undo)
        IconButton(
          icon: Icon(
            Icons.undo,
            size: 18,
            color: widget.canUndo ? iconColor : (isLight ? Colors.black26 : Colors.white24),
          ),
          onPressed: widget.canUndo ? widget.onUndo : null,
          tooltip: 'Desfazer (Ctrl + Z)',
        ),
        // 2. Refazer (Redo)
        IconButton(
          icon: Icon(
            Icons.redo,
            size: 18,
            color: widget.canRedo ? iconColor : (isLight ? Colors.black26 : Colors.white24),
          ),
          onPressed: widget.canRedo ? widget.onRedo : null,
          tooltip: 'Refazer (Ctrl + Y)',
        ),
        const SizedBox(width: 4),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 6),

        // 3. Caneta STEM (SVG) com indicador da cor ativa do slot selecionado
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHoverIconButton(
              index: 0,
              assetName: 'pen',
              tooltip: 'Caneta STEM (${widget.activePenPreset.name})',
              onPressed: widget.onSelectPen,
              iconSize: iconSize,
              customActiveColor: widget.isPenActive ? displayPenColor : null,
            ),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 2, right: 4),
              decoration: BoxDecoration(
                color: displayPenColor,
                shape: BoxShape.circle,
                border: Border.all(color: isLight ? Colors.black38 : Colors.white, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: displayPenColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),

        // 4. Borracha Inteligente (SVG)
        _buildHoverIconButton(
          index: 1,
          assetName: 'eraser',
          tooltip: 'Borracha Inteligente',
          onPressed: widget.onSelectEraser,
          iconSize: iconSize,
          customActiveColor: widget.isEraserActive ? MoscaroTokens.auroraPink : null,
        ),
        const SizedBox(width: 4),

        // 4.1 Formas Geométricas (SVG)
        _buildHoverIconButton(
          index: 5,
          assetName: 'shapes',
          tooltip: 'Formas Inteligentes',
          onPressed: widget.onSelectShapes,
          iconSize: iconSize,
          customActiveColor: widget.isShapesActive ? MoscaroTokens.auroraAmber : null,
        ),
        const SizedBox(width: 4),

        // 4.2 Seleção e Transformação (SVG)
        _buildHoverIconButton(
          index: 6,
          assetName: 'select',
          tooltip: 'Seleção e Transformação (${widget.selectionType == SelectionType.rectangle ? "Retângulo" : "Laço"})',
          onPressed: widget.onSelectTool,
          iconSize: iconSize,
          customActiveColor: widget.isSelectActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 4.3 Ponteiro Laser STEM (SVG)
        _buildHoverIconButton(
          index: 7,
          assetName: 'laser',
          tooltip: 'Ponteiro Laser Efêmero (Apresentação STEM)',
          onPressed: widget.onSelectLaser,
          iconSize: iconSize,
          customActiveColor: widget.isLaserActive ? MoscaroTokens.auroraPink : null,
        ),
        const SizedBox(width: 4),

        // 5. Régua & Transferidor STEM (SVG)
        _buildHoverIconButton(
          index: 4,
          assetName: 'ruler',
          tooltip: 'Instrumentos de Medição STEM (Régua / Transferidor)',
          onPressed: widget.onToggleRuler,
          iconSize: iconSize,
          customActiveColor: widget.isRulerActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 5.1 Inserir Cards no Canvas (Card STEM)
        _buildHoverIconButton(
          index: 5,
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
        _buildHoverIconButton(
          index: 2,
          assetName: 'grid',
          tooltip: 'Fundo do Canvas',
          onPressed: widget.onToggleGridMenu,
          iconSize: iconSize,
          customActiveColor: widget.isGridMenuOpen ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: dividerColor),
        const SizedBox(width: 8),

        // 7. Botão IA (SVG)
        _buildHoverIconButton(
          index: 3,
          assetName: 'ai',
          tooltip: widget.isAIOpen ? 'Fechar IA' : 'Assistente STEM IA',
          onPressed: widget.onToggleAI,
          iconSize: iconSize,
          customActiveColor: widget.isAIOpen ? MoscaroTokens.auroraPurple : null,
        ),
      ],
    );
  }

  Widget _buildHoverIconButton({
    required int index,
    required String assetName,
    required String tooltip,
    required VoidCallback onPressed,
    required double iconSize,
    Color? customActiveColor,
  }) {
    final bool isHovered = _hoveredIndex == index;
    final Color activeColor = customActiveColor ?? MoscaroTokens.auroraBlue;
    final defaultColor = MoscaroTokens.isLight ? MoscaroTokens.iconInactive : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: IconButton(
        icon: SvgIcon(
          assetName: assetName,
          size: iconSize,
          color: isHovered ? activeColor : (customActiveColor ?? defaultColor),
        ),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
