import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'theme_color_picker_dialog.dart';
import 'theme_property_hover_preview.dart';

/// Campo de Seleção Individual de Cor com Tag Hex, Abertura de Seletor e Hover Preview de 500ms.
/// Visual limpo com Orb de Vidro Luminoso Minimalista (Moscaro Standard).
class ThemeColorFieldTile extends StatefulWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final bool allowAlpha;
  final ThemePropertyType? propertyType;

  const ThemeColorFieldTile({
    super.key,
    required this.label,
    required this.color,
    required this.onColorChanged,
    this.allowAlpha = false,
    this.propertyType,
  });

  @override
  State<ThemeColorFieldTile> createState() => _ThemeColorFieldTileState();
}

class _ThemeColorFieldTileState extends State<ThemeColorFieldTile> {
  bool _isHovered = false;

  void _openPicker(BuildContext context) {
    ThemeColorPickerDialog.show(
      context: context,
      title: 'Ajustar ${widget.label}',
      initialColor: widget.color,
      allowAlpha: widget.allowAlpha,
      onColorChanged: widget.onColorChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hexString = '#${widget.color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final isLight = MoscaroTokens.isLight;

    Widget tile = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openPicker(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08))
                : (isLight ? Colors.black.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.55)
                  : (isLight ? Colors.black12 : Colors.white.withValues(alpha: 0.08)),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Orb de Vidro Luminoso com anel duplo de foco elegante (Sem poluição de ícones internos)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered ? Colors.white : Colors.white60,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _isHovered ? 0.65 : 0.35),
                      blurRadius: _isHovered ? 10 : 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Rótulo
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: MoscaroTokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Tag Hex Monospace
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
                ),
                child: Text(
                  hexString,
                  style: TextStyle(
                    color: MoscaroTokens.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.propertyType != null) {
      return ThemePropertyHoverPreview(
        propertyType: widget.propertyType!,
        currentColor: widget.color,
        child: tile,
      );
    }

    return tile;
  }
}
