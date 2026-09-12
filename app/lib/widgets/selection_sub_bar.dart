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
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Botão Retângulo
                    _SelectionTypeButton(
                      type: SelectionType.rectangle,
                      label: 'Área Retangular',
                      assetName: 'select_rect',
                      isSelected: activeType == SelectionType.rectangle,
                      onTap: () => onSelectType(SelectionType.rectangle),
                    ),
                    const SizedBox(width: 6),

                    Container(width: 1, height: 20, color: Colors.white12),
                    const SizedBox(width: 6),

                    // 2. Botão Laço Livre
                    _SelectionTypeButton(
                      type: SelectionType.lasso,
                      label: 'Laço Livre',
                      assetName: 'select_lasso',
                      isSelected: activeType == SelectionType.lasso,
                      onTap: () => onSelectType(SelectionType.lasso),
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
      ),
    );
  }
}

class _SelectionTypeButton extends StatefulWidget {
  final SelectionType type;
  final String label;
  final String assetName;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionTypeButton({
    required this.type,
    required this.label,
    required this.assetName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SelectionTypeButton> createState() => _SelectionTypeButtonState();
}

class _SelectionTypeButtonState extends State<_SelectionTypeButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 0.92 : (_isHovered ? 1.04 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () {
          if (_isPressed) setState(() => _isPressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.isSelected
                  ? MoscaroTokens.auroraBlue.withOpacity(0.18)
                  : (_isHovered ? Colors.white.withOpacity(0.06) : Colors.transparent),
              border: Border.all(
                color: widget.isSelected ? MoscaroTokens.auroraBlue : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: widget.isSelected
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
                  assetName: widget.assetName,
                  size: 16,
                  color: widget.isSelected ? MoscaroTokens.auroraBlue : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : Colors.white60,
                    fontSize: 12.5,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
