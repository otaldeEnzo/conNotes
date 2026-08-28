import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Variável global para rastrear se algum campo de texto (bloco, título, etc) está sendo editado.
/// Utilizada para impedir que atalhos globais (como Delete/Backspace) interfiram na digitação.
bool globalIsEditingText = false;

/// Modelo de Dados para Cards no Canvas Infinito (Texto, Markdown, LaTeX & Mermaid).
class CanvasCardModel {
  final String id;
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
  final DateTime createdAt;
  DateTime updatedAt;

  CanvasCardModel({
    required this.id,
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
    this.customGlassColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : _manualMinHeight = minHeight,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Retorna a altura mínima requerida para acomodar todo o conteúdo sem barras de rolagem
  double get minHeight => calculateMinHeight();

  /// Retorna a área mínima (largura * altura mínima) requerida pelo conteúdo.
  double get minArea => width * calculateMinHeight();

  /// Calcula a altura mínima necessária para que todo o conteúdo do card caiba
  /// perfeitamente sem gerar barras de rolagem (scroll) ou avisos de overflow.
  double calculateMinHeight() {
    if (isCollapsed) return 36.0;

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
        contentHeight += (fontSize * 3.0) + 28.0;
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

    final totalMin = headerHeight + paddingVertical + contentHeight + 24.0;
    return math.max(110.0, totalMin);
  }

  CanvasCardModel copyWith({
    String? id,
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
    Color? customGlassColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanvasCardModel(
      id: id ?? this.id,
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
      customGlassColor: customGlassColor ?? this.customGlassColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'customGlassColor': customGlassColor?.toARGB32(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

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

    return CanvasCardModel(
      id: map['id']?.toString() ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title']?.toString() ?? 'Card STEM',
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
      customGlassColor: map['customGlassColor'] != null ? Color(map['customGlassColor'] as int) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
    );
  }
}
