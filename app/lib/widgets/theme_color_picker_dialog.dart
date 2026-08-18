import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';

/// Diálogo Moscaro de Alta Precisão para Seleção de Cores com Efeito de Vidro Líquido Real.
class ThemeColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initialColor;
  final bool allowAlpha;
  final ValueChanged<Color> onColorChanged;

  const ThemeColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColor,
    this.allowAlpha = false,
    required this.onColorChanged,
  });

  static void show({
    required BuildContext context,
    required String title,
    required Color initialColor,
    bool allowAlpha = false,
    required ValueChanged<Color> onColorChanged,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => ThemeColorPickerDialog(
        title: title,
        initialColor: initialColor,
        allowAlpha: allowAlpha,
        onColorChanged: onColorChanged,
      ),
    );
  }

  @override
  State<ThemeColorPickerDialog> createState() => _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<ThemeColorPickerDialog> {
  late Color _currentColor;
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    final hsv = HSVColor.fromColor(_currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _alpha = _currentColor.a;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    if (widget.allowAlpha) {
      return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _updateFromHsv() {
    final base = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    _currentColor = base.withValues(alpha: widget.allowAlpha ? _alpha : 1.0);
    _hexController.text = _colorToHex(_currentColor);
    widget.onColorChanged(_currentColor);
    setState(() {});
  }

  void _parseHex(String val) {
    try {
      final clean = val.replaceAll('#', '').replaceAll('0x', '');
      if (clean.length == 6) {
        final col = Color(int.parse('FF$clean', radix: 16));
        final hsv = HSVColor.fromColor(col);
        _hue = hsv.hue;
        _saturation = hsv.saturation;
        _value = hsv.value;
        _currentColor = col.withValues(alpha: widget.allowAlpha ? _alpha : 1.0);
        widget.onColorChanged(_currentColor);
        setState(() {});
      } else if (clean.length == 8 && widget.allowAlpha) {
        final col = Color(int.parse(clean, radix: 16));
        final hsv = HSVColor.fromColor(col);
        _hue = hsv.hue;
        _saturation = hsv.saturation;
        _value = hsv.value;
        _alpha = col.a;
        _currentColor = col;
        widget.onColorChanged(_currentColor);
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (Título Protegido contra Overflow + Preview da Cor)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MoscaroTokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 1. Matriz 2D Saturação / Valor (HSV)
            SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GestureDetector(
                      onPanDown: (details) => _handleSatVal(details.localPosition, constraints.biggest),
                      onPanUpdate: (details) => _handleSatVal(details.localPosition, constraints.biggest),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.white, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (_saturation * constraints.maxWidth) - 8,
                            top: ((1.0 - _value) * constraints.maxHeight) - 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Slider de Matiz (Rainbow Hue)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GestureDetector(
                      onPanDown: (details) => _handleHue(details.localPosition, constraints.maxWidth),
                      onPanUpdate: (details) => _handleHue(details.localPosition, constraints.maxWidth),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (_hue / 360.0 * constraints.maxWidth) - 6,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black26),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Slider de Opacidade (se permitido)
            if (widget.allowAlpha) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Opacidade:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: MoscaroTokens.auroraBlue,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _alpha,
                        min: 0.05,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            _alpha = val;
                            _currentColor = _currentColor.withValues(alpha: _alpha);
                            _hexController.text = _colorToHex(_currentColor);
                          });
                          widget.onColorChanged(_currentColor);
                        },
                      ),
                    ),
                  ),
                  Text('${(_alpha * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // 4. Input Hexadecimal
            Row(
              children: [
                const Text('HEX:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _parseHex,
                    onChanged: _parseHex,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Botão Concluir
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.2),
                  foregroundColor: MoscaroTokens.auroraBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: MoscaroTokens.auroraBlue),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Concluir'),
              ),
            ),
          ],
        ),
      ).moscaroV2(
        borderRadius: 20,
        enableBlur: MoscaroTokens.enableModalsBlur,
        borderColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.5),
        borderWidth: 1.2,
      ),
    );
  }

  void _handleSatVal(Offset localPos, Size size) {
    final s = (localPos.dx / size.width).clamp(0.0, 1.0);
    final v = (1.0 - (localPos.dy / size.height)).clamp(0.0, 1.0);
    _saturation = s;
    _value = v;
    _updateFromHsv();
  }

  void _handleHue(Offset localPos, double width) {
    final h = ((localPos.dx / width).clamp(0.0, 1.0)) * 360.0;
    _hue = h % 360.0;
    _updateFromHsv();
  }
}
