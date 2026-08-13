import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'canvas_dot_grid_painter.dart';
import 'svg_icon.dart';
import 'moscaro_dropdown_button.dart'; // Importando o novo dropdown unificado

/// Pílula Flutuante com raio de 30.0px, blur 30.0 contendo apenas ícones SVG de cor única e efeitos de hover.
class ToolbarPill extends StatefulWidget {
  final CanvasBackgroundType currentBackground;
  final ValueChanged<CanvasBackgroundType> onBackgroundChanged;
  final VoidCallback onSelectPen;
  final VoidCallback onSelectEraser;
  final VoidCallback onToggleAI;
  final bool isAIOpen;

  const ToolbarPill({
    super.key,
    required this.currentBackground,
    required this.onBackgroundChanged,
    required this.onSelectPen,
    required this.onSelectEraser,
    required this.onToggleAI,
    required this.isAIOpen,
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
        // 1. Caneta (SVG)
        _buildHoverIconButton(
          index: 0,
          assetName: 'pen',
          tooltip: 'Caneta STEM',
          onPressed: widget.onSelectPen,
          iconSize: iconSize,
        ),
        const SizedBox(width: 4),
        // 2. Borracha (SVG)
        _buildHoverIconButton(
          index: 1,
          assetName: 'eraser',
          tooltip: 'Borracha',
          onPressed: widget.onSelectEraser,
          iconSize: iconSize,
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: Colors.white24),
        const SizedBox(width: 8),
        // 3. Grid / Fundo (SVG) - Utilizando o MoscaroDropdownButton centralizado e unificado
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = 2),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: MoscaroDropdownButton<CanvasBackgroundType>(
            tooltip: 'Fundo do Canvas',
            icon: SvgIcon(
              assetName: 'grid',
              size: iconSize,
              color: _hoveredIndex == 2 ? MoscaroTokens.auroraBlue : Colors.white,
            ),
            dropdownWidth: 180,
            onSelected: widget.onBackgroundChanged,
            items: const [
              MoscaroDropdownItem(
                value: CanvasBackgroundType.dotGrid,
                child: Text('Dot Grid (com Glow)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              MoscaroDropdownItem(
                value: CanvasBackgroundType.pautado,
                child: Text('Pautado (Notebook)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              MoscaroDropdownItem(
                value: CanvasBackgroundType.emBranco,
                child: Text('Em Branco (Blank)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 20, color: Colors.white24),
        const SizedBox(width: 8),
        // 4. Botão IA (SVG)
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
