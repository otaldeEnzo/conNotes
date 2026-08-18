import 'package:flutter/material.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';

/// HUD de Navegação e Zoom do Canvas no formato Pílula Moscaro v2 (Adaptativo Dark/Light).
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
    final textPrimary = MoscaroTokens.textPrimary;
    final iconColor = MoscaroTokens.iconInactive;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão Menos (-)
          IconButton(
            icon: Icon(Icons.remove, size: 16, color: iconColor),
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
                style: TextStyle(
                  color: textPrimary,
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
            icon: Icon(Icons.add, size: 16, color: iconColor),
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
