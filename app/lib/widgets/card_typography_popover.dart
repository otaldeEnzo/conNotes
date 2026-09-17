import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../services/custom_font_manager.dart';
import 'svg_icon.dart';

/// Popover de Tipografia (Família de Fonte e Tamanho) no padrão Moscaro v2.
class CardTypographyPopover extends StatefulWidget {
  final String currentFontFamily;
  final double currentFontSize;
  final ValueChanged<String> onSelectFontFamily;
  final ValueChanged<double> onSelectFontSize;
  final VoidCallback onClose;
  final double maxWidth;

  const CardTypographyPopover({
    super.key,
    required this.currentFontFamily,
    required this.currentFontSize,
    required this.onSelectFontFamily,
    required this.onSelectFontSize,
    required this.onClose,
    this.maxWidth = 320.0,
  });

  @override
  State<CardTypographyPopover> createState() => _CardTypographyPopoverState();
}

class _CardTypographyPopoverState extends State<CardTypographyPopover> {
  static const List<double> _quickSizes = [10, 12, 14, 16, 18, 20, 24, 32, 48];
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.currentFontSize;
  }

  @override
  void didUpdateWidget(covariant CardTypographyPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentFontSize != widget.currentFontSize) {
      _fontSize = widget.currentFontSize;
    }
  }

  void _changeSize(double delta) {
    final newSize = (_fontSize + delta).clamp(6.0, 120.0);
    setState(() => _fontSize = newSize);
    widget.onSelectFontSize(newSize);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = MoscaroTokens.textPrimary;
    final themeAccent = MoscaroTokens.auroraBlue;
    final glassTint = MoscaroTokens.glassTint;
    final blur = (MoscaroTokens.enableSubBarsBlur && MoscaroTokens.blurSigma > 0)
        ? MoscaroTokens.blurSigma
        : 0.0;
    final availableFonts = CustomFontManager.instance.availableFonts;

    return Container(
      width: widget.maxWidth,
      constraints: const BoxConstraints(maxHeight: 360),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgIcon(name: 'edit', size: 15, color: themeAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Tipografia',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 8),

          // Seção de Tamanho de Fonte
          Row(
            children: [
              Text(
                'Tamanho',
                style: TextStyle(
                  color: textPrimary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Botão Decrementar
              InkWell(
                onTap: () => _changeSize(-1),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isLight ? 0.05 : 0.07),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isLight ? MoscaroTokens.borderSubtle : Colors.white.withValues(alpha: 0.1),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 38,
                alignment: Alignment.center,
                child: Text(
                  '${_fontSize.round()}pt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Botão Incrementar
              InkWell(
                onTap: () => _changeSize(1),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isLight ? 0.05 : 0.07),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isLight ? MoscaroTokens.borderSubtle : Colors.white.withValues(alpha: 0.1),
                      width: 0.8,
                    ),
                  ),
                  child: SvgIcon(name: 'plus', size: 10, color: textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Chips de tamanhos rápidos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickSizes.map((size) {
                final isSelected = _fontSize.round() == size.round();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() => _fontSize = size);
                      widget.onSelectFontSize(size);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeAccent.withValues(alpha: 0.2)
                            : (isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? themeAccent : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${size.round()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? themeAccent : textPrimary.withValues(alpha: 0.7),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 6),

          // Seção Família de Fonte
          Text(
            'Família da Fonte',
            style: TextStyle(
              color: textPrimary.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: availableFonts.length,
              itemBuilder: (context, index) {
                final font = availableFonts[index];
                final isSelected = widget.currentFontFamily.toLowerCase() == font.toLowerCase();

                return InkWell(
                  onTap: () => widget.onSelectFontFamily(font),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeAccent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? themeAccent.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          font,
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 12,
                            color: isSelected ? themeAccent : textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isSelected)
                          SvgIcon(name: 'check', size: 13, color: themeAccent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
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
}
