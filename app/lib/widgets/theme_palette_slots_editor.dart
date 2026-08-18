import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/theme_harmony_service.dart';
import 'theme_color_picker_dialog.dart';

/// Editor Visual Interativo dos 6 Slots da Paleta Rápida de Canetas STEM.
class ThemePaletteSlotsEditor extends StatefulWidget {
  final List<Color> palette;
  final Color primaryAccent;
  final ValueChanged<List<Color>> onPaletteChanged;

  const ThemePaletteSlotsEditor({
    super.key,
    required this.palette,
    required this.primaryAccent,
    required this.onPaletteChanged,
  });

  @override
  State<ThemePaletteSlotsEditor> createState() => _ThemePaletteSlotsEditorState();
}

class _ThemePaletteSlotsEditorState extends State<ThemePaletteSlotsEditor> {
  void _editSlotColor(int index) {
    ThemeColorPickerDialog.show(
      context: context,
      title: 'Cor da Caneta #${index + 1}',
      initialColor: widget.palette[index],
      onColorChanged: (newColor) {
        final newPalette = List<Color>.from(widget.palette);
        newPalette[index] = newColor;
        widget.onPaletteChanged(newPalette);
      },
    );
  }

  void _harmonizeAll() {
    final generated = ThemeHarmonyService.generateStemPaletteFromAccent(widget.primaryAccent);
    widget.onPaletteChanged(generated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paleta de Canetas da Toolbar (6 Cores STEM)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: _harmonizeAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MoscaroTokens.auroraBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: MoscaroTokens.auroraBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Harmonizar com Acento',
                        style: TextStyle(color: MoscaroTokens.auroraBlue, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.palette.length.clamp(0, 6), (index) {
              final color = widget.palette[index];
              return Tooltip(
                message: 'Slot ${index + 1}: Clique para alterar',
                child: GestureDetector(
                  onTap: () => _editSlotColor(index),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
