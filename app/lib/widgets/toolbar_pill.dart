import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Desfazer (Undo)
        IconButton(
          icon: Icon(
            Icons.undo,
            size: 18,
            color: widget.canUndo ? Colors.white70 : Colors.white24,
          ),
          onPressed: widget.canUndo ? widget.onUndo : null,
          tooltip: 'Desfazer (Ctrl + Z)',
        ),
        // 2. Refazer (Redo)
        IconButton(
          icon: Icon(
            Icons.redo,
            size: 18,
            color: widget.canRedo ? Colors.white70 : Colors.white24,
          ),
          onPressed: widget.canRedo ? widget.onRedo : null,
          tooltip: 'Refazer (Ctrl + Y)',
        ),
        const SizedBox(width: 4),
        Container(width: 1, height: 20, color: Colors.white24),
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
              customActiveColor: widget.isPenActive ? widget.activePenPreset.color : null,
            ),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 2, right: 4),
              decoration: BoxDecoration(
                color: widget.activePenPreset.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.0),
                boxShadow: [
                  BoxShadow(color: widget.activePenPreset.color.withValues(alpha: 0.6), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),

        // 4. Borracha (SVG)
        _buildHoverIconButton(
          index: 1,
          assetName: 'eraser',
          tooltip: 'Borracha',
          onPressed: widget.onSelectEraser,
          iconSize: iconSize,
          customActiveColor: widget.isEraserActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 4.5. Formas Geométricas / Smart Shapes (SVG)
        _buildHoverIconButton(
          index: 5,
          assetName: 'shapes',
          tooltip: 'Formas Geométricas',
          onPressed: widget.onSelectShapes,
          iconSize: iconSize,
          customActiveColor: widget.isShapesActive ? MoscaroTokens.auroraPurple : null,
        ),
        const SizedBox(width: 4),

        // 5. Ferramenta de Seleção (SVG)
        _buildHoverIconButton(
          index: 4,
          assetName: widget.selectionType == SelectionType.rectangle ? 'select_rect' : 'select_lasso',
          tooltip: 'Ferramenta de Seleção',
          onPressed: widget.onSelectTool,
          iconSize: iconSize,
          customActiveColor: widget.isSelectActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 4),

        // 5.5. Ponteiro Laser (SVG)
        _buildHoverIconButton(
          index: 6,
          assetName: 'laser',
          tooltip: 'Ponteiro Laser (Apresentação)',
          onPressed: widget.onSelectLaser,
          iconSize: iconSize,
          customActiveColor: widget.isLaserActive ? const Color(0xFFFF0055) : null,
        ),
        const SizedBox(width: 4),

        // 5.6. Régua STEM Interativa (SVG)
        _buildHoverIconButton(
          index: 7,
          assetName: 'ruler',
          tooltip: 'Régua STEM (Fita Métrica e Guia)',
          onPressed: widget.onToggleRuler,
          iconSize: iconSize,
          customActiveColor: widget.isRulerActive ? MoscaroTokens.auroraBlue : null,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: Colors.white24),
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
        Container(width: 1, height: 20, color: Colors.white24),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: IconButton(
        icon: SvgIcon(
          assetName: assetName,
          size: iconSize,
          color: isHovered ? activeColor : (customActiveColor ?? Colors.white),
        ),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
