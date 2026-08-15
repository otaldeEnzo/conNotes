import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';

/// HUD de Navegação e Zoom do Canvas no formato Pílula Moscaro v2.
/// Fica posicionado no topo superior direito, alinhado com a TabBar sem sobreposição.
class ZoomHudPill extends StatelessWidget {
  final double zoomScale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  const ZoomHudPill({
    super.key,
    required this.zoomScale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    final int percentage = (zoomScale * 100).round();

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão Menos (-)
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
            onPressed: onZoomOut,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'Reduzir Zoom (Ctrl + Scroll)',
          ),
          const SizedBox(width: 2),
          // Porcentagem clicável (Reseta para 100%)
          InkWell(
            onTap: onResetZoom,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Botão Mais (+)
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Colors.white70),
            onPressed: onZoomIn,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'Aumentar Zoom (Ctrl + Scroll)',
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: MoscaroTokens.radiusPill,
      padding: EdgeInsets.zero,
    );
  }
}
