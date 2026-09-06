import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/moscaro_theme_controller.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_v2_tokens.dart';
import 'svg_icon.dart';

/// Modal Lightbox Moscaro Fullscreen com zoom/pan livre até 5x e opções de salvar imagem.
class MediaLightboxModal extends StatefulWidget {
  final String? mediaData;
  final String title;

  const MediaLightboxModal({
    super.key,
    required this.mediaData,
    this.title = 'Visualização de Mídia',
  });

  /// Método estático conveniente para exibir o modal
  static Future<void> show(BuildContext context, {required String? mediaData, String title = 'Visualização de Mídia'}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      barrierDismissible: true,
      builder: (ctx) => MediaLightboxModal(mediaData: mediaData, title: title),
    );
  }

  @override
  State<MediaLightboxModal> createState() => _MediaLightboxModalState();
}

class _MediaLightboxModalState extends State<MediaLightboxModal> {
  final TransformationController _transformController = TransformationController();

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  Widget _buildImage() {
    if (widget.mediaData == null || widget.mediaData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(assetName: 'image', size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Nenhuma imagem disponível', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final data = widget.mediaData!;
    if (data.startsWith('data:image/') || data.length > 500 && !data.startsWith('/')) {
      try {
        final cleanBase64 = data.contains(',') ? data.split(',')[1] : data;
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 48),
        );
      } catch (_) {}
    }

    return Image.file(
      File(data),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          // Área Central Interativa (Pan & Zoom + Fechar ao clicar fora)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              onDoubleTap: _resetZoom,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 6.0,
                boundaryMargin: const EdgeInsets.all(120),
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // Protege a imagem contra fechamento ao clicar nela
                    child: Hero(
                      tag: 'lightbox_${widget.mediaData?.hashCode ?? 0}',
                      child: _buildImage(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Barra Superior de Controles Estilo Moscaro
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Título e Dica
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SvgIcon(assetName: 'image', size: 16, color: theme.accentPrimary),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Role para zoom • Duplo clique para resetar',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ).moscaroV2(
                  backgroundColor: theme.backgroundSurface.withValues(alpha: 0.85),
                  borderColor: theme.accentPrimary.withValues(alpha: 0.3),
                  borderRadius: 16,
                  enableBlur: true,
                ),

                // Botões de Ação (Resetar Zoom e Fechar)
                Row(
                  children: [
                    _LightboxActionButton(
                      tooltip: 'Resetar Zoom',
                      iconName: 'restore',
                      onTap: _resetZoom,
                    ),
                    const SizedBox(width: 10),
                    _LightboxActionButton(
                      tooltip: 'Fechar (Esc)',
                      iconName: 'close',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LightboxActionButton extends StatelessWidget {
  final String tooltip;
  final String iconName;
  final VoidCallback onTap;

  const _LightboxActionButton({
    required this.tooltip,
    required this.iconName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: SvgIcon(assetName: iconName, size: 16, color: Colors.white),
        ).moscaroV2(
          backgroundColor: theme.backgroundSurface.withValues(alpha: 0.85),
          borderColor: theme.accentPrimary.withValues(alpha: 0.3),
          borderRadius: 18,
          enableBlur: true,
        ),
      ),
    );
  }
}
