import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/canvas_card_model.dart';
import '../../theme/moscaro_v2_extension.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../ink_models.dart';
import '../note_models.dart';
import '../svg_icon.dart';

/// Renderizador vetorial em miniatura dos traços e cartões de um NoteDocument.
/// Usado como preview interativo durante o hover do mouse.
class HomeNoteHoverPreview extends StatelessWidget {
  final NoteDocument note;
  final double width;
  final double height;

  const HomeNoteHoverPreview({
    super.key,
    required this.note,
    this.width = 240,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = note.strokes.isNotEmpty || note.cards.isNotEmpty;
    final isLight = MoscaroTokens.isLight;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xE8F8FAFC)
            : const Color(0xEB0F131C),
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusButton),
        border: Border.all(
          color: MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.35 : 0.4),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Fundo com Dot Grid minimalista
          Positioned.fill(
            child: CustomPaint(
              painter: _PreviewGridPainter(
                dotColor: isLight
                    ? const Color(0x200F172A)
                    : const Color(0x2500E1FF),
              ),
            ),
          ),

          if (hasContent)
            Positioned.fill(
              child: CustomPaint(
                painter: _CanvasContentMiniPainter(
                  strokes: note.strokes,
                  cards: note.cards,
                  isLight: isLight,
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgIcon(
                    name: 'edit',
                    size: 24,
                    color: isLight
                        ? const Color(0x600F172A)
                        : const Color(0x6094A3B8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Canvas em branco',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isLight
                          ? const Color(0x700F172A)
                          : const Color(0x7094A3B8),
                    ),
                  ),
                ],
              ),
            ),

          // Tag de preview no topo
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isLight ? Colors.white : Colors.black).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isLight ? const Color(0x200F172A) : const Color(0x25FFFFFF),
                  width: 0.5,
                ),
              ),
              child: Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: MoscaroTokens.auroraBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: MoscaroTokens.radiusButton,
      blurSigma: 16.0,
      enableBlur: true,
      borderColor: MoscaroTokens.auroraBlue.withValues(alpha: 0.3),
    );
  }
}

/// Painter minimalista para a grade pontilhada no preview
class _PreviewGridPainter extends CustomPainter {
  final Color dotColor;

  _PreviewGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    for (double x = 8.0; x < size.width; x += spacing) {
      for (double y = 8.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

/// Painter que normaliza as coordenadas de strokes e cards e os desenha com escala ajustada
class _CanvasContentMiniPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<CanvasCardModel> cards;
  final bool isLight;

  _CanvasContentMiniPainter({
    required this.strokes,
    required this.cards,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty && cards.isEmpty) return;

    // Calcula a bounding box de todo o conteúdo
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final stroke in strokes) {
      for (final p in stroke.points) {
        minX = math.min(minX, p.point.dx);
        minY = math.min(minY, p.point.dy);
        maxX = math.max(maxX, p.point.dx);
        maxY = math.max(maxY, p.point.dy);
      }
    }

    for (final card in cards) {
      minX = math.min(minX, card.x);
      minY = math.min(minY, card.y);
      maxX = math.max(maxX, card.x + card.width);
      maxY = math.max(maxY, card.y + card.height);
    }

    if (minX == double.infinity || minY == double.infinity) return;

    final contentWidth = math.max(maxX - minX, 100.0);
    final contentHeight = math.max(maxY - minY, 100.0);

    const padding = 14.0;
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);

    final scaleX = availableWidth / contentWidth;
    final scaleY = availableHeight / contentHeight;
    final scale = math.min(scaleX, scaleY).clamp(0.01, 1.0);

    final renderedWidth = contentWidth * scale;
    final renderedHeight = contentHeight * scale;
    final offsetX = padding + (availableWidth - renderedWidth) / 2 - (minX * scale);
    final offsetY = padding + (availableHeight - renderedHeight) / 2 - (minY * scale);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // Desenhar cards
    for (final card in cards) {
      final cardRect = Rect.fromLTWH(card.x, card.y, card.width, card.height);
      final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(8.0));

      final cardBgPaint = Paint()
        ..color = (isLight ? const Color(0xDDFFFFFF) : const Color(0xDD1E293B))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, cardBgPaint);

      final cardBorderPaint = Paint()
        ..color = MoscaroTokens.auroraBlue.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / scale;
      canvas.drawRRect(rrect, cardBorderPaint);

      // Linhas ilustrativas simulando texto dentro do card
      final textLinePaint = Paint()
        ..color = (isLight ? const Color(0x600F172A) : const Color(0x6094A3B8))
        ..style = PaintingStyle.fill;

      final lineCount = math.min(3, (card.height / 18).floor());
      for (int i = 0; i < lineCount; i++) {
        final lineY = card.y + 12.0 + (i * 12.0);
        final lineWidth = (card.width - 20.0) * (i == lineCount - 1 ? 0.6 : 0.85);
        if (lineY + 4 < card.y + card.height) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(card.x + 10.0, lineY, lineWidth, 4.0),
              const Radius.circular(2.0),
            ),
            textLinePaint,
          );
        }
      }
    }

    // Desenhar strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = math.max(stroke.strokeWidth, 1.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final path = Path();
      path.moveTo(stroke.points.first.point.dx, stroke.points.first.point.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final p0 = stroke.points[i - 1].point;
        final p1 = stroke.points[i].point;
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
      path.lineTo(stroke.points.last.point.dx, stroke.points.last.point.dy);
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasContentMiniPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.cards.length != cards.length ||
        oldDelegate.isLight != isLight;
  }
}
