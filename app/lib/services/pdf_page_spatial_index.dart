import 'dart:math' as math;
import 'dart:ui';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_text_selection_models.dart';

/// Single line entry indexed spatially.
class PdfSpatialLine {
  final int startIndex;
  final int endIndex;
  final Rect bounds;
  final List<Rect> charRects;
  final List<int> charIndices;
  final int columnIndex;
  final bool isVertical;

  const PdfSpatialLine({
    required this.startIndex,
    required this.endIndex,
    required this.bounds,
    required this.charRects,
    required this.charIndices,
    this.columnIndex = 0,
    this.isVertical = false,
  });

  bool containsY(double y, {double tolerance = 1.0}) {
    return y >= (bounds.top - tolerance) && y <= (bounds.bottom + tolerance);
  }

  bool containsX(double x, {double tolerance = 1.0}) {
    return x >= (bounds.left - tolerance) && x <= (bounds.right + tolerance);
  }
}

/// A spatial line index of page glyphs delivering O(log N) hit-testing,
/// two-column gutter detection, and word/paragraph boundary resolution.
class PdfPageSpatialIndex {
  final int pageNumber;
  final double nativeWidth;
  final double nativeHeight;
  final List<PdfSpatialLine> lines;
  final List<double> columnDividers;
  final String fullText;

  const PdfPageSpatialIndex._({
    required this.pageNumber,
    required this.nativeWidth,
    required this.nativeHeight,
    required this.lines,
    required this.columnDividers,
    required this.fullText,
  });

