import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Span de formatação rica em memória
class RichStyleSpan {
  int start;
  int end;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  bool isSubscript;
  bool isSuperscript;
  bool isCode;
  bool isLatex;
  Color? textColor;
  Color? highlightColor;
  double? fontSize;

  RichStyleSpan({
    required this.start,
    required this.end,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isSubscript = false,
    this.isSuperscript = false,
    this.isCode = false,
    this.isLatex = false,
    this.textColor,
    this.highlightColor,
    this.fontSize,
  });

  bool get isEmptyStyle =>
      !isBold &&
      !isItalic &&
      !isUnderline &&
      !isStrikethrough &&
      !isSubscript &&
      !isSuperscript &&
      !isCode &&
      !isLatex &&
      textColor == null &&
      highlightColor == null &&
      fontSize == null;

  bool hasSameStyleAs(RichStyleSpan other) {
    return isBold == other.isBold &&
        isItalic == other.isItalic &&
        isUnderline == other.isUnderline &&
        isStrikethrough == other.isStrikethrough &&
        isSubscript == other.isSubscript &&
        isSuperscript == other.isSuperscript &&
        isCode == other.isCode &&
        isLatex == other.isLatex &&
        textColor == other.textColor &&
        highlightColor == other.highlightColor &&
        fontSize == other.fontSize;
  }

