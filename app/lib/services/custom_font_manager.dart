import 'package:flutter/material.dart';

/// Gerenciador de Fontes do conNotes (Fontes Nativas + Fontes do Sistema Adicionadas pelo Usuário).
class CustomFontManager extends ChangeNotifier {
  CustomFontManager._internal();
  static final CustomFontManager instance = CustomFontManager._internal();

  static const List<String> standardFonts = [
    'Inter',
    'Outfit',
    'Fira Code',
    'JetBrains Mono',
    'Roboto',
    'Times New Roman',
    'Arial',
    'Georgia',
    'Consolas',
    'Courier New',
    'KaTeX Math',
  ];

  final List<String> _userFonts = [];

  List<String> get availableFonts => [...standardFonts, ..._userFonts];
  List<String> get userFonts => List.unmodifiable(_userFonts);

  void initialize(List<String> savedUserFonts) {
    _userFonts.clear();
    _userFonts.addAll(savedUserFonts);
    notifyListeners();
  }

  void addFont(String fontName) {
    final trimmed = fontName.trim();
    if (trimmed.isEmpty) return;
    if (!availableFonts.contains(trimmed)) {
      _userFonts.add(trimmed);
      notifyListeners();
    }
  }

  void removeFont(String fontName) {
    if (_userFonts.remove(fontName)) {
      notifyListeners();
    }
  }
}
