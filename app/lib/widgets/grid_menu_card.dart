import 'package:flutter/material.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'canvas_dot_grid_painter.dart';

/// Card flutuante com as opções de fundo do canvas (Dot Grid, Isométrico, Pautado, Em Branco)
/// desenhado com estética de vidro Moscaro v2 e alinhado perfeitamente no nível das sub-barras.
class GridMenuCard extends StatelessWidget {
  final CanvasBackgroundType currentBackground;
  final ValueChanged<CanvasBackgroundType> onSelectBackground;

  const GridMenuCard({
    super.key,
    required this.currentBackground,
    required this.onSelectBackground,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (CanvasBackgroundType.dotGrid, 'Dot Grid (com Glow)'),
      (CanvasBackgroundType.isometric, 'Isométrico (STEM 3D)'),
      (CanvasBackgroundType.pautado, 'Pautado (Notebook)'),
      (CanvasBackgroundType.emBranco, 'Em Branco (Blank)'),
    ];

    return Container(
      width: 204,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = item.$1 == currentBackground;
          final isLast = index == items.length - 1;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => onSelectBackground(item.$1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: isSelected ? MoscaroTokens.auroraBlue : MoscaroTokens.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: MoscaroTokens.auroraBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: MoscaroTokens.borderSubtle),
            ],
          );
        }).toList(),
      ),
    ).moscaroV2(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 4),
      borderWidth: 1.2,
    );
  }
}