  RichStyleSpan copyWith({
    int? start,
    int? end,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    bool? isSubscript,
    bool? isSuperscript,
    bool? isCode,
    bool? isLatex,
    Color? textColor,
    Color? highlightColor,
    double? fontSize,
  }) {
    return RichStyleSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      isSubscript: isSubscript ?? this.isSubscript,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isCode: isCode ?? this.isCode,
      isLatex: isLatex ?? this.isLatex,
      textColor: textColor ?? this.textColor,
      highlightColor: highlightColor ?? this.highlightColor,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

/// Controlador de Edição de Texto Rico 100% WYSIWYG (Zero Tags Visíveis).
/// Renderiza estilos (Negrito, Itálico, Sublinhado, LaTeX, Cores, Marca-Texto, Sub/Sobrescrito)
/// diretamente com partições disjuntas e suporte completo a estilo de digitação pré-ativo.
class MoscaroRichTextController extends TextEditingController {
  final List<RichStyleSpan> styleSpans = [];
  RichStyleSpan typingStyle = RichStyleSpan(start: 0, end: 0);
  bool hasActiveTypingStyle = false;

  Color defaultTextColor;
  Color defaultHighlightColor;
  Color themeAccent;

  MoscaroRichTextController({
    super.text,
    this.defaultTextColor = Colors.white,
    this.defaultHighlightColor = const Color(0xFFFACC15),
    this.themeAccent = const Color(0xFF00E1FF),
  }) {
    if (text.isNotEmpty) {
      loadFromFormattedText(text);
    }
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    // Delta tracking automático de inserção/deleção
    if (oldText != newText) {
      _applyTextDelta(oldText, newText);
    }

    super.value = newValue;
  }

  void _applyTextDelta(String oldText, String newText) {
    int commonPrefix = 0;
    while (commonPrefix < oldText.length &&
        commonPrefix < newText.length &&
        oldText[commonPrefix] == newText[commonPrefix]) {
      commonPrefix++;
    }

    int commonSuffix = 0;
    while (commonSuffix < (oldText.length - commonPrefix) &&
        commonSuffix < (newText.length - commonPrefix) &&
        oldText[oldText.length - 1 - commonSuffix] == newText[newText.length - 1 - commonSuffix]) {
      commonSuffix++;
    }

    final deletedCount = oldText.length - commonPrefix - commonSuffix;
    final insertedCount = newText.length - commonPrefix - commonSuffix;
    final changeIndex = commonPrefix;
    final delta = insertedCount - deletedCount;

    final updatedSpans = <RichStyleSpan>[];
    for (final span in styleSpans) {
      int s = span.start;
      int e = span.end;

      if (e <= changeIndex) {
        if (s < e) updatedSpans.add(span);
      } else if (s >= changeIndex + deletedCount) {
        span.start = s + delta;
        span.end = e + delta;
        if (span.start < span.end && span.start < newText.length) {
          span.start = span.start.clamp(0, newText.length);
          span.end = span.end.clamp(span.start, newText.length);
          updatedSpans.add(span);
        }
      } else {
        if (deletedCount > 0) {
          final overlapStart = math.max(s, changeIndex);
          final overlapEnd = math.min(e, changeIndex + deletedCount);
          final removedInSpan = overlapEnd - overlapStart;
          span.end = math.max(span.start, e - removedInSpan);
        }
        if (insertedCount > 0 && changeIndex >= s && changeIndex <= e) {
          span.end += insertedCount;
        }
        span.start = span.start.clamp(0, newText.length);
        span.end = span.end.clamp(span.start, newText.length);
        if (span.start < span.end) {
          updatedSpans.add(span);
        }
      }
    }

    // Se novos caracteres foram digitados com estilo de digitação ativo (typingStyle)
    if (insertedCount > 0 && hasActiveTypingStyle) {
      updatedSpans.add(RichStyleSpan(
        start: changeIndex,
        end: changeIndex + insertedCount,
        isBold: typingStyle.isBold,
        isItalic: typingStyle.isItalic,
        isUnderline: typingStyle.isUnderline,
        isStrikethrough: typingStyle.isStrikethrough,
        isSubscript: typingStyle.isSubscript,
        isSuperscript: typingStyle.isSuperscript,
        isCode: typingStyle.isCode,
        isLatex: typingStyle.isLatex,
        textColor: typingStyle.textColor,
        highlightColor: typingStyle.highlightColor,
        fontSize: typingStyle.fontSize,
      ));
    }

    styleSpans
      ..clear()
      ..addAll(updatedSpans);

    _normalizeSpans();
  }

  void _splitSpansAt(int offset) {
    if (offset <= 0 || offset >= text.length) return;
    final toAdd = <RichStyleSpan>[];
    for (final s in styleSpans) {
      if (s.start < offset && s.end > offset) {
        toAdd.add(s.copyWith(start: offset, end: s.end));
        s.end = offset;
      }
    }
    styleSpans.addAll(toAdd);
  }

  void _fillGapsInRange(int start, int end) {
    if (start >= end) return;
    styleSpans.sort((a, b) => a.start.compareTo(b.start));
    final inRange = styleSpans.where((s) => s.start >= start && s.end <= end).toList();

    int current = start;
    final gaps = <RichStyleSpan>[];
    for (final s in inRange) {
      if (s.start > current) {
        gaps.add(RichStyleSpan(start: current, end: s.start));
      }
      current = math.max(current, s.end);
    }
    if (current < end) {
      gaps.add(RichStyleSpan(start: current, end: end));
    }
    styleSpans.addAll(gaps);
  }

  void _normalizeSpans() {
    if (styleSpans.isEmpty) return;
    styleSpans.removeWhere((s) => s.start >= s.end || s.isEmptyStyle);
    if (styleSpans.length <= 1) return;

    styleSpans.sort((a, b) => a.start.compareTo(b.start));
    final merged = <RichStyleSpan>[];
    for (final s in styleSpans) {
      if (s.start >= s.end || s.isEmptyStyle) continue;
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.end >= s.start && last.hasSameStyleAs(s)) {
          last.end = math.max(last.end, s.end);
          continue;
        }
      }
      merged.add(s);
    }
    styleSpans
      ..clear()
      ..addAll(merged);
  }

