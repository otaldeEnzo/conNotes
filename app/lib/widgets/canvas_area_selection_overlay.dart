import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_extension.dart';
import 'svg_icon.dart';

/// Overlay de seleção de área do canvas para análise multimodal pela IA.
/// Apresenta um fundo translúcido escuro e permite arrastar um retângulo de seleção
/// com bordas neon ciano brilhantes. Ao soltar, dispara `onAreaSelected(rect)`.
class CanvasAreaSelectionOverlay extends StatefulWidget {
  final ValueChanged<Rect> onAreaSelected;
  final VoidCallback onCancel;

  const CanvasAreaSelectionOverlay({
    super.key,
    required this.onAreaSelected,
    required this.onCancel,
  });

  @override
  State<CanvasAreaSelectionOverlay> createState() => _CanvasAreaSelectionOverlayState();
}

class _CanvasAreaSelectionOverlayState extends State<CanvasAreaSelectionOverlay> {
  Offset? _startPoint;
  Offset? _currentPoint;

  Rect? get _selectionRect {
    if (_startPoint == null || _currentPoint == null) return null;
    return Rect.fromPoints(_startPoint!, _currentPoint!);
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _startPoint = details.localPosition;
      _currentPoint = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoint = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final rect = _selectionRect;
    if (rect != null && rect.width > 20 && rect.height > 20) {
      widget.onAreaSelected(rect);
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    const seaWashGreen = Color(0xFF2EE59D);
    final rect = _selectionRect;

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // Sem overlay escurecido para não obscurecer o canvas subjacente
            const Positioned.fill(
              child: SizedBox.shrink(),
            ),

            // Retângulo de Seleção Neon Sea Wash Green com Brilho
            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                child: Container(
                  decoration: BoxDecoration(
                    color: seaWashGreen.withValues(alpha: 0.2),
                    border: Border.all(
                      color: seaWashGreen,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: seaWashGreen.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D1117), // Fundo dark glass
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: seaWashGreen.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: seaWashGreen.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        '${rect.width.round()} x ${rect.height.round()} px',
                        style: const TextStyle(
                          color: seaWashGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Pílula Superior de Instruções (Estilo Moscaro)
            Positioned(
              top: 36,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SvgIcon(assetName: 'crop', size: 16, color: seaWashGreen),
                      const SizedBox(width: 10),
                      const Text(
                        'Arraste para selecionar a área do canvas para a IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: widget.onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Cancelar (Esc)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).moscaroV2(
                  backgroundColor: theme.backgroundSurface.withValues(alpha: 0.9),
                  borderColor: seaWashGreen.withValues(alpha: 0.45),
                  borderRadius: 20,
                  enableBlur: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
