import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/theme_models.dart';
import '../theme/moscaro_v2_tokens.dart';

enum CanvasBackgroundType { dotGrid, pautado, isometric, emBranco }

/// Engine de Renderização 2D do Canvas Infinito com suporte a Pautas de Caderno,
/// Grid Isométrico Rígido, Temas Dinâmicos e Texturas Procedurais STEM.
class CanvasDotGridPainter extends CustomPainter {
  final Offset panOffset;
  final double zoomScale;
  final Offset? mousePosition;
  final CanvasBackgroundType backgroundType;
  final bool isDrawing;
  final double gridSpacing;
  final bool enableMouseGlow;
  final double mouseGlowRadius;
  final ThemeDefinition theme;
  final CanvasBackgroundMode backgroundMode;
  final Color customSolidColor;
  final Color customGradientStart;
  final Color customGradientEnd;
  final CanvasTextureType textureType;

  CanvasDotGridPainter({
    required this.panOffset,
    required this.zoomScale,
    required this.mousePosition,
    required this.backgroundType,
    this.isDrawing = false,
    this.gridSpacing = 28.0,
    this.enableMouseGlow = true,
    this.mouseGlowRadius = 120.0,
    this.theme = ThemeDefinition.moscaroCyan,
    this.backgroundMode = CanvasBackgroundMode.preset,
    this.customSolidColor = const Color(0xFF070B14),
    this.customGradientStart = const Color(0xFF0C1B2E),
    this.customGradientEnd = const Color(0xFF060B12),
    this.textureType = CanvasTextureType.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo do Canvas (Suporte a Cor Sólida, Gradiente, Wallpapers STEM, Imagem ou Preset Oficial)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint bgPaint = Paint();

    final effectiveBgMode = theme.isCustom ? theme.bgMode : backgroundMode;

    if (effectiveBgMode == CanvasBackgroundMode.solidColor) {
      bgPaint.color = theme.isCustom ? theme.backgroundSurface : customSolidColor;
      canvas.drawRect(rect, bgPaint);
    } else if (effectiveBgMode == CanvasBackgroundMode.customImage) {
      // Deixa a camada do painter transparente para que a imagem do disco (Renderizada na Camada 0) fique visível
      bgPaint.color = Colors.transparent;
      canvas.drawRect(rect, bgPaint);
    } else if (effectiveBgMode == CanvasBackgroundMode.stemWallpaper) {
      _paintStemWallpaperBackground(canvas, rect);
    } else if (effectiveBgMode == CanvasBackgroundMode.gradient ||
        (theme.gradientColors != null && theme.gradientColors!.length >= 2 && theme.isCustom) ||
        theme.bgMode == CanvasBackgroundMode.gradient) {
      final List<Color> colors = (theme.gradientColors != null && theme.gradientColors!.length >= 2)
          ? theme.gradientColors!
          : (theme.effectiveGradientColors.length >= 2
              ? theme.effectiveGradientColors
              : [customGradientStart, customGradientEnd]);
      
      final List<double> stops = (theme.gradientStops != null && theme.gradientStops!.length == colors.length)
          ? theme.gradientStops!
          : (theme.effectiveGradientStops.length == colors.length
              ? theme.effectiveGradientStops
              : [
                  for (int i = 0; i < colors.length; i++) i / (colors.length - 1)
                ]);

      bgPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: stops,
      ).createShader(rect);
      canvas.drawRect(rect, bgPaint);
    } else {
      bgPaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 1.4,
        colors: [theme.backgroundDeep, theme.backgroundSurface],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, bgPaint);
    }

    // Salva o estado do Canvas e aplica a transformação mundial (World Space)
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final double worldLeft = -panOffset.dx / zoomScale;
    final double worldTop = -panOffset.dy / zoomScale;
    final double worldRight = (size.width - panOffset.dx) / zoomScale;
    final double worldBottom = (size.height - panOffset.dy) / zoomScale;

    // 2. Textura Procedural STEM (se ativa)
    if (textureType != CanvasTextureType.none && backgroundType != CanvasBackgroundType.emBranco) {
      _paintTextureOverlay(canvas, worldLeft, worldTop, worldRight, worldBottom);
    }

    // 3. Renderização de Padrões de Fundo (World Coordinates)
    if (backgroundType == CanvasBackgroundType.dotGrid) {
      _paintDotGrid(canvas, worldLeft, worldTop, worldRight, worldBottom);
    } else if (backgroundType == CanvasBackgroundType.pautado) {
      _paintPautadoNotebook(canvas, worldLeft, worldTop, worldRight, worldBottom);
    } else if (backgroundType == CanvasBackgroundType.isometric) {
      _paintIsometricLattice(canvas, worldLeft, worldTop, worldRight, worldBottom);
    }

