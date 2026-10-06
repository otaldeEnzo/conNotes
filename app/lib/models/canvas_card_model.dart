import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Variável global para rastrear se algum campo de texto (bloco, título, etc) está sendo editado.
/// Utilizada para impedir que atalhos globais (como Delete/Backspace) interfiram na digitação.
bool globalIsEditingText = false;

/// Tipo de Card no Canvas Infinito
enum CardType {
  textLatex,
  media,
  pdf,
}

/// Modo de exibicao do documento PDF no card
enum PdfDisplayMode {
  continuous,
  singlePage,
  grid,
}

/// Modelo de Dados para Cards no Canvas Infinito (Texto, Markdown, LaTeX, Mermaid & Mídia).
class CanvasCardModel {
  final String id;
  final CardType cardType;
  String title;
  double x;
  double y;
  double width;
  double height;
  final double? _manualMinHeight;
  String content;
  String fontFamily;
  double fontSize;
  TextAlign textAlign;
  Color? textColor;
  Color? highlightColor;
  bool isPinned;
  bool isCollapsed;
  Color? customGlassColor;
  String? mediaData;
  double? originalAspectRatio;
  bool lockAspectRatio;
  BoxFit mediaFit;
  String? caption;
  bool invertLuminance;
  bool isDrawOverMode;
  final double rotation;
  int imageRotationQuarterTurns;
  bool isFlippedHorizontal;
  bool isFlippedVertical;
  final List<String> attachedStrokeIds;
  final bool isProcessing;
  // Propriedades especificas de CardType.pdf
  String? pdfPath;
  PdfDisplayMode pdfDisplayMode;
  int currentPdfPage;
  int totalPdfPages;
  double pdfPageGap;
  bool isPdfLocked;
  bool isDetached;
  Map<int, List<String>> pageAttachedStrokeIds;
  List<int> excludedPageIndices;
  String? sourceMasterCardId;
  final DateTime createdAt;
  DateTime updatedAt;