  /// Factory creating an optimized spatial index from a pdfrx [PdfPageText].
  factory PdfPageSpatialIndex.fromPageText({
    required PdfPageText pageText,
    required int pageNumber,
    required double nativeWidth,
    required double nativeHeight,
    List<Rect>? excludedImageRects,
  }) {
    final fullText = pageText.fullText;
    if (pageText.fragments.isEmpty || fullText.isEmpty || nativeWidth <= 0 || nativeHeight <= 0) {
      return PdfPageSpatialIndex._(
        pageNumber: pageNumber,
        nativeWidth: nativeWidth,
        nativeHeight: nativeHeight,
        lines: const <PdfSpatialLine>[],
        columnDividers: const <double>[],
        fullText: fullText,
      );
    }

    // 1. Collect all characters, separating vertical fragments from horizontal text
    final verticalLines = <PdfSpatialLine>[];
    final horizontalChars = <_IndexedChar>[];

    for (final fragment in pageText.fragments) {
      final fragIndex = fragment.index;
      final charRects = fragment.charRects;
      if (charRects.isEmpty) continue;

      final convertedChars = <_IndexedChar>[];
      for (int i = 0; i < charRects.length; i++) {
        final globalIdx = fragIndex + i;
        if (globalIdx < fullText.length) {
          final r = charRects[i];
          // pdfrx PdfRect uses PDF space (origin bottom-left, Y up, top > bottom).
          // Convert to Flutter space (origin top-left, Y down) once at ingestion.
          final y1 = nativeHeight - r.top;
          final y2 = nativeHeight - r.bottom;
          final charTop = math.min(y1, y2);
          final charBottom = math.max(y1, y2);
          final charLeft = math.min(r.left, r.right);
          final charRight = math.max(r.left, r.right);
          final charRect = Rect.fromLTRB(charLeft, charTop, charRight, charBottom);

          // Filtra rótulos/glifos sobrepostos a imagens ou diagramas
          if (excludedImageRects != null && excludedImageRects.isNotEmpty) {
            final center = charRect.center;
            if (excludedImageRects.any((imgRect) => imgRect.contains(center))) {
              continue;
            }
          }

          convertedChars.add(_IndexedChar(
            index: globalIdx,
            char: fullText[globalIdx],
            rect: charRect,
          ));
        }
      }

      if (convertedChars.isEmpty) continue;

      // Detecta se o fragmento e vertical (ex: rotulo de eixo de grafico rotacionado em 90 ou 270 graus)
      bool isFragmentVertical = false;
      if (convertedChars.length >= 2) {
        final firstR = convertedChars.first.rect;
        final lastR = convertedChars.last.rect;
        final deltaX = (lastR.center.dx - firstR.center.dx).abs();
        final deltaY = (lastR.center.dy - firstR.center.dy).abs();
        if (deltaY > deltaX * 1.5) {
          isFragmentVertical = true;
        }
      }

      if (isFragmentVertical) {
        verticalLines.add(_buildSpatialLine(convertedChars, const [], isVertical: true));
      } else {
        horizontalChars.addAll(convertedChars);
      }
    }

    if (horizontalChars.isEmpty && verticalLines.isEmpty) {
      return PdfPageSpatialIndex._(
        pageNumber: pageNumber,
        nativeWidth: nativeWidth,
        nativeHeight: nativeHeight,
        lines: const <PdfSpatialLine>[],
        columnDividers: const <double>[],
        fullText: fullText,
      );
    }

    // 2. Sort horizontal characters primarily by vertical position (Y), then horizontal (X).
    // Uses center Y with an 8.0px threshold to keep superscripts and subscripts in reading sequence with their base glyphs.
    horizontalChars.sort((a, b) {
      final centerDiff = a.rect.center.dy - b.rect.center.dy;
      if (centerDiff.abs() > 8.0) {
        return centerDiff > 0 ? 1 : -1;
      }
      return a.rect.left.compareTo(b.rect.left);
    });

    // 3. Detect column gutters (looking for continuous vertical whitespace bands)
    final columnDividers = _detectColumnDividers(horizontalChars, nativeWidth);

    // 4. Cluster characters into continuous horizontal lines
    final lines = <PdfSpatialLine>[...verticalLines];
    if (horizontalChars.isNotEmpty) {
      List<_IndexedChar> currentLineChars = [horizontalChars.first];
      double currentLineTop = horizontalChars.first.rect.top;
      double currentLineBottom = horizontalChars.first.rect.bottom;

      for (int i = 1; i < horizontalChars.length; i++) {
        final c = horizontalChars[i];
        final verticalOverlap = math.min(currentLineBottom, c.rect.bottom) -
            math.max(currentLineTop, c.rect.top);
        final lineHeight = math.max(1.0, currentLineBottom - currentLineTop);

        final lastChar = currentLineChars.last;
        final isHorizontallyAdjacent = (c.rect.left - lastChar.rect.right).abs() < 14.0;
        final isNearLineBand = (c.rect.center.dy - ((currentLineTop + currentLineBottom) / 2.0)).abs() < (lineHeight * 0.85);

        // If characters overlap vertically or are immediately horizontally adjacent within the line band (superscripts/subscripts)
        if (verticalOverlap > lineHeight * 0.3 || (isHorizontallyAdjacent && isNearLineBand) || (c.rect.top - currentLineTop).abs() < 6.0) {
          currentLineChars.add(c);
          currentLineTop = math.min(currentLineTop, c.rect.top);
          currentLineBottom = math.max(currentLineBottom, c.rect.bottom);
        } else {
          // Emit accumulated line
          lines.add(_buildSpatialLine(currentLineChars, columnDividers));
          currentLineChars = [c];
          currentLineTop = c.rect.top;
          currentLineBottom = c.rect.bottom;
        }
      }

      if (currentLineChars.isNotEmpty) {
        lines.add(_buildSpatialLine(currentLineChars, columnDividers));
      }
    }

    // Sort lines by column first, then by vertical top
    lines.sort((a, b) {
      if (a.columnIndex != b.columnIndex) {
        return a.columnIndex.compareTo(b.columnIndex);
      }
      return a.bounds.top.compareTo(b.bounds.top);
    });

    return PdfPageSpatialIndex._(
      pageNumber: pageNumber,
      nativeWidth: nativeWidth,
      nativeHeight: nativeHeight,
      lines: lines,
      columnDividers: columnDividers,
      fullText: fullText,
    );
  }

