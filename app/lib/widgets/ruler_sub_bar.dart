import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'stem_ruler_model.dart';
import 'svg_icon.dart';

/// Sub-Barra Flutuante de Instrumentos de Medição STEM (Régua e Transferidor).
/// Estilizada universalmente no padrão Moscaro v2.
/// Aparece centralizada acima da Toolbar quando o modo de medição está aberto.
class RulerSubBar extends StatelessWidget {
  final bool isVisible;
  final MeasurementToolType activeTool;
  final ValueChanged<MeasurementToolType> onSelectTool;

  const RulerSubBar({
    super.key,
    required this.isVisible,
    required this.activeTool,
    required this.onSelectTool,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 0.4),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          scale: isVisible ? 1.0 : 0.88,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isVisible ? 1.0 : 0.0,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Botão Régua Linear
                  _buildToolButton(
                    type: MeasurementToolType.ruler,
                    label: 'Régua Linear',
                    assetName: 'ruler',
                    isSelected: activeTool == MeasurementToolType.ruler,
                  ),
                  const SizedBox(width: 6),

                  Container(width: 1, height: 20, color: Colors.white12),
                  const SizedBox(width: 6),

                  // 2. Botão Transferidor
                  _buildToolButton(
                    type: MeasurementToolType.protractor,
                    label: 'Transferidor',
                    assetName: 'protractor',
                    isSelected: activeTool == MeasurementToolType.protractor,
                  ),
                ],
              ),
            ).moscaroV2(
              borderRadius: MoscaroTokens.radiusPill,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required MeasurementToolType type,
    required String label,
    required String assetName,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelectTool(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? MoscaroTokens.auroraBlue.withValues(alpha: 0.22)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 1.2,
            ),
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
                  color: isSelected ? MoscaroTokens.auroraBlue : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