    // 4. Pautas Universais de Caderno e Origem (Apenas quando não for modo emBranco)
    if (backgroundType != CanvasBackgroundType.emBranco) {
      _paintNotebookMarginAndHeader(canvas, worldLeft, worldTop, worldRight, worldBottom);
      _paintOriginBoundaries(canvas, worldLeft, worldTop, worldRight, worldBottom);
    }

    canvas.restore();
  }

  void _paintTextureOverlay(Canvas canvas, double left, double top, double right, double bottom) {
    switch (textureType) {
      case CanvasTextureType.graphPaper:
        const double minorSpacing = 8.0;
        const double majorSpacing = 40.0;
        final minorPaint = Paint()
          ..color = theme.accentPrimary.withValues(alpha: 0.05)
          ..strokeWidth = 0.5;
        final majorPaint = Paint()
          ..color = theme.accentPrimary.withValues(alpha: 0.15)
          ..strokeWidth = 0.9;

        final startX = (left / minorSpacing).floor() * minorSpacing;
        final startY = (top / minorSpacing).floor() * minorSpacing;

        for (double x = startX; x <= right; x += minorSpacing) {
          final isMajor = (x.round() % majorSpacing.round()).abs() < 0.5;
          canvas.drawLine(Offset(x, top), Offset(x, bottom), isMajor ? majorPaint : minorPaint);
        }
        for (double y = startY; y <= bottom; y += minorSpacing) {
          final isMajor = (y.round() % majorSpacing.round()).abs() < 0.5;
          canvas.drawLine(Offset(left, y), Offset(right, y), isMajor ? majorPaint : minorPaint);
        }
        break;

      case CanvasTextureType.blueprintCloth:
        const double spacing = 16.0;
        final paint = Paint()
          ..color = theme.accentPrimary.withValues(alpha: 0.06)
          ..strokeWidth = 0.6;
        final startX = (left / spacing).floor() * spacing;
        final startY = (top / spacing).floor() * spacing;
        for (double x = startX; x <= right; x += spacing) {
          canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
        }
        for (double y = startY; y <= bottom; y += spacing) {
          canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        }
        break;

      case CanvasTextureType.carbonFiber:
        const double step = 20.0;
        final blockPaint1 = Paint()
          ..color = Colors.white.withValues(alpha: 0.02)
          ..style = PaintingStyle.fill;
        final blockPaint2 = Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        final startX = (left / step).floor() * step;
        final startY = (top / step).floor() * step;
        for (double x = startX; x <= right; x += step) {
          for (double y = startY; y <= bottom; y += step) {
            final isEven = ((x / step).round() + (y / step).round()) % 2 == 0;
            final r = Rect.fromLTWH(x, y, step * 0.9, step * 0.9);
            canvas.drawRect(r, isEven ? blockPaint1 : blockPaint2);
          }
        }
        break;

      case CanvasTextureType.analogGrain:
        final grainPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.03)
          ..style = PaintingStyle.fill;
        const double grainSpacing = 28.0;
        final startX = (left / grainSpacing).floor() * grainSpacing;
        final startY = (top / grainSpacing).floor() * grainSpacing;
        for (double x = startX; x <= right; x += grainSpacing) {
          for (double y = startY; y <= bottom; y += grainSpacing) {
            final pseudoRandom = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
            final offsetX = (pseudoRandom - pseudoRandom.floor()) * 12.0;
            final offsetY = ((pseudoRandom * 2.0) - (pseudoRandom * 2.0).floor()) * 12.0;
            canvas.drawCircle(Offset(x + offsetX, y + offsetY), 0.7, grainPaint);
          }
        }
        break;

      case CanvasTextureType.none:
        break;
    }
  }

  void _paintStemWallpaperBackground(Canvas canvas, Rect rect) {
    final wpId = theme.name;
    final bgPaint = Paint();

    // 1. Base Gradient Cósmico / Técnico
    bgPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [theme.backgroundDeep, theme.backgroundSurface],
    ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final overlayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 2. Elementos Procedurais do Wallpaper
    if (wpId.contains('Cosmos') || wpId.contains('deep_field')) {
      final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
      for (double i = 0; i < rect.width; i += 75) {
        for (double j = 0; j < rect.height; j += 75) {
          final pseudo = math.sin(i * 91.34 + j * 47.19) * 1000;
          final ox = (pseudo - pseudo.floor()) * 60;
          final oy = ((pseudo * 2.1) - (pseudo * 2.1).floor()) * 60;
          canvas.drawCircle(Offset(i + ox, j + oy), 0.9, starPaint);
        }
      }
    } else if (wpId.contains('Circuito') || wpId.contains('quantum_circuits')) {
      overlayPaint.color = MoscaroTokens.auroraBlue.withValues(alpha: 0.08);
      for (double y = 40; y < rect.height; y += 120) {
        canvas.drawLine(Offset(0, y), Offset(rect.width, y), overlayPaint);
        canvas.drawCircle(Offset(120, y), 3, overlayPaint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(340, y), 3, overlayPaint);
      }
    } else if (wpId.contains('Feynman') || wpId.contains('feynman')) {
      overlayPaint.color = MoscaroTokens.auroraPurple.withValues(alpha: 0.12);
      for (double y = 80; y < rect.height; y += 160) {
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < rect.width; x += 40) {
          path.quadraticBezierTo(x + 10, y - 12, x + 20, y);
          path.quadraticBezierTo(x + 30, y + 12, x + 40, y);
        }
        canvas.drawPath(path, overlayPaint..style = PaintingStyle.stroke);
      }
    } else if (wpId.contains('Gravitacional') || wpId.contains('gravity')) {
      overlayPaint.color = MoscaroTokens.auroraBlue.withValues(alpha: 0.07);
      final center = Offset(rect.width / 2, rect.height / 2);
      for (double r = 40; r < rect.width; r += 50) {
        canvas.drawOval(Rect.fromCenter(center: center, width: r * 1.6, height: r * 0.8), overlayPaint);
      }
    } else if (wpId.contains('Grafeno') || wpId.contains('graphene')) {
      overlayPaint.color = Colors.white.withValues(alpha: 0.04);
      const side = 24.0;
      final h = side * math.sqrt(3);
      for (double y = 0; y < rect.height; y += h) {
        for (double x = 0; x < rect.width; x += side * 3) {
          canvas.drawCircle(Offset(x, y), 1.2, overlayPaint..style = PaintingStyle.fill);
        }
      }
    }
  }

  /// Renderiza o Dot Grid com LOD dinâmico em coordenadas de mundo e Glow Reativo
  void _paintDotGrid(Canvas canvas, double left, double top, double right, double bottom) {
    double spacing = gridSpacing;
    final scaledSpacing = spacing * zoomScale;
    if (scaledSpacing < 18.0) {
      spacing = gridSpacing * 2.0;
    } else if (scaledSpacing > 76.0) {
      spacing = gridSpacing / 2.0;
    }

    final double startX = (left / spacing).floor() * spacing;
    final double startY = (top / spacing).floor() * spacing;
    final double dotRadius = (1.2 / zoomScale).clamp(0.6, 2.2);

    final Paint dotPaint = Paint()
      ..color = theme.dotGridColor
      ..strokeWidth = dotRadius * 2
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    final glowPoints = <Offset>[];
    final glowRadiusSq = (mouseGlowRadius / zoomScale) * (mouseGlowRadius / zoomScale);
    final worldMouse = mousePosition != null
        ? Offset((mousePosition!.dx - panOffset.dx) / zoomScale, (mousePosition!.dy - panOffset.dy) / zoomScale)
        : null;

    for (double x = startX; x <= right + spacing; x += spacing) {
      if (x < 0) continue; // Confinado ao 4º quadrante (x >= 0)
      for (double y = startY; y <= bottom + spacing; y += spacing) {
        if (y < 0) continue; // Confinado ao 4º quadrante (y >= 0)
        final pt = Offset(x, y);
        if (enableMouseGlow && worldMouse != null && !isDrawing && (pt - worldMouse).distanceSquared < glowRadiusSq) {
          glowPoints.add(pt);
        } else {
          points.add(pt);
        }
      }
    }

    if (points.isNotEmpty) {
      canvas.drawPoints(PointMode.points, points, dotPaint);
    }

    if (glowPoints.isNotEmpty) {
      final Paint glowPaint = Paint()
        ..color = theme.mouseGlowColor.withValues(alpha: 0.8)
        ..strokeWidth = dotRadius * 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawPoints(PointMode.points, glowPoints, glowPaint);
    }
  }

  /// Renderiza o modo Pautado (Linhas horizontais regulares espaçadas a cada 34pt)
  void _paintPautadoNotebook(Canvas canvas, double left, double top, double right, double bottom) {
    const double lineSpacing = 34.0;
    final double startY = math.max(0.0, (top / lineSpacing).floor() * lineSpacing);

    final linePaint = Paint()
      ..color = theme.accentPrimary.withValues(alpha: 0.12)
      ..strokeWidth = 1.0 / zoomScale;

    // Linhas horizontais pautadas
    for (double y = startY; y <= bottom + lineSpacing; y += lineSpacing) {
      if (y < 0) continue;
      canvas.drawLine(
        Offset(math.max(0.0, left), y),
        Offset(right, y),
        linePaint,
      );
    }
  }

  /// Renderiza o modo Isométrico Rígido (Grid 3D com linhas a 30° e 150°)
  void _paintIsometricLattice(Canvas canvas, double left, double top, double right, double bottom) {
    const double isoSpacing = 32.0;
    final double sin30 = math.sin(math.pi / 6);
    final double cos30 = math.cos(math.pi / 6);
    final double triangleHeight = isoSpacing * sin30 * 2;
    final double triangleWidth = isoSpacing * cos30 * 2;

    final linePaint = Paint()
      ..color = theme.accentPrimary.withValues(alpha: 0.08)
      ..strokeWidth = 0.8 / zoomScale;

    final double startY = (top / triangleHeight).floor() * triangleHeight;
    for (double y = startY; y <= bottom + triangleHeight; y += triangleHeight) {
      if (y < 0) continue;
      canvas.drawLine(Offset(math.max(0.0, left), y), Offset(right, y), linePaint);
    }

    final double startX = (left / triangleWidth).floor() * triangleWidth;
    for (double x = startX - (bottom - top) * math.tan(math.pi / 6); x <= right + (bottom - top) * math.tan(math.pi / 6); x += triangleWidth) {
      canvas.drawLine(
        Offset(x, top),
        Offset(x + (bottom - top) * math.tan(math.pi / 6), bottom),
        linePaint,
      );
      canvas.drawLine(
        Offset(x, top),
        Offset(x - (bottom - top) * math.tan(math.pi / 6), bottom),
        linePaint,
      );
    }
  }

  /// Pautas Universais de Caderno (Margem Esquerda em X=80 e Cabeçalho em Y=102)
  void _paintNotebookMarginAndHeader(Canvas canvas, double left, double top, double right, double bottom) {
    const double marginX = 80.0;
    const double headerY = 102.0;

    final marginPaint = Paint()
      ..color = MoscaroTokens.auroraPink.withValues(alpha: 0.35)
      ..strokeWidth = 1.2 / zoomScale;

    final headerPaint = Paint()
      ..color = theme.accentPrimary.withValues(alpha: 0.35)
      ..strokeWidth = 1.2 / zoomScale;

    if (marginX >= left && marginX <= right) {
      canvas.drawLine(
        Offset(marginX, math.max(0.0, top)),
        Offset(marginX, math.max(0.0, bottom)),
        marginPaint,
      );
    }

    if (headerY >= top && headerY <= bottom) {
      canvas.drawLine(
        Offset(math.max(0.0, left), headerY),
        Offset(right, headerY),
        headerPaint,
      );
    }
  }

  /// Delimitação dos Eixos da Origem do 4º Quadrante (X=0 e Y=0)
  void _paintOriginBoundaries(Canvas canvas, double left, double top, double right, double bottom) {
    final axisPaint = Paint()
      ..color = theme.accentPrimary.withValues(alpha: 0.45)
      ..strokeWidth = 1.5 / zoomScale;

    if (0.0 >= left && 0.0 <= right) {
      canvas.drawLine(
        Offset(0.0, math.max(0.0, top)),
        Offset(0.0, math.max(0.0, bottom)),
        axisPaint,
      );
    }

    if (0.0 >= top && 0.0 <= bottom) {
      canvas.drawLine(
        Offset(math.max(0.0, left), 0.0),
        Offset(right, 0.0),
        axisPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CanvasDotGridPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.mousePosition != mousePosition ||
        oldDelegate.backgroundType != backgroundType ||
        oldDelegate.isDrawing != isDrawing ||
        oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.enableMouseGlow != enableMouseGlow ||
        oldDelegate.mouseGlowRadius != mouseGlowRadius ||
        oldDelegate.theme != theme ||
        oldDelegate.backgroundMode != backgroundMode ||
        oldDelegate.customSolidColor != customSolidColor ||
        oldDelegate.customGradientStart != customGradientStart ||
        oldDelegate.customGradientEnd != customGradientEnd ||
        oldDelegate.textureType != textureType;
  }
}
