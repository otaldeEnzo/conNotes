import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

/// Barra Flutuante de Ações Rápidas da Seleção (Vidro Líquido Moscaro v2).
/// Permite Duplicar, Mudar Cor de todos os traços e Excluir.
class SelectionActionBar extends StatefulWidget {
  final List<Color> availableColors;
  final VoidCallback onDuplicate;
  final ValueChanged<Color> onChangeColor;
  final VoidCallback onRotate90;
  final GestureDragStartCallback? onRotatePanStart;
  final GestureDragUpdateCallback? onRotatePanUpdate;
  final GestureDragEndCallback? onRotatePanEnd;
  final VoidCallback onDelete;
  final VoidCallback onDeselect;

  const SelectionActionBar({
    super.key,
    required this.availableColors,
    required this.onDuplicate,
    required this.onChangeColor,
    required this.onRotate90,
    this.onRotatePanStart,
    this.onRotatePanUpdate,
    this.onRotatePanEnd,
    required this.onDelete,
    required this.onDeselect,
  });

  @override
  State<SelectionActionBar> createState() => _SelectionActionBarState();
}

class _SelectionActionBarState extends State<SelectionActionBar> {
  bool _isColorPickerOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Seletor de cores rápido (Cores dos Presets de Canetas)
        if (_isColorPickerOpen) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.availableColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    widget.onChangeColor(color);
                    setState(() {
                      _isColorPickerOpen = false;
                    });
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ).moscaroV2(
            borderRadius: 20.0,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
        ],

        // 2. Barra principal de botões de ação
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Duplicar
              _buildActionButton(
                assetName: 'duplicate',
                tooltip: 'Duplicar Traços (Ctrl+D)',
                onPressed: widget.onDuplicate,
              ),
              const SizedBox(width: 4),

              // 2. Mudar Cor
              _buildActionButton(
                assetName: 'palette',
                tooltip: 'Mudar Cor dos Traços',
                onPressed: () {
                  setState(() {
                    _isColorPickerOpen = !_isColorPickerOpen;
                  });
                },
                isActive: _isColorPickerOpen,
              ),
              const SizedBox(width: 4),

              // 3. Rotação (Clique: +90° | Arrastar: 360° Livre)
              _buildRotationButton(),
              const SizedBox(width: 4),

              Container(width: 1, height: 16, color: Colors.white24),
              const SizedBox(width: 4),

              // 4. Deletar
              _buildActionButton(
                assetName: 'trash',
                tooltip: 'Excluir Traços (Delete)',
                hoverColor: Colors.redAccent,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ).moscaroV2(
          borderRadius: 24.0,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildRotationButton() {
    return Tooltip(
      message: 'Girar (Clique: 90° | Arraste: Livre)',
      child: GestureDetector(
        onPanStart: widget.onRotatePanStart,
        onPanUpdate: widget.onRotatePanUpdate,
        onPanEnd: widget.onRotatePanEnd,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onRotate90,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: const SvgIcon(
                assetName: 'rotate',
                size: 18,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String assetName,
    required String tooltip,
    required VoidCallback onPressed,
    Color? hoverColor,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? MoscaroTokens.auroraBlue.withValues(alpha: 0.2) : Colors.transparent,
            ),
            child: SvgIcon(
              assetName: assetName,
              size: 18,
              color: isActive ? MoscaroTokens.auroraBlue : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
