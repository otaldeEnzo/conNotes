import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/canvas_card_model.dart';
import 'media_lightbox_modal.dart';
import 'svg_icon.dart';
import 'ink_models.dart';
import 'canvas_layers.dart';

/// Renderizador Visual do Conteudo do Card de Midia (Imagens estaticas e GIFs).
/// Otimizado com cache de texturas sob demanda (ResizeImage / cacheWidth) para economizar VRAM.
class CanvasCardMediaView extends StatefulWidget {
  final CanvasCardModel card;
  final bool isSelected;
  final ValueChanged<CanvasCardModel> onUpdateCard;
  final double zoomScale;
  final List<InkStroke> Function(Set<String> ids)? getAttachedStrokes;
  final String activeTool;
  final void Function(List<InkStroke> finalStrokes, String cardId)? onSyncCardStrokes;

  const CanvasCardMediaView({
    super.key,
    required this.card,
    required this.isSelected,
    required this.onUpdateCard,
    this.zoomScale = 1.0,
    this.getAttachedStrokes,
    this.activeTool = 'pen',
    this.onSyncCardStrokes,
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

  static final Map<String, Uint8List> _globalMediaCache = {};

  void _decodeMediaData() {
    final mediaData = widget.card.mediaData;
    _lastDataUri = mediaData;
    if (mediaData == null || mediaData.isEmpty) {
      _cachedBytes = null;
      return;
    }

    if (_globalMediaCache.containsKey(mediaData)) {
      _cachedBytes = _globalMediaCache[mediaData];
      return;
    }

    if (mediaData.startsWith('data:')) {
      final commaIndex = mediaData.indexOf(',');
      if (commaIndex != -1) {
        try {
          final b64 = mediaData.substring(commaIndex + 1);
          _cachedBytes = base64Decode(b64);
          _globalMediaCache[mediaData] = _cachedBytes!;
        } catch (e) {
          debugPrint('[CanvasCardMediaView] Erro ao decodificar Base64: $e');
          _cachedBytes = null;
        }
      }
    }
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

      imageContent = RepaintBoundary(
        child: img,
      );
    } else {
      imageContent = _buildPlaceholder('Nenhuma midia carregada');
    }

    final attachedStrokes = widget.getAttachedStrokes != null && card.attachedStrokeIds.isNotEmpty
        ? widget.getAttachedStrokes!(card.attachedStrokeIds.toSet())
        : <InkStroke>[];

    Widget finalContent = imageContent;
    if (attachedStrokes.isNotEmpty) {
      finalContent = Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _CardMediaStrokesPainter(
                  strokes: attachedStrokes,
                  cardX: card.x,
                  cardY: card.y,
                  baseWidth: card.width,
                  baseHeight: card.height,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: SizedBox.expand(
        child: finalContent,
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

class _CardMediaStrokesPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final double cardX;
  final double cardY;
  final double baseWidth;
  final double baseHeight;
  final Paint _reusablePaint = Paint();

  _CardMediaStrokesPainter({
    required this.strokes,
    required this.cardX,
    required this.cardY,
    required this.baseWidth,
    required this.baseHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    
    final actualBaseHeight = math.max(1.0, baseHeight - 28.0);
    final scaleX = (baseWidth > 0 && size.width > 0) ? (size.width / baseWidth) : 1.0;
    final scaleY = (actualBaseHeight > 0 && size.height > 0) ? (size.height / actualBaseHeight) : 1.0;

    canvas.save();
    if (scaleX != 1.0 || scaleY != 1.0) {
      canvas.scale(scaleX, scaleY);
    }
    // O corpo da imagem do card começa em cardY + 28.0 por conta do cabeçalho de 28px
    canvas.translate(-cardX, -(cardY + 28.0));

    // 1. Marca-textos primeiro
    for (final s in strokes) {
      if (s.toolType == InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _reusablePaint);
      }
    }

    // 2. Traços regulares
    for (final s in strokes) {
      if (s.toolType != InkToolType.highlighter) {
        StrokePictureCache.drawSingleStroke(canvas, s, _reusablePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardMediaStrokesPainter oldDelegate) {
    return true; // Repaint whenever size or card changes (real-time 144 FPS)
  }
}