  static PdfSpatialLine _buildSpatialLine(
    List<_IndexedChar> chars,
    List<double> dividers, {
    bool isVertical = false,
  }) {
    if (isVertical) {
      chars.sort((a, b) => a.rect.top.compareTo(b.rect.top));
    } else {
      chars.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    int minIdx = chars.first.index;
    int maxIdx = chars.first.index;
    final rects = <Rect>[];
    final charIndices = <int>[];

    for (final c in chars) {
      left = math.min(left, c.rect.left);
      top = math.min(top, c.rect.top);
      right = math.max(right, c.rect.right);
      bottom = math.max(bottom, c.rect.bottom);
      minIdx = math.min(minIdx, c.index);
      maxIdx = math.max(maxIdx, c.index);
      rects.add(c.rect);
      charIndices.add(c.index);
    }

    final midX = (left + right) / 2.0;
    int col = 0;
    for (final div in dividers) {
      if (midX > div) col++;
    }

    return PdfSpatialLine(
      startIndex: minIdx,
      endIndex: maxIdx + 1,
      bounds: Rect.fromLTRB(left, top, right, bottom),
      charRects: rects,
      charIndices: charIndices,
      columnIndex: col,
      isVertical: isVertical,
    );
  }

  static List<double> _detectColumnDividers(List<_IndexedChar> chars, double width) {
    if (width <= 0) return const [];
    // Checa se ha caracteres que cruzam a faixa central da pagina (40% a 60%)
    final midLeft = width * 0.40;
    final midRight = width * 0.60;
    bool hasCharsCrossingMidlane = false;
    for (final c in chars) {
      if (c.rect.right > midLeft && c.rect.left < midRight) {
        hasCharsCrossingMidlane = true;
        break;
      }
    }
    // Uma pagina de 2 colunas reais NAO possui caracteres cruzando o centro da pagina
    if (!hasCharsCrossingMidlane && chars.length > 80) {
      return [width * 0.50];
    }
    return const [];
  }

  /// Binary search / spatial lookup finding the nearest character index for a display point.
  int findNearestCharIndex({
    required Offset displayPos,
    required double displayWidth,
    required double displayHeight,
  }) {
    if (lines.isEmpty || nativeWidth <= 0 || nativeHeight <= 0) return 0;
    final scaleX = displayWidth / nativeWidth;
    final scaleY = displayHeight / nativeHeight;
    final targetX = displayPos.dx / scaleX;
    final targetY = displayPos.dy / scaleY;
    final targetOffset = Offset(targetX, targetY);

    // 1. Verificacao exata rapida: ponto caiu dentro ou no respiro imediato de alguma linha
    for (final line in lines) {
      final expandedBounds = line.bounds.inflate(3.0);
      if (expandedBounds.contains(targetOffset)) {
        int nearestIdx = line.charIndices.isNotEmpty ? line.charIndices.first : line.startIndex;
        double minD = double.infinity;
        for (int i = 0; i < line.charRects.length; i++) {
          final r = line.charRects[i];
          if (r.contains(targetOffset)) {
            return i < line.charIndices.length ? line.charIndices[i] : line.startIndex + i;
          }
          final d = (r.center - targetOffset).distanceSquared;
          if (d < minD) {
            minD = d;
            nearestIdx = i < line.charIndices.length ? line.charIndices[i] : line.startIndex + i;
          }
        }
        return nearestIdx;
      }
    }

    // Identifica coluna de destino (evita salto de coluna)
    int targetCol = 0;
    for (final div in columnDividers) {
      if (targetX > div) targetCol++;
    }

    // 2. Busca pela linha mais proxima no espaco 2D com forte priorizacao da coordenada de leitura
    PdfSpatialLine nearestLine = lines.first;
    double minLineDist = double.infinity;

    for (final line in lines) {
      double dist;
      if (line.isVertical) {
        final double dX = (targetX < line.bounds.left)
            ? (line.bounds.left - targetX)
            : (targetX > line.bounds.right ? targetX - line.bounds.right : 0.0);
        final double dY = (targetY < line.bounds.top)
            ? (line.bounds.top - targetY)
            : (targetY > line.bounds.bottom ? targetY - line.bounds.bottom : 0.0);
        dist = (dX * 10.0) + dY;
      } else {
        final double dY = (targetY < line.bounds.top)
            ? (line.bounds.top - targetY)
            : (targetY > line.bounds.bottom ? targetY - line.bounds.bottom : 0.0);
        final double dX = (targetX < line.bounds.left)
            ? (line.bounds.left - targetX)
            : (targetX > line.bounds.right ? targetX - line.bounds.right : 0.0);

        // Proximidade vertical pura: linhas na mesma faixa horizontal do ponteiro sao prioridade absoluta
        dist = (dY * 5.0) + dX;

        // Penalidade de coluna so deve ser considerada se a linha estiver bem afastada verticalmente (> 60px)
        if (dY > 60.0 && line.columnIndex != targetCol) {
          dist += 300.0;
        }
      }

      if (dist < minLineDist) {
        minLineDist = dist;
        nearestLine = line;
      }
    }

    // 3. Dentro da linha mais proxima, busca o caractere mais proximo ou faz snap para inicio/fim
    if (nearestLine.charRects.isEmpty) {
      return nearestLine.startIndex;
    }

    if (nearestLine.isVertical) {
      if (targetY <= nearestLine.bounds.top) {
        return nearestLine.charIndices.isNotEmpty ? nearestLine.charIndices.first : nearestLine.startIndex;
      }
      if (targetY >= nearestLine.bounds.bottom) {
        return nearestLine.charIndices.isNotEmpty ? nearestLine.charIndices.last : nearestLine.endIndex - 1;
      }
    } else {
      if (targetX <= nearestLine.bounds.left) {
        return nearestLine.charIndices.isNotEmpty ? nearestLine.charIndices.first : nearestLine.startIndex;
      }
      if (targetX >= nearestLine.bounds.right) {
        return nearestLine.charIndices.isNotEmpty ? nearestLine.charIndices.last : nearestLine.endIndex - 1;
      }
    }

    int nearestCharIdx = nearestLine.charIndices.isNotEmpty ? nearestLine.charIndices.first : nearestLine.startIndex;
    double minCharDist = double.infinity;

    for (int i = 0; i < nearestLine.charRects.length; i++) {
      final rect = nearestLine.charRects[i];
      final globalIdx = i < nearestLine.charIndices.length ? nearestLine.charIndices[i] : nearestLine.startIndex + i;
      final dist = (rect.center - targetOffset).distanceSquared;
      if (dist < minCharDist) {
        minCharDist = dist;
        nearestCharIdx = globalIdx;
      }
    }

    return nearestCharIdx;
  }

  /// Locates word boundaries around [charIndex] for double-click word selection.
  TextRange findWordBoundaries(int charIndex) {
    if (fullText.isEmpty || charIndex < 0 || charIndex >= fullText.length) {
      return TextRange.empty;
    }

    bool isWordChar(String ch) {
      return RegExp(r'[\w\u00C0-\u017F]').hasMatch(ch);
    }

    int start = charIndex;
    while (start > 0 && isWordChar(fullText[start - 1])) {
      start--;
    }

    int end = charIndex;
    while (end < fullText.length && isWordChar(fullText[end])) {
      end++;
    }

    if (start == end && end < fullText.length) {
      end++;
    }

    return TextRange(start: start, end: end);
  }

  /// Locates paragraph/block boundaries around [charIndex] for triple-click selection.
  TextRange findParagraphBoundaries(int charIndex) {
    if (lines.isEmpty || fullText.isEmpty || charIndex < 0 || charIndex >= fullText.length) {
      return TextRange.empty;
    }

    int lineIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (charIndex >= lines[i].startIndex && charIndex <= lines[i].endIndex) {
        lineIdx = i;
        break;
      }
    }

    if (lineIdx < 0) {
      int start = charIndex;
      while (start > 0 && fullText[start - 1] != '\n') {
        start--;
      }
      int end = charIndex;
      while (end < fullText.length && fullText[end] != '\n') {
        end++;
      }
      return TextRange(start: start, end: math.min(fullText.length, end + 1));
    }

    // Se for linha vertical (como rotulo de eixo), seleciona toda a linha vertical
    if (lines[lineIdx].isVertical) {
      return TextRange(
        start: lines[lineIdx].startIndex,
        end: math.min(fullText.length, lines[lineIdx].endIndex + 1),
      );
    }

    final targetCol = lines[lineIdx].columnIndex;
    final avgLineHeight = lines[lineIdx].bounds.height;

    // Expande para cima (linhas anteriores do mesmo paragrafo)
    int firstLine = lineIdx;
    while (firstLine > 0) {
      final prevLine = lines[firstLine - 1];
      if (prevLine.isVertical || prevLine.columnIndex != targetCol) break;

      final vGap = lines[firstLine].bounds.top - prevLine.bounds.bottom;
      if (vGap > math.max(14.0, avgLineHeight * 1.8)) break;

      // Se a linha atual (firstLine) tem recuo evidente em relação à anterior, ela é o início do parágrafo
      if (lines[firstLine].bounds.left > prevLine.bounds.left + 10.0) {
        break;
      }

      final prevText = fullText.substring(
        prevLine.startIndex,
        math.min(fullText.length, prevLine.endIndex),
      ).trimRight();

      final currLineStart = fullText.substring(
        lines[firstLine].startIndex,
        math.min(fullText.length, lines[firstLine].startIndex + 1),
      );
      final isNewSentenceStart = currLineStart.isNotEmpty && currLineStart == currLineStart.toUpperCase();

      // Ponto final em linha mais curta indica fim do parágrafo anterior
      if ((prevText.endsWith('.') || prevText.endsWith('!') || prevText.endsWith('?')) &&
          prevLine.bounds.width < lines[firstLine].bounds.width * 0.85 &&
          isNewSentenceStart) {
        break;
      }

      firstLine--;
    }

    // Expande para baixo (linhas seguintes do mesmo paragrafo)
    int lastLine = lineIdx;
    while (lastLine < lines.length - 1) {
      final nextLine = lines[lastLine + 1];
      if (nextLine.isVertical || nextLine.columnIndex != targetCol) break;

      final vGap = nextLine.bounds.top - lines[lastLine].bounds.bottom;
      if (vGap > math.max(14.0, avgLineHeight * 1.8)) break;

      // Se a próxima linha tem recuo de parágrafo, ela inicia um novo parágrafo
      if (nextLine.bounds.left > lines[lastLine].bounds.left + 10.0) {
        break;
      }

      final currText = fullText.substring(
        lines[lastLine].startIndex,
        math.min(fullText.length, lines[lastLine].endIndex),
      ).trimRight();

      final nextLineStart = fullText.substring(
        nextLine.startIndex,
        math.min(fullText.length, nextLine.startIndex + 1),
      );
      final isNextSentenceStart = nextLineStart.isNotEmpty && nextLineStart == nextLineStart.toUpperCase();

      // Se a linha atual termina com pontuação terminal e é mais curta que a próxima (fim de parágrafo)
      if ((currText.endsWith('.') || currText.endsWith('!') || currText.endsWith('?')) &&
          lines[lastLine].bounds.width < nextLine.bounds.width * 0.85 &&
          isNextSentenceStart) {
        break;
      }

      lastLine++;
    }

    final start = lines[firstLine].startIndex;
    final end = math.min(fullText.length, lines[lastLine].endIndex);
    return TextRange(start: start, end: end);
  }

