import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import 'ink_models.dart';

/// Editor de Caneta de Alta Precisão (Auto-Save instantâneo, Switch compacto, Matriz 2D).
class PrecisionColorPicker extends StatefulWidget {
  final PenSlotPreset initialPreset;
  final bool canDelete;
  final ValueChanged<PenSlotPreset> onChange;
  final VoidCallback onDelete;

  const PrecisionColorPicker({
    super.key,
    required this.initialPreset,
    required this.canDelete,
    required this.onChange,
    required this.onDelete,
  });

  @override
  State<PrecisionColorPicker> createState() => _PrecisionColorPickerState();
}

class _PrecisionColorPickerState extends State<PrecisionColorPicker> {
  late Color _currentColor;
  late double _strokeWidth;
  late InkToolType _toolType;
  late bool _enablePressure;

  late double _hue;
  late double _saturation;
  late double _value;

  final TextEditingController _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialPreset.color;
    _strokeWidth = widget.initialPreset.strokeWidth;
    _toolType = widget.initialPreset.toolType;
    _enablePressure = widget.initialPreset.enablePressure;

    final hsv = HSVColor.fromColor(_currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;

    _hexController.text = _colorToHex(_currentColor);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  void _notifyChange() {
    final updated = widget.initialPreset.copyWith(
      color: _currentColor,
      strokeWidth: _strokeWidth,
      toolType: _toolType,
      enablePressure: _enablePressure,
    );
    widget.onChange(updated);
  }

  void _updateColorFromHSV() {
    final newColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    setState(() {
      _currentColor = newColor;
      _hexController.text = _colorToHex(newColor);
    });
    _notifyChange();
  }

  void _updateColorFromHex(String hexText) {
    String cleanHex = hexText.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final int? intVal = int.tryParse(cleanHex, radix: 16);
      if (intVal != null) {
        final newColor = Color(0xFF000000 | intVal);
        final hsv = HSVColor.fromColor(newColor);
        setState(() {
          _currentColor = newColor;
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
        _notifyChange();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho com Preview e botão de deletar slot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: _currentColor.withOpacity(0.6), blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ajustar Caneta',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (widget.canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: MoscaroTokens.auroraPink, size: 18),
                  onPressed: widget.onDelete,
                  tooltip: 'Remover Slot',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 8),

          // 2. Seletor do Tipo de Ferramenta
          const Text('Tipo de Ferramenta', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildToolTypeButton('Técnica', InkToolType.technical, Icons.edit),
              _buildToolTypeButton('Tinteiro', InkToolType.fountain, Icons.brush),
              _buildToolTypeButton('Lápis', InkToolType.pencil, Icons.create),
              _buildToolTypeButton('Marca', InkToolType.highlighter, Icons.highlight),
            ],
          ),
          const SizedBox(height: 8),

          // Toggle de Sensibilidade a Pressão (Proporcional e Compacto com Transform.scale)
          if (_toolType == InkToolType.technical)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sensibilidade à Pressão', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Transform.scale(
                  scale: 0.72, // Reduzido o switch para proporções elegantes e proporcionais ao texto
                  child: Switch(
                    value: _enablePressure,
                    activeColor: MoscaroTokens.auroraBlue,
                    onChanged: (val) {
                      setState(() => _enablePressure = val);
                      _notifyChange();
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 4),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 8),

          // 3. Matriz 2D de Alta Precisão (Saturação x Brilho)
          const Text('Espectro de Precisão 2D', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          _build2DColorMatrix(),
          const SizedBox(height: 8),

          // 4. Slider de Matiz (Hue)
          _buildHueSlider(),
          const SizedBox(height: 8),

          // 5. Paleta Rápida STEM & Campo de Código HEX
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: MoscaroTokens.stemPalette.map((col) {
                    return GestureDetector(
                      onTap: () {
                        final hsv = HSVColor.fromColor(col);
                        setState(() {
                          _currentColor = col;
                          _hue = hsv.hue;
                          _saturation = hsv.saturation;
                          _value = hsv.value;
                          _hexController.text = _colorToHex(col);
                        });
                        _notifyChange();
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 75,
                height: 26,
                child: TextField(
                  controller: _hexController,
                  onChanged: _updateColorFromHex,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 8),

          // 6. Espessura do Traço
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Espessura', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('${_strokeWidth.toStringAsFixed(1)} px', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              thumbColor: MoscaroTokens.auroraBlue,
              activeTrackColor: MoscaroTokens.auroraBlue,
              inactiveTrackColor: Colors.white12,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _strokeWidth,
              min: 1.0,
              max: 16.0,
              onChanged: (val) {
                setState(() => _strokeWidth = val);
                _notifyChange();
              },
            ),
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      borderWidth: 1.2,
    );
  }

  Widget _buildToolTypeButton(String label, InkToolType type, IconData icon) {
    final isSelected = _toolType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _toolType = type);
        _notifyChange();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MoscaroTokens.auroraBlue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MoscaroTokens.auroraBlue : Colors.white12,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? MoscaroTokens.auroraBlue : Colors.white60),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2DColorMatrix() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double height = 85.0;
        final baseColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

        return GestureDetector(
          onPanDown: (details) => _handleMatrixGesture(details.localPosition, width, height),
          onPanUpdate: (details) => _handleMatrixGesture(details.localPosition, width, height),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24, width: 1.0),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, baseColor],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
              child: CustomPaint(
                painter: _MatrixCursorPainter(
                  saturation: _saturation,
                  value: _value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMatrixGesture(Offset localPosition, double width, double height) {
    final double sat = (localPosition.dx / width).clamp(0.0, 1.0);
    final double val = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);

    setState(() {
      _saturation = sat;
      _value = val;
    });
    _updateColorFromHSV();
  }

  Widget _buildHueSlider() {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
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
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 12,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          thumbColor: Colors.white,
          overlayShape: SliderComponentShape.noOverlay,
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
        ),
        child: Slider(
          value: _hue,
          min: 0.0,
          max: 360.0,
          onChanged: (val) {
            setState(() {
              _hue = val;
            });
            _updateColorFromHSV();
          },
        ),
      ),
    );
  }
}

class _MatrixCursorPainter extends CustomPainter {
  final double saturation;
  final double value;

  _MatrixCursorPainter({
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double x = saturation * size.width;
    final double y = (1.0 - value) * size.height;

    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(x, y), 6.0, cursorPaint);
    canvas.drawCircle(Offset(x, y), 7.0, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant _MatrixCursorPainter oldDelegate) {
    return oldDelegate.saturation != saturation || oldDelegate.value != value;
  }
}