  CanvasCardModel({
    required this.id,
    this.cardType = CardType.textLatex,
    this.title = 'Card STEM',
    required this.x,
    required this.y,
    this.width = 340.0,
    this.height = 200.0,
    double? minHeight,
    this.content = '',
    this.fontFamily = 'Inter',
    this.fontSize = 14.0,
    this.textAlign = TextAlign.left,
    this.textColor,
    this.highlightColor,
    this.isPinned = false,
    this.isCollapsed = false,
    this.isProcessing = false,
    this.customGlassColor,
    this.mediaData,
    this.originalAspectRatio,
    this.lockAspectRatio = true,
    this.mediaFit = BoxFit.contain,
    this.caption,
    this.invertLuminance = false,
    this.isDrawOverMode = false,
    this.rotation = 0.0,
    this.imageRotationQuarterTurns = 0,
    this.isFlippedHorizontal = false,
    this.isFlippedVertical = false,
    this.attachedStrokeIds = const [],
    this.pdfPath,
    this.pdfDisplayMode = PdfDisplayMode.singlePage,
    this.currentPdfPage = 1,
    this.totalPdfPages = 1,
    this.pdfPageGap = 56.0,
    this.isPdfLocked = false,
    this.isDetached = false,
    this.sourceMasterCardId,
    Map<int, List<String>>? pageAttachedStrokeIds,
    List<int>? excludedPageIndices,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : _manualMinHeight = minHeight,
        pageAttachedStrokeIds = pageAttachedStrokeIds ?? <int, List<String>>{},
        excludedPageIndices = excludedPageIndices ?? <int>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Alias de tipo de card
  CardType get type => cardType;

  /// Indica se o card e do tipo PDF
  bool get isPdf => cardType == CardType.pdf;

  /// Retorna os IDs de tracos vinculados a uma pagina especifica do PDF
  List<String> getStrokesForPage(int pageNumber) {
    return pageAttachedStrokeIds[pageNumber] ?? const [];
  }

  /// Retorna o conjunto consolidado de todos os IDs de tracos do card
  Set<String> get allAttachedStrokeIds {
    final ids = <String>{...attachedStrokeIds};
    for (final strokes in pageAttachedStrokeIds.values) {
      ids.addAll(strokes);
    }
    return ids;
  }

  /// Centro geométrico do card no espaço do canvas
  Offset get center => Offset(x + width / 2.0, y + height / 2.0);

  /// Retorna a altura mínima requerida para acomodar todo o conteúdo sem barras de rolagem
  double get minHeight => calculateMinHeight();

  /// Retorna a área mínima (largura * altura mínima) requerida pelo conteúdo.
  double get minArea => width * calculateMinHeight();

  /// Calcula a altura mínima necessária para que todo o conteúdo do card caiba
  /// perfeitamente sem gerar barras de rolagem (scroll) ou avisos de overflow.
  double calculateMinHeight() {
    if (isCollapsed) return 36.0;

    if (cardType == CardType.media) {
      if (lockAspectRatio && originalAspectRatio != null && originalAspectRatio! > 0) {
        return math.max(100.0, width / originalAspectRatio!);
      }
      return 100.0;
    }

    if (cardType == CardType.pdf) {
      final double effectiveAspectRatio =
          (originalAspectRatio != null && originalAspectRatio! > 0)
              ? originalAspectRatio!
              : (1.0 / 1.4142); // Proporcao padrao A4 (0.7071)
      final double singlePageHeight = width / effectiveAspectRatio;

      if (pdfDisplayMode == PdfDisplayMode.singlePage || sourceMasterCardId != null) {
        final double headerH = (sourceMasterCardId == null || isDetached) ? 28.0 : 0.0;
        return math.max(100.0, singlePageHeight + headerH);
      }

      final int excludedCount = excludedPageIndices.toSet().length;
      final int activePages = math.max(1, totalPdfPages - excludedCount);

      if (pdfDisplayMode == PdfDisplayMode.grid) {
        final int rows = (activePages / 2.0).ceil();
        final double itemWidth = (width - pdfPageGap) / 2.0;
        final double itemHeight = itemWidth / effectiveAspectRatio;
        final double totalHeight = (rows * itemHeight) + (math.max(0, rows - 1) * pdfPageGap);
        return math.max(100.0, totalHeight);
      }

      final double totalGaps = (activePages - 1) * pdfPageGap;
      final double totalHeight = (activePages * singlePageHeight) + totalGaps;
      return math.max(100.0, totalHeight);
    }

    const headerHeight = 36.0;
    const paddingVertical = 24.0; // 8px topo + 8px base + respiro
    final availableTextWidth = math.max(40.0, width - 46.0); // 14px outer + 4px inner + bordas de cada lado

    if (content.trim().isEmpty) {
      final titleTp = TextPainter(
        text: TextSpan(
          text: 'Card STEM',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize + 2.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableTextWidth);

      final descTp = TextPainter(
        text: TextSpan(
          text: 'Clique duas vezes para digitar texto, fórmulas LaTeX (\$E=mc^2\$), diagramas Mermaid ou "/" para comandos...',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: 1.4,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableTextWidth);

      final placeholderHeight = headerHeight + 24.0 + titleTp.height + 8.0 + descTp.height + 24.0;
      return math.max(120.0, placeholderHeight);
    }

    final rawChunks = content.split('\n---\n');
    double contentHeight = 0.0;

    for (final chunk in rawChunks) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty && rawChunks.length > 1) continue;

      if (trimmed.startsWith('```mermaid')) {
        final lineCount = trimmed.split('\n').length;
        contentHeight += math.max(160.0, lineCount * 22.0) + 20.0;
      } else if (trimmed.startsWith('```')) {
        final lineCount = trimmed.split('\n').length;
        contentHeight += (lineCount * (fontSize * 1.45)) + 40.0;
      } else if (trimmed.startsWith(r'$$')) {
        // Bloco LaTeX: extrai linhas reais de fórmulas descartando delimitadores e ambientes
        var cleanTex = trimmed.replaceAll(r'$$', '').trim();
        cleanTex = cleanTex
            .replaceAll(RegExp(r'\\begin\{(?:aligned|gathered|matrix|bmatrix|pmatrix|cases)\}'), '')
            .replaceAll(RegExp(r'\\end\{(?:aligned|gathered|matrix|bmatrix|pmatrix|cases)\}'), '');
        final lines = cleanTex
            .split(RegExp(r'\\\\|\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        
        double mathBlockH = 20.0; // padding interno do container LaTeX (10px topo + 10px base)
        for (final line in lines) {
          final fracCount = RegExp(r'\\(?:frac|cfrac)').allMatches(line).length;
          final sqrtCount = RegExp(r'\\sqrt').allMatches(line).length;
          final hasBigOp = RegExp(r'\\(?:iint|iiint|oint|int|sum|prod)').hasMatch(line);
          if (fracCount >= 2) {
            mathBlockH += 56.0;
          } else if (fracCount == 1) {
            mathBlockH += 40.0;
          } else if (hasBigOp) {
            mathBlockH += 44.0;
          } else if (sqrtCount > 0) {
            mathBlockH += 30.0;
          } else {
            mathBlockH += 24.0;
          }
        }
        contentHeight += mathBlockH + 6.0;
      } else if (trimmed.startsWith('> [!')) {
        final lines = trimmed.split('\n');
        double calloutInner = 36.0;
        for (final l in lines) {
          final tp = TextPainter(
            text: TextSpan(
              text: l.startsWith('>') ? l.substring(1).trim() : l,
              style: TextStyle(fontFamily: fontFamily, fontSize: fontSize * 0.95, height: 1.45),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: math.max(40.0, availableTextWidth - 28.0));
          calloutInner += tp.height + 4.0;
        }
        contentHeight += calloutInner + 20.0;
      } else {
        final lines = chunk.split('\n');
        for (final line in lines) {
          final trimmedLine = line.trim();
          double lineFontSize = fontSize;
          if (trimmedLine.startsWith('# ')) {
            lineFontSize = fontSize * 1.5;
          } else if (trimmedLine.startsWith('## ')) {
            lineFontSize = fontSize * 1.3;
          } else if (trimmedLine.startsWith('### ')) {
            lineFontSize = fontSize * 1.15;
          }

          final tp = TextPainter(
            text: TextSpan(
              text: line.isEmpty ? ' ' : line,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: lineFontSize,
                height: 1.45,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: availableTextWidth);

          contentHeight += tp.height;
        }
        contentHeight += 12.0;
      }
    }

    final totalMin = headerHeight + paddingVertical + contentHeight;
    return math.max(90.0, totalMin);
  }

  /// Gira o conteúdo da imagem em múltiplos de 90° e inverte largura e altura
  /// mantendo rigorosamente o centro geométrico no mesmo ponto da tela/canvas.
  void rotateQuarterTurns(int delta) {
    imageRotationQuarterTurns = (imageRotationQuarterTurns + delta) % 4;
    if (imageRotationQuarterTurns < 0) {
      imageRotationQuarterTurns += 4;
    }

    if (delta % 2 != 0) {
      // Troca largura e altura
      final oldW = width;
      final oldH = height;
      final newW = oldH;
      final newH = oldW;

      // Deslocamento para manter o centro invariante
      x += (oldW - newW) / 2.0;
      y += (oldH - newH) / 2.0;
      width = newW;
      height = newH;

      if (originalAspectRatio != null && originalAspectRatio! > 0) {
        originalAspectRatio = 1.0 / originalAspectRatio!;
      }
    }
    updatedAt = DateTime.now();
  }

  /// Alterna o espelhamento horizontal da mídia
  void toggleFlipHorizontal() {
    isFlippedHorizontal = !isFlippedHorizontal;
    updatedAt = DateTime.now();
  }

  /// Alterna o espelhamento vertical da mídia
  void toggleFlipVertical() {
    isFlippedVertical = !isFlippedVertical;
    updatedAt = DateTime.now();
  }

  CanvasCardModel copyWith({
    String? id,
    CardType? cardType,
    String? title,
    double? x,
    double? y,
    double? width,
    double? height,
    double? minHeight,
    String? content,
    String? fontFamily,
    double? fontSize,
    TextAlign? textAlign,
    Color? textColor,
    Color? highlightColor,
    bool? isPinned,
    bool? isCollapsed,
    bool? isProcessing,
    Color? customGlassColor,
    String? mediaData,
    double? originalAspectRatio,
    bool? lockAspectRatio,
    BoxFit? mediaFit,
    String? caption,
    bool? invertLuminance,
    bool? isDrawOverMode,
    double? rotation,
    int? imageRotationQuarterTurns,
    bool? isFlippedHorizontal,
    bool? isFlippedVertical,
    List<String>? attachedStrokeIds,
    String? pdfPath,
    PdfDisplayMode? pdfDisplayMode,
    int? currentPdfPage,
    int? totalPdfPages,
    double? pdfPageGap,
    bool? isPdfLocked,
    bool? isDetached,
    String? sourceMasterCardId,
    Map<int, List<String>>? pageAttachedStrokeIds,
    List<int>? excludedPageIndices,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanvasCardModel(
      id: id ?? this.id,
      cardType: cardType ?? this.cardType,
      title: title ?? this.title,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      minHeight: minHeight ?? _manualMinHeight,
      content: content ?? this.content,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textAlign: textAlign ?? this.textAlign,
      textColor: textColor ?? this.textColor,
      highlightColor: highlightColor ?? this.highlightColor,
      isPinned: isPinned ?? this.isPinned,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isProcessing: isProcessing ?? this.isProcessing,
      customGlassColor: customGlassColor ?? this.customGlassColor,
      mediaData: mediaData ?? this.mediaData,
      originalAspectRatio: originalAspectRatio ?? this.originalAspectRatio,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      mediaFit: mediaFit ?? this.mediaFit,
      caption: caption ?? this.caption,
      invertLuminance: invertLuminance ?? this.invertLuminance,
      isDrawOverMode: isDrawOverMode ?? this.isDrawOverMode,
      rotation: rotation ?? this.rotation,
      imageRotationQuarterTurns: imageRotationQuarterTurns ?? this.imageRotationQuarterTurns,
      isFlippedHorizontal: isFlippedHorizontal ?? this.isFlippedHorizontal,
      isFlippedVertical: isFlippedVertical ?? this.isFlippedVertical,
      attachedStrokeIds: attachedStrokeIds ?? this.attachedStrokeIds,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfDisplayMode: pdfDisplayMode ?? this.pdfDisplayMode,
      currentPdfPage: currentPdfPage ?? this.currentPdfPage,
      totalPdfPages: totalPdfPages ?? this.totalPdfPages,
      pdfPageGap: pdfPageGap ?? this.pdfPageGap,
      isPdfLocked: isPdfLocked ?? this.isPdfLocked,
      isDetached: isDetached ?? this.isDetached,
      sourceMasterCardId: sourceMasterCardId ?? this.sourceMasterCardId,
      pageAttachedStrokeIds: (pageAttachedStrokeIds ?? this.pageAttachedStrokeIds)
          .map((k, v) => MapEntry(k, List<String>.from(v))),
      excludedPageIndices:
          List<int>.from(excludedPageIndices ?? this.excludedPageIndices),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cardType': cardType.name,
      'title': title,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'minHeight': minHeight,
      'content': content,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'textAlign': textAlign.name,
      'textColor': textColor?.toARGB32(),
      'highlightColor': highlightColor?.toARGB32(),
      'isPinned': isPinned,
      'isCollapsed': isCollapsed,
      'isProcessing': isProcessing,
      'customGlassColor': customGlassColor?.toARGB32(),
      'mediaData': mediaData,
      'originalAspectRatio': originalAspectRatio,
      'lockAspectRatio': lockAspectRatio,
      'mediaFit': mediaFit.name,
      'caption': caption,
      'invertLuminance': invertLuminance,
      'isDrawOverMode': isDrawOverMode,
      'rotation': rotation,
      'imageRotationQuarterTurns': imageRotationQuarterTurns,
      'isFlippedHorizontal': isFlippedHorizontal,
      'isFlippedVertical': isFlippedVertical,
      'attachedStrokeIds': attachedStrokeIds,
      'pdfPath': pdfPath,
      'pdfDisplayMode': pdfDisplayMode.name,
      'currentPdfPage': currentPdfPage,
      'totalPdfPages': totalPdfPages,
      'pdfPageGap': pdfPageGap,
      'isPdfLocked': isPdfLocked,
      'isDetached': isDetached,
      'sourceMasterCardId': sourceMasterCardId,
      'pageAttachedStrokeIds': pageAttachedStrokeIds.map(
        (page, strokes) => MapEntry(page.toString(), strokes),
      ),
      'excludedPageIndices': excludedPageIndices,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory CanvasCardModel.fromJson(Map<String, dynamic> json) => CanvasCardModel.fromMap(json);

  factory CanvasCardModel.fromMap(Map<String, dynamic> map) {
    TextAlign parsedAlign = TextAlign.left;
    if (map['textAlign'] != null) {
      for (final a in TextAlign.values) {
        if (a.name == map['textAlign']) {
          parsedAlign = a;
          break;
        }
      }
    }

    CardType parsedType = CardType.textLatex;
    if (map['cardType'] != null) {
      for (final t in CardType.values) {
        if (t.name == map['cardType']) {
          parsedType = t;
          break;
        }
      }
    }

    BoxFit parsedFit = BoxFit.contain;
    if (map['mediaFit'] != null) {
      for (final f in BoxFit.values) {
        if (f.name == map['mediaFit']) {
          parsedFit = f;
          break;
        }
      }
    }

    PdfDisplayMode parsedPdfMode = PdfDisplayMode.singlePage;
    if (map['pdfDisplayMode'] != null) {
      for (final m in PdfDisplayMode.values) {
        if (m.name == map['pdfDisplayMode']) {
          parsedPdfMode = m;
          break;
        }
      }
    }

    final Map<int, List<String>> parsedPageAttachedStrokes = {};
    if (map['pageAttachedStrokeIds'] is Map) {
      final rawMap = map['pageAttachedStrokeIds'] as Map;
      rawMap.forEach((key, value) {
        final pageNum = int.tryParse(key.toString());
        if (pageNum != null && value is List) {
          parsedPageAttachedStrokes[pageNum] =
              value.map((e) => e.toString()).toList();
        }
      });
    }

    final List<int> parsedExcludedPages = [];
    if (map['excludedPageIndices'] is List) {
      for (final item in map['excludedPageIndices'] as List) {
        if (item is num) {
          parsedExcludedPages.add(item.toInt());
        } else if (item != null) {
          final parsed = int.tryParse(item.toString());
          if (parsed != null) parsedExcludedPages.add(parsed);
        }
      }
    }

    String defaultTitle;
    if (parsedType == CardType.media) {
      defaultTitle = 'Media';
    } else if (parsedType == CardType.pdf) {
      defaultTitle = 'PDF STEM';
    } else {
      defaultTitle = 'Card STEM';
    }

    return CanvasCardModel(
      id: map['id']?.toString() ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
      cardType: parsedType,
      title: map['title']?.toString() ?? defaultTitle,
      x: (map['x'] as num?)?.toDouble() ?? 100.0,
      y: (map['y'] as num?)?.toDouble() ?? 100.0,
      width: (map['width'] as num?)?.toDouble() ?? 340.0,
      height: (map['height'] as num?)?.toDouble() ?? 200.0,
      minHeight: (map['minHeight'] as num?)?.toDouble() ?? 110.0,
      content: map['content']?.toString() ?? '',
      fontFamily: map['fontFamily']?.toString() ?? 'Inter',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      textAlign: parsedAlign,
      textColor: map['textColor'] != null ? Color(map['textColor'] as int) : null,
      highlightColor: map['highlightColor'] != null ? Color(map['highlightColor'] as int) : null,
      isPinned: map['isPinned'] == true,
      isCollapsed: map['isCollapsed'] == true,
      isProcessing: map['isProcessing'] == true,
      customGlassColor: map['customGlassColor'] != null ? Color(map['customGlassColor'] as int) : null,
      mediaData: map['mediaData']?.toString(),
      originalAspectRatio: (map['originalAspectRatio'] as num?)?.toDouble(),
      lockAspectRatio: map['lockAspectRatio'] ?? true,
      mediaFit: parsedFit,
      caption: map['caption']?.toString(),
      invertLuminance: map['invertLuminance'] == true,
      isDrawOverMode: map['isDrawOverMode'] == true,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
      imageRotationQuarterTurns: (map['imageRotationQuarterTurns'] as num?)?.toInt() ?? 0,
      isFlippedHorizontal: map['isFlippedHorizontal'] == true,
      isFlippedVertical: map['isFlippedVertical'] == true,
      attachedStrokeIds: (map['attachedStrokeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pdfPath: map['pdfPath']?.toString(),
      pdfDisplayMode: parsedPdfMode,
      currentPdfPage: (map['currentPdfPage'] as num?)?.toInt() ?? 1,
      totalPdfPages: (map['totalPdfPages'] as num?)?.toInt() ?? 1,
      pdfPageGap: (map['pdfPageGap'] as num?)?.toDouble() ?? 56.0,
      isPdfLocked: map['isPdfLocked'] == true,
      isDetached: map['isDetached'] == true,
      sourceMasterCardId: map['sourceMasterCardId']?.toString(),
      pageAttachedStrokeIds: parsedPageAttachedStrokes,
      excludedPageIndices: parsedExcludedPages,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
    );
  }
}