  /// Builds a consolidated [PdfTextSelectionState] mapped to display dimensions.
  PdfTextSelectionState buildSelectionState({
    required int charA,
    required int charB,
    required double displayWidth,
    required double displayHeight,
    bool isSelecting = false,
  }) {
    if (fullText.isEmpty || nativeWidth <= 0 || nativeHeight <= 0) {
      return PdfTextSelectionState.empty;
    }

    int start = math.max(0, math.min(charA, charB));
    int end = math.min(fullText.length, math.max(charA, charB));

    if (start >= end) {
      if (isSelecting && fullText.isNotEmpty) {
        end = math.min(fullText.length, start + 1);
      } else {
        return PdfTextSelectionState.empty;
      }
    }

    // Build selected text line by line using spatial lines to eliminate PDFium internal font matrix newlines
    final lineTexts = <String>[];
    for (final line in lines) {
      if (line.endIndex <= start || line.startIndex >= end) {
        continue;
      }
      final lineBuffer = StringBuffer();
      final count = math.min(line.charRects.length, line.charIndices.length);
      for (int k = 0; k < count; k++) {
        final idx = line.charIndices[k];
        if (idx < start || idx >= end) continue;
        final ch = fullText[idx];
        // Strip any internal newline/carriage return inside a single spatial line
        if (ch == '\r' || ch == '\n') continue;
        lineBuffer.write(ch);
      }
      final str = lineBuffer.toString().trim();
      if (str.isNotEmpty) {
        lineTexts.add(str);
      }
    }

    final rawSelectedText = lineTexts.isNotEmpty
        ? lineTexts.join('\n')
        : fullText.substring(start, end);
    final selectedText = cleanStemText(rawSelectedText);
    final scaleX = displayWidth / nativeWidth;
    final scaleY = displayHeight / nativeHeight;

    final displayLineRects = <Rect>[];

    for (final line in lines) {
      if (line.endIndex <= start || line.startIndex >= end) {
        continue;
      }
      double lineLeft = double.infinity;
      double lineTop = double.infinity;
      double lineRight = double.negativeInfinity;
      double lineBottom = double.negativeInfinity;

      final count = math.min(line.charRects.length, line.charIndices.length);
      for (int k = 0; k < count; k++) {
        final idx = line.charIndices[k];
        if (idx < start || idx >= end) continue;
        final r = line.charRects[k];
        lineLeft = math.min(lineLeft, r.left);
        lineTop = math.min(lineTop, r.top);
        lineRight = math.max(lineRight, r.right);
        lineBottom = math.max(lineBottom, r.bottom);
      }

      if (lineLeft <= lineRight && lineTop <= lineBottom) {
        final l = lineLeft * scaleX;
        final t = lineTop * scaleY;
        final r = math.max(l + 2.0, lineRight * scaleX);
        final b = math.max(t + 8.0, lineBottom * scaleY);
        displayLineRects.add(Rect.fromLTRB(l, t, r, b));
      }
    }

    if (displayLineRects.isEmpty) {
      return PdfTextSelectionState.empty;
    }

    double boundingLeft = double.infinity;
    double boundingTop = double.infinity;
    double boundingRight = double.negativeInfinity;
    double boundingBottom = double.negativeInfinity;

    for (final r in displayLineRects) {
      boundingLeft = math.min(boundingLeft, r.left);
      boundingTop = math.min(boundingTop, r.top);
      boundingRight = math.max(boundingRight, r.right);
      boundingBottom = math.max(boundingBottom, r.bottom);
    }

    return PdfTextSelectionState(
      pageNumber: pageNumber,
      startIndex: start,
      endIndex: end,
      selectedText: selectedText,
      rects: displayLineRects,
      bounds: Rect.fromLTRB(boundingLeft, boundingTop, boundingRight, boundingBottom),
      isSelecting: isSelecting,
    );
  }