  /// Carrega o texto puro e extrai recursivamente as tags Markdown/HTML para spans em memória (WYSIWYG 100% limpo)
  void loadFromFormattedText(String raw) {
    styleSpans.clear();
    hasActiveTypingStyle = false;
    typingStyle = RichStyleSpan(start: 0, end: 0);

    final cleanBuffer = StringBuffer();

    void parseRecursive(String input, RichStyleSpan currentStyle) {
      final pattern = RegExp(
        r'(\*\*([\s\S]*?)\*\*)|' // 1,2: Bold
        r'(\*([^\*\n]+)\*)|' // 3,4: Italic
        r'(<u>([\s\S]*?)<\/u>)|' // 5,6: Underline
        r'(~~([\s\S]*?)~~)|' // 7,8: Strikethrough
        r'(`([^`\n]+)`)|' // 9,10: Inline Code
        r'(\$([^\$\n]+)\$)|' // 11,12: Inline LaTeX
        r'(<sub>([\s\S]*?)<\/sub>)|' // 13,14: Subscript
        r'(<sup>([\s\S]*?)<\/sup>)|' // 15,16: Superscript
        r'(<mark style="background:\s*([^"]+)">([\s\S]*?)<\/mark>)|' // 17,18,19: Styled Mark
        r'(<mark>([\s\S]*?)<\/mark>)|' // 20,21: Plain Mark
        r'(==([\s\S]*?)==)|' // 22,23: ==Mark==
        r'(<span style="color:\s*([^"]+)">([\s\S]*?)<\/span>)|' // 24,25,26: Color Span
        r'(<font color="([^"]+)">([\s\S]*?)<\/font>)|' // 27,28,29: Font Color
        r'(<span style="font-size:\s*([0-9.]+)px">([\s\S]*?)<\/span>)', // 30,31,32: Font Size Span
      );

      int lastEnd = 0;
      for (final match in pattern.allMatches(input)) {
        if (match.start > lastEnd) {
          final plain = input.substring(lastEnd, match.start);
          final startPos = cleanBuffer.length;
          cleanBuffer.write(plain);
          if (!currentStyle.isEmptyStyle) {
            styleSpans.add(currentStyle.copyWith(start: startPos, end: startPos + plain.length));
          }
        }

        String inner = '';
        RichStyleSpan nextStyle = currentStyle.copyWith();

        if (match.group(1) != null) {
          inner = match.group(2)!;
          nextStyle.isBold = true;
        } else if (match.group(3) != null) {
          inner = match.group(4)!;
          nextStyle.isItalic = true;
        } else if (match.group(5) != null) {
          inner = match.group(6)!;
          nextStyle.isUnderline = true;
        } else if (match.group(7) != null) {
          inner = match.group(8)!;
          nextStyle.isStrikethrough = true;
        } else if (match.group(9) != null) {
          inner = match.group(10)!;
          nextStyle.isCode = true;
        } else if (match.group(11) != null) {
          inner = match.group(12)!;
          nextStyle.isLatex = true;
        } else if (match.group(13) != null) {
          inner = match.group(14)!;
          nextStyle.isSubscript = true;
        } else if (match.group(15) != null) {
          inner = match.group(16)!;
          nextStyle.isSuperscript = true;
        } else if (match.group(17) != null) {
          final hex = match.group(18) ?? '#FACC15';
          inner = match.group(19)!;
          nextStyle.highlightColor = _parseHexColor(hex, defaultHighlightColor);
        } else if (match.group(20) != null || match.group(22) != null) {
          inner = match.group(21) ?? match.group(23) ?? '';
          nextStyle.highlightColor = defaultHighlightColor;
        } else if (match.group(24) != null || match.group(27) != null) {
          final hex = match.group(25) ?? match.group(28) ?? '';
          inner = match.group(26) ?? match.group(29) ?? '';
          nextStyle.textColor = _parseHexColor(hex, defaultTextColor);
        } else if (match.group(30) != null) {
          final sizeStr = match.group(31) ?? '';
          inner = match.group(32) ?? '';
          nextStyle.fontSize = double.tryParse(sizeStr);
        }

        parseRecursive(inner, nextStyle);
        lastEnd = match.end;
      }

      if (lastEnd < input.length) {
        final plain = input.substring(lastEnd);
        final startPos = cleanBuffer.length;
        cleanBuffer.write(plain);
        if (!currentStyle.isEmptyStyle) {
          styleSpans.add(currentStyle.copyWith(start: startPos, end: startPos + plain.length));
        }
      }
    }

    parseRecursive(raw, RichStyleSpan(start: 0, end: 0));
    text = cleanBuffer.toString();
    _normalizeSpans();
  }

