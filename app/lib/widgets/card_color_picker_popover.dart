import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

enum ColorPickerMode {
  textColor,
  highlightColor,
}

/// Popover de Seleção de Cores de Texto e Marca-texto no padrão Moscaro v2.
class CardColorPickerPopover extends StatefulWidget {
  final Color? currentTextColor;
  final Color? currentHighlightColor;
  final ColorPickerMode initialMode;
  final ValueChanged<Color> onSelectTextColor;
  final ValueChanged<Color?> onSelectHighlightColor;
  final VoidCallback onClose;
  final double maxWidth;

  const CardColorPickerPopover({
    super.key,
    this.currentTextColor,
    this.currentHighlightColor,
    this.initialMode = ColorPickerMode.textColor,
    required this.onSelectTextColor,
    required this.onSelectHighlightColor,
    required this.onClose,
    this.maxWidth = 320.0,
  });

  @override
  State<CardColorPickerPopover> createState() => _CardColorPickerPopoverState();
}

class _CardColorPickerPopoverState extends State<CardColorPickerPopover> {
  late ColorPickerMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(CardColorPickerPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }
  }

  static const List<Color> _textColors = [
    Color(0xFFFFFFFF), // Branco puro
    Color(0xFFE2E8F0), // Cinza claro
    Color(0xFF00E1FF), // Aurora Cyan
    Color(0xFF38BDF8), // Sky Blue
    Color(0xFF818CF8), // Indigo
    Color(0xFFA78BFA), // Purple
    Color(0xFFF472B6), // Pink
    Color(0xFFFB7185), // Rose
    Color(0xFFF87171), // Red
    Color(0xFFFB923C), // Orange
    Color(0xFFFACC15), // Amber
    Color(0xFF4ADE80), // Emerald
    Color(0xFF2DD4BF), // Teal
    Color(0xFF94A3B8), // Slate
    Color(0xFF475569), // Dark Slate
    Color(0xFF0F172A), // Dark Navy
  ];

  static const List<Map<String, dynamic>> _highlightColors = [
    {'label': 'Nenhum', 'color': null},
    {'label': 'Amarelo', 'color': Color(0x66FACC15)},
    {'label': 'Ciano', 'color': Color(0x6600E1FF)},
    {'label': 'Verde', 'color': Color(0x664ADE80)},
    {'label': 'Laranja', 'color': Color(0x66FB923C)},
    {'label': 'Rosa', 'color': Color(0x66F472B6)},
    {'label': 'Roxo', 'color': Color(0x66A78BFA)},
    {'label': 'Azul', 'color': Color(0x6638BDF8)},
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final themeAccent = MoscaroTokens.auroraBlue;
    final glassTint = MoscaroTokens.glassTint;
    final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;

    return Container(
      width: widget.maxWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho com Abas e Fechar
          Row(
            children: [
              SvgIcon(
                name: _mode == ColorPickerMode.textColor ? 'palette' : 'brush',
                size: 15,
                color: themeAccent,
              ),
              const SizedBox(width: 8),
              // Segmented Tabs
              Expanded(
                child: Row(
                  children: [
                    _buildModeButton(
                      mode: ColorPickerMode.textColor,
                      label: 'Cor do Texto',
                      themeAccent: themeAccent,
                      textPrimary: textPrimary,
                    ),
                    const SizedBox(width: 4),
                    _buildModeButton(
                      mode: ColorPickerMode.highlightColor,
                      label: 'Marca-texto',
                      themeAccent: themeAccent,
                      textPrimary: textPrimary,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SvgIcon(
                    name: 'close',
                    size: 13,
                    color: textPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),
          // Swatches Grid
          if (_mode == ColorPickerMode.textColor)
            _buildTextColorsGrid(themeAccent)
          else
            _buildHighlightColorsGrid(themeAccent, isLight),
        ],
      ),
    ).moscaroV2(
      borderRadius: 16,
      blurSigma: blur,
      enableBlur: blur > 0,
      backgroundColor: isLight
          ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
          : glassTint,
      borderColor: isLight ? MoscaroTokens.borderSubtle : MoscaroTokens.borderGlow,
      borderWidth: 1.0,
      padding: EdgeInsets.zero,
      customShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required ColorPickerMode mode,
    required String label,
    required Color themeAccent,
    required Color textPrimary,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? themeAccent.withValues(alpha: 0.45)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? themeAccent : textPrimary.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTextColorsGrid(Color themeAccent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _textColors.map((color) {
        final isSelected = widget.currentTextColor?.toARGB32() == color.toARGB32();
        return InkWell(
          onTap: () => widget.onSelectTextColor(color),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? themeAccent : Colors.white.withValues(alpha: 0.25),
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: themeAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Center(
                    child: SvgIcon(
                      name: 'check',
                      size: 14,
                      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHighlightColorsGrid(Color themeAccent, bool isLight) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _highlightColors.map((item) {
        final color = item['color'] as Color?;
        final label = item['label'] as String;
        final isSelected = (color == null && widget.currentHighlightColor == null) ||
            (color != null && widget.currentHighlightColor?.toARGB32() == color.toARGB32());

        return InkWell(
          onTap: () => widget.onSelectHighlightColor(color),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color ?? (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? themeAccent : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (color == null)
                  SvgIcon(name: 'close', size: 12, color: MoscaroTokens.textPrimary.withValues(alpha: 0.6))
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isSelected ? themeAccent : MoscaroTokens.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