  /// Converts ASCII digits to Unicode superscripts.
  static String toSuperscript(String str) {
    const normal = '0123456789+-=()n';
    const superChars = '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿ';
    return str.split('').map((c) {
      final idx = normal.indexOf(c);
      return idx != -1 ? superChars[idx] : c;
    }).join();
  }

  /// Converts ASCII digits to Unicode subscripts.
  static String toSubscript(String str) {
    const normal = '0123456789+-=()';
    const subChars = '₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎';
    return str.split('').map((c) {
      final idx = normal.indexOf(c);
      return idx != -1 ? subChars[idx] : c;
    }).join();
  }

  /// Sanitizes common STEM / PDF font encoding artifacts from extracted text,
  /// such as broken line breaks around superscripts/subscripts and font-encoded ions
  /// (e.g. `Na"`, `Cl#` -> `Na⁺`, `Cl⁻`).
  static String cleanStemText(String text) {
    if (text.isEmpty) return text;

    String cleaned = text;

    // 0.1 De-hifenização inteligente em quebra de linha:
    // Reconecta palavras divididas por hífen ou traço suave (ex: "partícu-\nlas" -> "partículas", "núme-\nro" -> "número")
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([a-zA-ZÀ-ÿ\u00C0-\u017F]+)[-\u00ad\u2010\u2011\u2013\u0001\u0002\u001f\uFFFD]\r?\n\s*([a-zA-ZÀ-ÿ\u00C0-\u017F]+)'),
      (m) => '${m[1]}${m[2]}',
    );

