import 'dart:ui';
import 'package:flutter/material.dart';

/// Mini-Barra Flutuante de Seleção de Texto (Estilo Google Docs / Medium / Craft).
class CardSelectionFloatingBubble extends StatefulWidget {
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final VoidCallback onToggleSubscript;
  final VoidCallback onToggleSuperscript;
  final ValueChanged<Color> onApplyTextColor;
  final ValueChanged<Color> onApplyHighlightColor;
  final VoidCallback onWrapLatexInline;
  final VoidCallback onClearFormatting;
  final bool isLight;
  final Color themeAccent;
  final Color textPrimary;
  final double blur;

  const CardSelectionFloatingBubble({
    super.key,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onToggleSubscript,
    required this.onToggleSuperscript,
    required this.onApplyTextColor,
    required this.onApplyHighlightColor,
    required this.onWrapLatexInline,
    required this.onClearFormatting,
    required this.isLight,
    required this.themeAccent,
    required this.textPrimary,
    required this.blur,
  });

  @override
  State<CardSelectionFloatingBubble> createState() => _CardSelectionFloatingBubbleState();
}

class _CardSelectionFloatingBubbleState extends State<CardSelectionFloatingBubble> {
  bool _isColorPickerOpen = false;
  bool _isHighlightPickerOpen = false;

  static const List<Color> _textColors = [
    Color(0xFFFFFFFF),
    Color(0xFF00E1FF),
    Color(0xFFA855F7),
    Color(0xFFFF007A),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const List<Color> _highlightColors = [
    Color(0xFFFACC15),
    Color(0xFF00E1FF),
    Color(0xFF10B981),
    Color(0xFFFF007A),
    Color(0xFFFB923C),
    Color(0xFFA855F7),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isColorPickerOpen) ...[
          _buildMiniPalette(
            colors: _textColors,
            onPick: (c) {
              widget.onApplyTextColor(c);
              setState(() => _isColorPickerOpen = false);
            },
          ),
          const SizedBox(height: 4),
        ],
        if (_isHighlightPickerOpen) ...[
          _buildMiniPalette(
            colors: _highlightColors,
            onPick: (c) {
              widget.onApplyHighlightColor(c);
              setState(() => _isHighlightPickerOpen = false);
            },
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: widget.blur > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blur,
                    sigmaY: widget.blur,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isLight
                          ? Colors.white.withValues(alpha: 0.94)
                          : const Color(0xFF0D121E).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.themeAccent.withValues(alpha: 0.45),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBubbleButton(
                          icon: Icons.format_bold_rounded,
                          tooltip: 'Negrito',
                          onTap: widget.onToggleBold,
                        ),
                        _buildBubbleButton(
                          icon: Icons.format_italic_rounded,
                          tooltip: 'Itálico',
                          onTap: widget.onToggleItalic,
                        ),
                        _buildBubbleButton(
                          icon: Icons.format_underlined_rounded,
                          tooltip: 'Sublinhado',
                          onTap: widget.onToggleUnderline,
                        ),
                        _buildBubbleButton(
                          icon: Icons.subscript_rounded,
                          tooltip: 'Subscrito (x₂)',
                          onTap: widget.onToggleSubscript,
                        ),
                        _buildBubbleButton(
                          icon: Icons.superscript_rounded,
                          tooltip: 'Sobrescrito (x²)',
                          onTap: widget.onToggleSuperscript,
                        ),
                        Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 2)),
                        _buildBubbleButton(
                          icon: Icons.format_color_text_rounded,
                          tooltip: 'Cor do Texto',
                          isActive: _isColorPickerOpen,
                          onTap: () => setState(() {
                            _isColorPickerOpen = !_isColorPickerOpen;
                            _isHighlightPickerOpen = false;
                          }),
                        ),
                        _buildBubbleButton(
                          icon: Icons.highlight_rounded,
                          tooltip: 'Cor do Marca-Texto',
                          isActive: _isHighlightPickerOpen,
                          onTap: () => setState(() {
                            _isHighlightPickerOpen = !_isHighlightPickerOpen;
                            _isColorPickerOpen = false;
                          }),
                        ),
                        _buildBubbleButton(
                          icon: Icons.functions_rounded,
                          tooltip: 'Fórmula Inline (\$...\$)',
                          onTap: widget.onWrapLatexInline,
                        ),
                        _buildBubbleButton(
                          icon: Icons.format_clear_rounded,
                          tooltip: 'Limpar Formatação',
                          onTap: widget.onClearFormatting,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isLight
                        ? Colors.white.withValues(alpha: 0.94)
                        : const Color(0xFF0D121E).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.themeAccent.withValues(alpha: 0.45),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBubbleButton(
                        icon: Icons.format_bold_rounded,
                        tooltip: 'Negrito',
                        onTap: widget.onToggleBold,
                      ),
                      _buildBubbleButton(
                        icon: Icons.format_italic_rounded,
                        tooltip: 'Itálico',
                        onTap: widget.onToggleItalic,
                      ),
                      _buildBubbleButton(
                        icon: Icons.format_underlined_rounded,
                        tooltip: 'Sublinhado',
                        onTap: widget.onToggleUnderline,
                      ),
                      _buildBubbleButton(
                        icon: Icons.subscript_rounded,
                        tooltip: 'Subscrito (x₂)',
                        onTap: widget.onToggleSubscript,
                      ),
                      _buildBubbleButton(
                        icon: Icons.superscript_rounded,
                        tooltip: 'Sobrescrito (x²)',
                        onTap: widget.onToggleSuperscript,
                      ),
                      Container(width: 1, height: 16, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 2)),
                      _buildBubbleButton(
                        icon: Icons.format_color_text_rounded,
                        tooltip: 'Cor do Texto',
                        isActive: _isColorPickerOpen,
                        onTap: () => setState(() {
                          _isColorPickerOpen = !_isColorPickerOpen;
                          _isHighlightPickerOpen = false;
                        }),
                      ),
                      _buildBubbleButton(
                        icon: Icons.highlight_rounded,
                        tooltip: 'Cor do Marca-Texto',
                        isActive: _isHighlightPickerOpen,
                        onTap: () => setState(() {
                          _isHighlightPickerOpen = !_isHighlightPickerOpen;
                          _isColorPickerOpen = false;
                        }),
                      ),
                      _buildBubbleButton(
                        icon: Icons.functions_rounded,
                        tooltip: 'Fórmula Inline (\$...\$)',
                        onTap: widget.onWrapLatexInline,
                      ),
                      _buildBubbleButton(
                        icon: Icons.format_clear_rounded,
                        tooltip: 'Limpar Formatação',
                        onTap: widget.onClearFormatting,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMiniPalette({
    required List<Color> colors,
    required ValueChanged<Color> onPick,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isLight ? Colors.white : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.themeAccent.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: colors.map((c) {
            return InkWell(
              onTap: () => onPick(c),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white38, width: 0.8),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBubbleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive ? widget.themeAccent.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? widget.themeAccent : widget.textPrimary,
          ),
        ),
      ),
    );
  }
}
