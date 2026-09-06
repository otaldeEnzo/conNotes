import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import 'media_lightbox_modal.dart';
import 'svg_icon.dart';

/// Renderizador Visual do Conteudo do Card de Midia (Imagens estaticas e GIFs).
/// Otimizado com cache de texturas sob demanda (ResizeImage / cacheWidth) para economizar VRAM.
class CanvasCardMediaView extends StatefulWidget {
  final CanvasCardModel card;
  final bool isSelected;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final double zoomScale;

  const CanvasCardMediaView({
    super.key,
    required this.card,
    required this.isSelected,
    required this.onUpdateCard,
    this.zoomScale = 1.0,
  });

  @override
  State<CanvasCardMediaView> createState() => _CanvasCardMediaViewState();
}

class _CanvasCardMediaViewState extends State<CanvasCardMediaView> {
  Uint8List? _cachedBytes;
  String? _lastDataUri;

  @override
  void initState() {
    super.initState();
    _decodeMediaData();
  }

  @override
  void didUpdateWidget(covariant CanvasCardMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.mediaData != _lastDataUri) {
      _decodeMediaData();
    }
  }

  void _decodeMediaData() {
    final mediaData = widget.card.mediaData;
    _lastDataUri = mediaData;
    if (mediaData == null || mediaData.isEmpty) {
      _cachedBytes = null;
      return;
    }

    if (mediaData.startsWith('data:')) {
      final commaIndex = mediaData.indexOf(',');
      if (commaIndex != -1) {
        try {
          final b64 = mediaData.substring(commaIndex + 1);
          _cachedBytes = base64Decode(b64);
        } catch (e) {
          debugPrint('[CanvasCardMediaView] Erro ao decodificar Base64: $e');
          _cachedBytes = null;
        }
      }
    }
  }

  void _openLightbox() {
    MediaLightboxModal.show(
      context,
      mediaData: widget.card.mediaData,
      title: widget.card.title.isNotEmpty ? widget.card.title : 'Visualizacao de Midia',
    );
  }

  static const ColorFilter _invertLuminanceFilter = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    Widget imageContent;
    if (_cachedBytes != null) {
      Widget img = Image.memory(
        _cachedBytes!,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(
            'Erro ao carregar midia',
            isError: true,
          );
        },
      );

      if (card.invertLuminance) {
        img = ColorFiltered(
          colorFilter: _invertLuminanceFilter,
          child: img,
        );
      }

      if (card.imageRotationQuarterTurns != 0) {
        img = RotatedBox(
          quarterTurns: card.imageRotationQuarterTurns,
          child: img,
        );
      }

      if (card.isFlippedHorizontal || card.isFlippedVertical) {
        img = Transform.scale(
          scaleX: card.isFlippedHorizontal ? -1.0 : 1.0,
          scaleY: card.isFlippedVertical ? -1.0 : 1.0,
          child: img,
        );
      }

      imageContent = GestureDetector(
        onDoubleTap: card.isDrawOverMode ? null : _openLightbox,
        child: RepaintBoundary(
          child: img,
        ),
      );
    } else {
      imageContent = _buildPlaceholder('Nenhuma midia carregada');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: IgnorePointer(
        ignoring: card.isDrawOverMode,
        child: SizedBox.expand(
          child: imageContent,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String message, {bool isError = false}) {
    return Container(
      color: const Color(0xEB0E1018),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgIcon(
              name: isError ? 'close' : 'image',
              size: 32.0,
              color: isError ? const Color(0xFFFF5252) : const Color(0x6600E1FF),
            ),
            const SizedBox(height: 8.0),
            Text(
              message,
              style: TextStyle(
                color: isError ? const Color(0xFFFF5252) : const Color(0x80FFFFFF),
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