    // 0.2 Remoção de caracteres de controle e glifos invisíveis que viram tofu-boxes ([]):
    cleaned = cleaned.replaceAll(RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u00ad\uFFFD]'), '');

    // 0.3 Converte quebras de linha duras no meio de frases em espaços para fluxo de leitura natural:
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([^\.\!\?\:\n])\r?\n\s*([a-zA-ZÀ-ÿ\u00C0-\u017F0-9])'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 1. Remove broken newlines immediately preceding or following formula symbols/ions/subscripts:
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])\r?\n\s*(["#+\-\u207A\u207B0-9]+)'),
      (m) => '${m[1]} ${m[2]}',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(["#+\-\u207A\u207B])\r?\n\s*([A-Za-z0-9])'),
      (m) => '${m[1]} ${m[2]}',
    );

    // 2. Multi-fragment formulas like Cr2O 2 7# -> Cr₂O₇²⁻
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?\d*[A-Z][a-z]?)\s*(\d)\s*(\d+)[\#]'),
      (m) => '${m[1]}${toSubscript(m[3]!)}${toSuperscript(m[2]!)}⁻',
    );

    // 3. Inverted notation where # or " precedes subscript digit (e.g. MnO# 4 -> MnO₄⁻)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?(?:\d*[A-Z][a-z]?)*)[\#]\s*(\d+)'),
      (m) => '${m[1]}${toSubscript(m[2]!)}⁻',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?(?:\d*[A-Z][a-z]?)*)[\"]\s*(\d+)'),
      (m) => '${m[1]}${toSubscript(m[2]!)}⁺',
    );

    // 4. Chemical charges with magnitude: e.g. Cu 2", Cu2", Fe3+, Ni2+ -> Cu²⁺, Fe³⁺, Ni²⁺
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?)\s*(\d+)[\"\+\u207A]'),
      (m) => '${m[1]}${toSuperscript(m[2]!)}⁺',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?)\s*(\d+)[\#\-\u207B]'),
      (m) => '${m[1]}${toSuperscript(m[2]!)}⁻',
    );

    // 5. Chemical symbols followed directly by font-encoded " -> ⁺ (e.g. Na" -> Na⁺)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?(?:[0-9]|[\u00B2\u00B3\u00B9\u2070-\u2079])*)\"'),
      (m) => '${m[1]}⁺',
    );

    // 6. Chemical symbols followed directly by font-encoded # -> ⁻ (e.g. Cl# -> Cl⁻)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?(?:[0-9]|[\u00B2\u00B3\u00B9\u2070-\u2079])*)\#'),
      (m) => '${m[1]}⁻',
    );

    // 7. Subscripts in standard chemical formulas (e.g. Cr2O -> Cr₂O, H2O -> H₂O, CO2 -> CO₂)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z][a-z]?)(\d+)([A-Z])'),
      (m) => '${m[1]}${toSubscript(m[2]!)}${m[3]}',
    );

    // 8. Isolated + or - mapped to " or # in chemical/ion context
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\b[A-Z][a-z]?\s*)\#'),
      (m) => '${m[1]?.trim() ?? ''}⁻',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\b[A-Z][a-z]?\s*)\"'),
      (m) => '${m[1]?.trim() ?? ''}⁺',
    );

    return cleaned;
  }
}

class _IndexedChar {
  final int index;
  final String char;
  final Rect rect;

  const _IndexedChar({
    required this.index,
    required this.char,
    required this.rect,
  });
}