  /// Converte o texto puro e spans em Markdown formatado para persistência
  String toFormattedText() {
    if (styleSpans.isEmpty) return text;

    final sorted = List<RichStyleSpan>.from(styleSpans)
      ..sort((a, b) => a.start.compareTo(b.start));

    final sb = StringBuffer();
    int lastEnd = 0;

    for (final s in sorted) {
      final safeStart = s.start.clamp(0, text.length);
      final safeEnd = s.end.clamp(safeStart, text.length);

      if (safeStart > lastEnd) {
        sb.write(text.substring(lastEnd, safeStart));
      }

      if (safeEnd > safeStart) {
        String chunk = text.substring(safeStart, safeEnd);

        final lines = chunk.split('\n');
        final formattedLines = lines.map((line) {
          if (line.isEmpty) return line;
          String l = line;
          if (s.isCode) l = '`$l`';
          if (s.isLatex) l = '\$$l\$';
          if (s.isSubscript) l = '<sub>$l</sub>';
          if (s.isSuperscript) l = '<sup>$l</sup>';
          if (s.isBold) l = '**$l**';
          if (s.isItalic) l = '*$l*';
          if (s.isUnderline) l = '<u>$l</u>';
          if (s.isStrikethrough) l = '~~$l~~';
          if (s.textColor != null) {
            final hex = '#${s.textColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
            l = '<span style="color: $hex">$l</span>';
          }
          if (s.highlightColor != null) {
            final hex = '#${s.highlightColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
            l = '<mark style="background: $hex">$l</mark>';
          }
          if (s.fontSize != null) {
            l = '<span style="font-size: ${s.fontSize}px">$l</span>';
          }
          return l;
        });

        chunk = formattedLines.join('\n');
        sb.write(chunk);
      }
      lastEnd = safeEnd;
    }

    if (lastEnd < text.length) {
      sb.write(text.substring(lastEnd));
    }

    return sb.toString();
  }

  /// Aplica ou remove formatação no intervalo selecionado ou ativa estilo para digitação subsequente
  void toggleFormatting({
    bool? toggleBold,
    bool? toggleItalic,
    bool? toggleUnderline,
    bool? toggleStrikethrough,
    bool? toggleSubscript,
    bool? toggleSuperscript,
    bool? toggleCode,
    bool? toggleLatex,
    Color? setTextColor,
    Color? setHighlightColor,
    double? setFontSize,
  }) {
    final sel = selection;
    final bool hasSelection = sel.isValid && sel.start >= 0 && sel.end >= 0 && sel.start != sel.end;

    // 1. Caso o cursor esteja colapsado ou não haja seleção de caracteres (ativa estilo para o próximo texto digitado)
    if (!hasSelection) {
      if (toggleBold == true) typingStyle.isBold = !typingStyle.isBold;
      if (toggleItalic == true) typingStyle.isItalic = !typingStyle.isItalic;
      if (toggleUnderline == true) typingStyle.isUnderline = !typingStyle.isUnderline;
      if (toggleStrikethrough == true) typingStyle.isStrikethrough = !typingStyle.isStrikethrough;
      if (toggleSubscript == true) {
        typingStyle.isSubscript = !typingStyle.isSubscript;
        if (typingStyle.isSubscript) typingStyle.isSuperscript = false;
      }
      if (toggleSuperscript == true) {
        typingStyle.isSuperscript = !typingStyle.isSuperscript;
        if (typingStyle.isSuperscript) typingStyle.isSubscript = false;
      }
      if (toggleCode == true) typingStyle.isCode = !typingStyle.isCode;
      if (toggleLatex == true) typingStyle.isLatex = !typingStyle.isLatex;
      if (setTextColor != null) typingStyle.textColor = setTextColor;
      if (setHighlightColor != null) typingStyle.highlightColor = setHighlightColor;
      if (setFontSize != null) typingStyle.fontSize = setFontSize;

      hasActiveTypingStyle = !typingStyle.isEmptyStyle;
      notifyListeners();
      return;
    }

    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);

    // 2. Caso haja caracteres selecionados (start < end)
    _splitSpansAt(start);
    _splitSpansAt(end);

    final spansInRange = styleSpans.where((s) => s.start >= start && s.end <= end).toList();

