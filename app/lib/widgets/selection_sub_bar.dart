import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'selection_models.dart';
import 'svg_icon.dart';

/// Sub-Barra Flutuante de Seleção (Vidro Líquido Moscaro v2).
/// Surge centralizada acima da Toolbar quando a ferramenta de seleção está ativa.
class SelectionSubBar extends StatelessWidget {
  final bool isVisible;
  final SelectionType activeType;
  final ValueChanged<SelectionType> onSelectType;

  const SelectionSubBar({
    super.key,
    required this.isVisible,
    required this.activeType,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isVisible ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MoscaroTokens.glassWhite,
          borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
          border: Border.all(color: MoscaroTokens.borderGlow),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Botão Retângulo
            _buildTypeButton(
              type: SelectionType.rectangle,
              label: 'Área Retangular',
              assetName: 'select_rect',
              isSelected: activeType == SelectionType.rectangle,
            ),
            const SizedBox(width: 6),

            Container(width: 1, height: 20, color: Colors.white12),
            const SizedBox(width: 6),

            // 2. Botão Laço Livre
            _buildTypeButton(
              type: SelectionType.lasso,
              label: 'Laço Livre',
              assetName: 'select_lasso',
              isSelected: activeType == SelectionType.lasso,
            ),
          ],
        ),
      ).moscaroV2(
        borderRadius: MoscaroTokens.radiusPill,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTypeButton({
    required SelectionType type,
    required String label,
    required String assetName,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelectType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? MoscaroTokens.auroraBlue.withOpacity(0.18)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? MoscaroTokens.auroraBlue : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: MoscaroTokens.auroraBlue.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                assetName: assetName,
                size: 16,
                color: isSelected ? MoscaroTokens.auroraBlue : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
