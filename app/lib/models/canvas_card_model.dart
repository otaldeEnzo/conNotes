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
  double minHeight;
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
    this.minHeight = 40.0,
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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
      minHeight: minHeight ?? this.minHeight,
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