    final allBold = spansInRange.isNotEmpty && spansInRange.every((s) => s.isBold);
    final allItalic = spansInRange.isNotEmpty && spansInRange.every((s) => s.isItalic);
    final allUnderline = spansInRange.isNotEmpty && spansInRange.every((s) => s.isUnderline);
    final allStrikethrough = spansInRange.isNotEmpty && spansInRange.every((s) => s.isStrikethrough);
    final allSubscript = spansInRange.isNotEmpty && spansInRange.every((s) => s.isSubscript);
    final allSuperscript = spansInRange.isNotEmpty && spansInRange.every((s) => s.isSuperscript);
    final allCode = spansInRange.isNotEmpty && spansInRange.every((s) => s.isCode);
    final allLatex = spansInRange.isNotEmpty && spansInRange.every((s) => s.isLatex);
    final allSameHighlight = setHighlightColor != null && spansInRange.isNotEmpty && spansInRange.every((s) => s.highlightColor == setHighlightColor);
    final allSameTextColor = setTextColor != null && spansInRange.isNotEmpty && spansInRange.every((s) => s.textColor == setTextColor);

    _fillGapsInRange(start, end);

    final targetSpans = styleSpans.where((s) => s.start >= start && s.end <= end).toList();
    for (final s in targetSpans) {
      if (toggleBold == true) s.isBold = !allBold;
      if (toggleItalic == true) s.isItalic = !allItalic;
      if (toggleUnderline == true) s.isUnderline = !allUnderline;
      if (toggleStrikethrough == true) s.isStrikethrough = !allStrikethrough;
      if (toggleSubscript == true) {
        s.isSubscript = !allSubscript;
        if (s.isSubscript) s.isSuperscript = false;
      }
      if (toggleSuperscript == true) {
        s.isSuperscript = !allSuperscript;
        if (s.isSuperscript) s.isSubscript = false;
      }
      if (toggleCode == true) s.isCode = !allCode;
      if (toggleLatex == true) s.isLatex = !allLatex;
      if (setHighlightColor != null) {
        s.highlightColor = allSameHighlight ? null : setHighlightColor;
      }
      if (setTextColor != null) {
        s.textColor = allSameTextColor ? null : setTextColor;
      }
      if (setFontSize != null) s.fontSize = setFontSize;
    }

    _normalizeSpans();
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final baseStyle = style ?? TextStyle(color: defaultTextColor, fontSize: 14);

    if (styleSpans.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }

    final spans = <InlineSpan>[];
    int current = 0;

    final sorted = List<RichStyleSpan>.from(styleSpans)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final s in sorted) {
      final safeStart = s.start.clamp(0, text.length);
      final safeEnd = s.end.clamp(safeStart, text.length);

      if (safeStart > current) {
        spans.add(TextSpan(
          text: text.substring(current, safeStart),
          style: baseStyle,
        ));
      }

      if (safeEnd > safeStart) {
        TextStyle spanStyle = baseStyle;

        if (s.isBold) {
          spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (s.isItalic) {
          spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (s.isUnderline) {
          spanStyle = spanStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: themeAccent,
            decorationThickness: 1.5,
          );
        }
        if (s.isStrikethrough) {
          spanStyle = spanStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if (s.isCode) {
          spanStyle = spanStyle.copyWith(
            fontFamily: 'JetBrains Mono, monospace',
            color: themeAccent,
            backgroundColor: themeAccent.withValues(alpha: 0.12),
          );
        }
        if (s.isLatex) {
          spanStyle = spanStyle.copyWith(
            fontFamily: 'KaTeX_Math, serif',
            fontStyle: FontStyle.italic,
            color: const Color(0xFF00FFCC),
          );
        }
        if (s.textColor != null) {
          spanStyle = spanStyle.copyWith(color: s.textColor);
        }
        if (s.highlightColor != null) {
          spanStyle = spanStyle.copyWith(
            backgroundColor: s.highlightColor!.withValues(alpha: 0.38),
          );
        }
        if (s.isSubscript || s.isSuperscript) {
          spanStyle = spanStyle.copyWith(
            fontSize: (spanStyle.fontSize ?? 14.0) * 0.8,
          );
        }
        if (s.fontSize != null) {
          spanStyle = spanStyle.copyWith(fontSize: s.fontSize);
        }

        spans.add(TextSpan(
          text: text.substring(safeStart, safeEnd),
          style: spanStyle,
        ));
      }

      current = math.max(current, safeEnd);
    }

    if (current < text.length) {
      spans.add(TextSpan(
        text: text.substring(current),
        style: baseStyle,
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      String clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return fallback;
  }
}
