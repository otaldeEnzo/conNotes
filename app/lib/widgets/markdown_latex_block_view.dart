import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../models/canvas_card_model.dart';
import 'mermaid_diagram_painter_view.dart';
import 'moscaro_rich_text_controller.dart';
import 'card_slash_command_popover.dart';
import 'card_format_floating_pill.dart';
import 'card_latex_editor_popover.dart';
import 'stem_callout_box_view.dart';
import 'svg_icon.dart';

enum BlockType {
  heading,
  latexBlock,
  codeBlock,
  mermaidBlock,
  calloutBlock,
  markdownText,
}

class ParsedContentBlock {
  final int index;
  final BlockType type;
  final String rawText;
  final String? language;
  final StemCalloutType? calloutType;

  const ParsedContentBlock({
    required this.index,
    required this.type,
    required this.rawText,
    this.language,
    this.calloutType,
  });
}

/// Renderizador de Conteúdo por Blocos no Estilo Notion / Obsidian (Live Preview + Moscaro Theme).
class MarkdownLatexBlockView extends StatefulWidget {
  final CanvasCardModel card;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<CardActiveTextStyles>? onActiveStylesChanged;
  final ValueChanged<bool>? onEditingModeChanged;
  final bool isInteractive;
  final VoidCallback? onSelectCard;
  final bool isSelected;

  const MarkdownLatexBlockView({
    super.key,
    required this.card,
    required this.onContentChanged,
    this.onActiveStylesChanged,
    this.onEditingModeChanged,
    this.isInteractive = true,
    this.onSelectCard,
    this.isSelected = false,
  });

  @override
  State<MarkdownLatexBlockView> createState() => MarkdownLatexBlockViewState();
}

class MarkdownLatexBlockViewState extends State<MarkdownLatexBlockView> {
  int? _editingBlockIndex;
  int? _hoveredBlockIndex;
  Offset? _lastEmptyAreaDoubleTapPos;
  late MoscaroRichTextController _blockController;
  late FocusNode _blockFocusNode;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);

  // Estados de Popovers Dinâmicos
  bool _showSlashMenu = false;
  String _slashQuery = '';
  DateTime? _timeBecameEmpty;

  // Cache para Performance O(1) de Build & Layout (Evita recriar Math.tex a cada frame)
  String? _lastParsedContent;
  bool? _lastIsLight;
  Color? _lastTextPrimary;
  Color? _lastThemeAccent;
  String? _lastFontFamily;
  double? _lastFontSize;
  List<ParsedContentBlock>? _cachedParsedBlocks;
  final Map<int, Widget> _cachedBlockWidgets = {};

  bool _isCacheValid(bool isLight, Color textPrimary, Color themeAccent, String fontFamily, double fontSize) {
    return _lastParsedContent == widget.card.content &&
           _lastIsLight == isLight &&
           _lastTextPrimary == textPrimary &&
           _lastThemeAccent == themeAccent &&
           _lastFontFamily == fontFamily &&
           _lastFontSize == fontSize &&
           _cachedParsedBlocks != null;
  }

  void _updateCache(bool isLight, Color textPrimary, Color themeAccent, String fontFamily, double fontSize) {
    _lastParsedContent = widget.card.content;
    _lastIsLight = isLight;
    _lastTextPrimary = textPrimary;
    _lastThemeAccent = themeAccent;
    _lastFontFamily = fontFamily;
    _lastFontSize = fontSize;
    
    _cachedParsedBlocks = _parseContentIntoBlocks(widget.card.content);
    _cachedBlockWidgets.clear();
    for (final block in _cachedParsedBlocks!) {
      _cachedBlockWidgets[block.index] = _buildBlockContent(block, isLight, themeAccent, textPrimary, fontFamily, fontSize);
    }
  }

  @override
  void initState() {
    super.initState();
    _blockController = MoscaroRichTextController(
      defaultTextColor: widget.card.textColor ?? MoscaroTokens.textPrimary,
      themeAccent: MoscaroTokens.auroraBlue,
    );

    _blockController.addListener(_handleControllerChange);
    _blockFocusNode = FocusNode();
    _blockFocusNode.addListener(() {
      globalIsEditingText = _blockFocusNode.hasFocus;
    });
  }

  void _handleControllerChange() {
    final text = _blockController.text;
    final sel = _blockController.selection;

    // Preserva a seleção de texto sempre que for válida
    if (sel.isValid && sel.start >= 0) {
      if (sel.end >= sel.start) {
        _lastSelection = sel;
      }
    }

    // Rastreia quando o bloco fica vazio para impedir exclusão acidental via Backspace
    if (text.isEmpty) {
      _timeBecameEmpty ??= DateTime.now();
    } else {
      _timeBecameEmpty = null;
    }

    // Notifica estilos ativos para iluminar botões na barra flutuante
    widget.onActiveStylesChanged?.call(getActiveStyles());

    // Detecção ESTRITA de Slash Commands (/):
    // Nunca abre se houver seleção de texto ativa
    if (sel.isValid && sel.isCollapsed && sel.start > 0) {
      final cursorPos = sel.start;
      final textBeforeCursor = text.substring(0, cursorPos);
      final lastSlashIndex = textBeforeCursor.lastIndexOf('/');

      if (lastSlashIndex >= 0) {
        final isAtStartOrAfterSpace = lastSlashIndex == 0 ||
            textBeforeCursor[lastSlashIndex - 1] == ' ' ||
            textBeforeCursor[lastSlashIndex - 1] == '\n';

        final queryAfterSlash = textBeforeCursor.substring(lastSlashIndex);
        final hasSpaceInQuery = queryAfterSlash.contains(' ') || queryAfterSlash.contains('\n');

        if (isAtStartOrAfterSpace && !hasSpaceInQuery && queryAfterSlash.length <= 20) {
          if (!_showSlashMenu || _slashQuery != queryAfterSlash) {
            setState(() {
              _showSlashMenu = true;
              _slashQuery = queryAfterSlash;
            });
          }
          return;
        }
      }
    }

    if (_showSlashMenu) {
      setState(() => _showSlashMenu = false);
    }
  }

  CardActiveTextStyles getActiveStyles() {
    if (_editingBlockIndex == null) return const CardActiveTextStyles();
    final style = _blockController.getActiveStyleAtCurrentSelection();
    final sel = _blockController.selection;
    String? selectedText;
    if (sel.isValid && !sel.isCollapsed && sel.start >= 0 && sel.end <= _blockController.text.length) {
      selectedText = _blockController.text.substring(sel.start, sel.end);
    }
    return CardActiveTextStyles(
      isBold: style.isBold,
      isItalic: style.isItalic,
      isUnderline: style.isUnderline,
      isStrikethrough: style.isStrikethrough,
      isSubscript: style.isSubscript,
      isSuperscript: style.isSuperscript,
      isCode: style.isCode,
      isLatex: style.isLatex,
      selectedText: selectedText,
      textColor: style.textColor,
      highlightColor: style.highlightColor,
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
    );
  }

  bool get isEditing => _editingBlockIndex != null;

  @override
  void dispose() {
    _blockController.removeListener(_handleControllerChange);
    _blockController.dispose();
    _blockFocusNode.dispose();
    super.dispose();
  }

  List<ParsedContentBlock> _parseContentIntoBlocks(String content) {
    if (content.isEmpty || (!content.contains('\n---\n') && content.trim().isEmpty)) {
      return [
        const ParsedContentBlock(
          index: 0,
          type: BlockType.markdownText,
          rawText: '',
        ),
      ];
    }

    // Divide o conteúdo considerando separadores de bloco explícitos (\n---\n)
    // ou quebras naturais entre blocos especiais (> [!, ```, $$, etc)
    final rawChunks = content.split('\n---\n');
    final List<ParsedContentBlock> resultBlocks = [];

    for (int i = 0; i < rawChunks.length; i++) {
      final chunk = rawChunks[i];
      final trimmed = chunk.trim();

      // Blocos vazios são preservados para suportar linhas e blocos em branco!
      if (trimmed.startsWith('```mermaid')) {
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.mermaidBlock, rawText: trimmed, language: 'mermaid'));
      } else if (trimmed.startsWith('```')) {
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.codeBlock, rawText: trimmed));
      } else if (trimmed.startsWith(r'$$')) {
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.latexBlock, rawText: trimmed));
      } else if (trimmed.startsWith('> [!')) {
        final type = _detectCalloutType(trimmed);
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.calloutBlock, rawText: chunk, calloutType: type));
      } else if (trimmed.startsWith('# ') || trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.heading, rawText: trimmed));
      } else {
        // Se dentro de um texto simples houver um callout isolado ou texto vazio, mantemos como markdownText
        resultBlocks.add(ParsedContentBlock(index: resultBlocks.length, type: BlockType.markdownText, rawText: chunk));
      }
    }

    if (resultBlocks.isEmpty) {
      return [const ParsedContentBlock(index: 0, type: BlockType.markdownText, rawText: '')];
    }

    return resultBlocks;
  }

  static StemCalloutType _detectCalloutType(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('> [!TIP]')) return StemCalloutType.tip;
    if (upper.contains('> [!THEOREM]') || upper.contains('> [!FORMULA]')) return StemCalloutType.theorem;
    if (upper.contains('> [!WARNING]') || upper.contains('> [!CAUTION]') || upper.contains('> [!ALERT]')) return StemCalloutType.warning;
    if (upper.contains('> [!CONCEPT]') || upper.contains('> [!NOTE]') || upper.contains('> [!INFO]')) return StemCalloutType.concept;
    return StemCalloutType.tip;
  }

  void _startEditingBlock(ParsedContentBlock block) {
    if (!widget.isInteractive) {
      return;
    }
    globalIsEditingText = true;
    _lastSelection = const TextSelection.collapsed(offset: -1);
    setState(() {
      _editingBlockIndex = block.index;
      _blockController.loadFromFormattedText(block.rawText);
      _showSlashMenu = false;
    });
    widget.onEditingModeChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockFocusNode.requestFocus();
      }
    });
  }

  /// Permite iniciar a edição do último bloco externamente (ex: ao clicar no fundo do card)
  void editLastBlock() {
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    if (currentBlocks.isNotEmpty) {
      _startEditingBlock(currentBlocks.last);
    }
  }

  /// Trata o duplo clique em area vazia do card criando um novo bloco focado para digitacao
  void _handleDoubleTapOnEmptyArea(Offset localPosition) {
    if (!widget.isInteractive) return;
    if (_editingBlockIndex != null) {
      commitBlockEdit();
    }
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    if (currentBlocks.isEmpty || (currentBlocks.length == 1 && currentBlocks.first.rawText.trim().isEmpty)) {
      _startEditingBlock(const ParsedContentBlock(
        index: 0,
        type: BlockType.markdownText,
        rawText: '',
      ));
      return;
    }

    if (currentBlocks.isNotEmpty && currentBlocks.last.rawText.trim().isEmpty) {
      _startEditingBlock(currentBlocks.last);
      return;
    }

    final newIndex = currentBlocks.length;
    final updatedContent = widget.card.content.isEmpty
        ? ''
        : '${widget.card.content}\n---\n';
    widget.onContentChanged(updatedContent);
    setState(() {
      _lastParsedContent = null;
      _cachedBlockWidgets.clear();
    });
    _startEditingBlock(ParsedContentBlock(
      index: newIndex,
      type: BlockType.markdownText,
      rawText: '',
    ));
  }

  /// Salva as alterações do bloco ativo sem fechar o modo de edição
  void _syncBlockContent() {
    if (_editingBlockIndex == null) return;
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    final updatedBlocks = <String>[];
    final maxLen = math.max(currentBlocks.length, _editingBlockIndex! + 1);

    for (int i = 0; i < maxLen; i++) {
      if (i == _editingBlockIndex) {
        updatedBlocks.add(_blockController.toFormattedText());
      } else if (i < currentBlocks.length) {
        updatedBlocks.add(currentBlocks[i].rawText);
      } else {
        updatedBlocks.add('');
      }
    }
    widget.onContentChanged(updatedBlocks.join('\n---\n'));
  }

  /// Conclui a edição do bloco e fecha a caixa de edição
  void commitBlockEdit() {
    if (_editingBlockIndex == null) return;
    _syncBlockContent();
    setState(() {
      _editingBlockIndex = null;
      _showSlashMenu = false;
      _lastParsedContent = null;
      _cachedBlockWidgets.clear();
    });
    widget.onEditingModeChanged?.call(false);
    globalIsEditingText = false;
  }

  /// Cria um novo bloco abaixo do bloco fornecido (Ctrl + Enter)
  void createNewBlockBelow(int index) {
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    final updatedBlocks = <String>[];

    for (int i = 0; i < currentBlocks.length; i++) {
      final text = (i == _editingBlockIndex) ? _blockController.toFormattedText() : currentBlocks[i].rawText;
      updatedBlocks.add(text);
      if (i == index) {
        updatedBlocks.add('Novo Bloco');
      }
    }

    if (index >= currentBlocks.length) {
      updatedBlocks.add('Novo Bloco');
    }

    final finalStr = updatedBlocks.join('\n---\n');
    widget.onContentChanged(finalStr);

    final targetIndex = index + 1;
    globalIsEditingText = true;
    setState(() {
      _editingBlockIndex = targetIndex;
      _blockController.loadFromFormattedText('Novo Bloco');
      _blockController.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      _showSlashMenu = false;
    });
    widget.onEditingModeChanged?.call(true);
    widget.onActiveStylesChanged?.call(getActiveStyles());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockFocusNode.requestFocus();
      }
    });
  }

  /// Deleta o bloco atual (apenas via botão de lixeira ou atalho explícito quando vazio)
  void deleteBlock(int index) {
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    if (currentBlocks.length <= 1) {
      widget.onContentChanged('');
      setState(() {
        _editingBlockIndex = null;
        _blockController.loadFromFormattedText('');
      });
      return;
    }

    final updatedBlocks = <String>[];
    for (int i = 0; i < currentBlocks.length; i++) {
      if (i != index) {
        final text = (i == _editingBlockIndex) ? _blockController.toFormattedText() : currentBlocks[i].rawText;
        updatedBlocks.add(text);
      }
    }

    final finalStr = updatedBlocks.join('\n---\n');
    widget.onContentChanged(finalStr);

    final targetIndex = math.max(0, index - 1);
    final targetBlocks = _parseContentIntoBlocks(finalStr);
    setState(() {
      _editingBlockIndex = targetIndex;
      final raw = targetIndex < targetBlocks.length ? targetBlocks[targetIndex].rawText : '';
      _blockController.loadFromFormattedText(raw);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockFocusNode.requestFocus();
      }
    });
  }

  /// Divide o bloco no cursor atual e cria novo bloco abaixo (Notion Dynamic Enter)
  void _handleEnterSplitBlock(int blockIndex) {
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    final text = _blockController.text;
    final selection = _blockController.selection;
    final offset = (selection.isValid && selection.baseOffset >= 0)
        ? selection.baseOffset
        : text.length;

    final textBefore = text.substring(0, offset);
    final textAfter = text.substring(offset);

    final updatedBlocks = <String>[];
    for (int i = 0; i < currentBlocks.length; i++) {
      if (i == blockIndex) {
        updatedBlocks.add(textBefore);
        updatedBlocks.add(textAfter);
      } else {
        updatedBlocks.add(currentBlocks[i].rawText);
      }
    }

    if (blockIndex >= currentBlocks.length) {
      updatedBlocks.add('');
    }

    final finalStr = updatedBlocks.join('\n---\n');
    widget.onContentChanged(finalStr);

    final nextIndex = blockIndex + 1;
    globalIsEditingText = true;
    setState(() {
      _editingBlockIndex = nextIndex;
      _showSlashMenu = false;
      _lastParsedContent = null;
    });
    widget.onEditingModeChanged?.call(true);
    widget.onActiveStylesChanged?.call(getActiveStyles());

    _blockController.loadFromFormattedText(textAfter);
    _blockController.selection = const TextSelection.collapsed(offset: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockFocusNode.requestFocus();
      }
    });
  }

  /// Mescla o bloco atual com o bloco anterior ao pressionar Backspace no início (Notion Dynamic Backspace)
  void _handleBackspaceMergeBlock(int blockIndex) {
    if (blockIndex <= 0) return;
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    if (blockIndex >= currentBlocks.length) return;

    final currentText = _blockController.text;
    final prevBlock = currentBlocks[blockIndex - 1];
    final prevText = prevBlock.rawText;
    final mergedText = '$prevText$currentText';
    final newCursorOffset = prevText.length;

    final updatedBlocks = <String>[];
    for (int i = 0; i < currentBlocks.length; i++) {
      if (i == blockIndex - 1) {
        updatedBlocks.add(mergedText);
      } else if (i == blockIndex) {
        // Bloco incorporado ao anterior
        continue;
      } else {
        updatedBlocks.add(currentBlocks[i].rawText);
      }
    }

    final finalStr = updatedBlocks.join('\n---\n');
    widget.onContentChanged(finalStr);

    final targetIndex = blockIndex - 1;
    setState(() {
      _editingBlockIndex = targetIndex;
      _showSlashMenu = false;
      _lastParsedContent = null;
    });

    _blockController.loadFromFormattedText(mergedText);
    _blockController.selection = TextSelection.collapsed(offset: newCursorOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockFocusNode.requestFocus();
      }
    });
  }

  /// Insere um snippet no bloco ativo ou no final do card
  void insertSnippetAtActive(String snippet) {
    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }
      final text = _blockController.text;
      final sel = _blockController.selection;
      
      // Se o snippet for um bloco estrutural (Mermaid, Callout, Bloco LaTeX), criamos blocos separados
      if (snippet.trim().startsWith('```') || snippet.trim().startsWith('> [!') || snippet.trim().startsWith(r'$$') && snippet.trim().contains('\n')) {
        final currentBlocks = _parseContentIntoBlocks(widget.card.content);
        final offset = (sel.isValid && sel.start >= 0) ? sel.start : text.length;
        
        // Pega o texto formatado antes e depois do cursor
        // Como é difícil mapear, vamos exportar tudo, e dividir no cursor?
        // Na verdade, toFormattedText exporta tudo. Precisamos cortar.
        // Uma forma melhor é aplicar uma marca temporária, exportar, e dividir.
        const mark = '\u200B_SPLIT_\u200B';
        final newText = text.replaceRange(offset, (sel.isValid && sel.end >= 0) ? sel.end : offset, mark);
        _blockController.text = newText;
        final formattedWithMark = _blockController.toFormattedText();
        
        final parts = formattedWithMark.split(mark);
        final beforeStr = parts[0].trim();
        final afterStr = parts.length > 1 ? parts[1].trim() : '';
        
        final updatedBlocks = <String>[];
        for (int i = 0; i < currentBlocks.length; i++) {
          if (i == _editingBlockIndex) {
            if (beforeStr.isNotEmpty) updatedBlocks.add(beforeStr);
            updatedBlocks.add(snippet.trim());
            if (afterStr.isNotEmpty) updatedBlocks.add(afterStr);
          } else {
            updatedBlocks.add(currentBlocks[i].rawText);
          }
        }
        
        final finalStr = updatedBlocks.join('\n---\n');
        widget.onContentChanged(finalStr);
        
        final nextIndex = _editingBlockIndex! + (beforeStr.isNotEmpty ? 1 : 0);
        setState(() {
          _editingBlockIndex = nextIndex;
          _showSlashMenu = false;
        });
        _blockController.loadFromFormattedText(snippet.trim());
        _blockController.selection = TextSelection.collapsed(offset: _blockController.text.length);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _blockFocusNode.requestFocus();
        });
        return;
      }

      // Caso contrário, é um snippet inline normal
      String textToInsert = snippet;
      bool isInlineMath = false;
      if (snippet.startsWith(r'$') && snippet.endsWith(r'$') && snippet.length >= 2) {
        textToInsert = snippet.substring(1, snippet.length - 1).trim();
        isInlineMath = true;
      }

      final insertStart = (sel.isValid && sel.start >= 0) ? sel.start : text.length;
      final insertEnd = (sel.isValid && sel.end >= 0) ? sel.end : text.length;
      final newText = text.replaceRange(insertStart, insertEnd, textToInsert);

      _blockController.text = newText;
      _blockController.selection = TextSelection.collapsed(offset: insertStart + textToInsert.length);

      if (isInlineMath) {
        _blockController.styleSpans.add(RichStyleSpan(
          start: insertStart,
          end: insertStart + textToInsert.length,
          isLatex: true,
        ));
      }

      _lastParsedContent = null;
      _cachedBlockWidgets.clear();
      _syncBlockContent();
      _lastSelection = _blockController.selection;
      _blockFocusNode.requestFocus();
    } else {
      final current = widget.card.content;
      final updated = current.isEmpty ? snippet.trim() : '$current\n---\n${snippet.trim()}';
      widget.onContentChanged(updated);
    }
  }

  /// Abre o popover/modal de edição interativa de fórmulas LaTeX com preview KaTeX em tempo real
  void openLatexEditor({
    String? initialFormula,
    bool isBlock = false,
    ValueChanged<String>? onCustomApply,
  }) {
    final effectiveInitial = initialFormula ?? (
      _lastSelection.isValid && !_lastSelection.isCollapsed && _lastSelection.start >= 0 && _lastSelection.end <= _blockController.text.length
        ? _blockController.text.substring(_lastSelection.start, _lastSelection.end)
        : ''
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogCtx) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: CardLatexEditorPopover(
            initialLatex: effectiveInitial,
            defaultBlockMode: isBlock,
            onApply: (formattedMath) {
              if (onCustomApply != null) {
                onCustomApply(formattedMath);
              } else {
                insertSnippetAtActive(formattedMath);
              }
            },
            onClose: () {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
            },
          ),
        ),
      ),
    );
  }

  /// Aplica ou remove (toggle) formatação no texto selecionado ou ativa typingStyle para os próximos caracteres (100% WYSIWYG)
  void wrapSelection({required String prefix, required String suffix}) {
    if (_editingBlockIndex == null) {
      editLastBlock();
    }

    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }

      if (prefix == '**') {
        _blockController.toggleFormatting(toggleBold: true);
      } else if (prefix == '*') {
        _blockController.toggleFormatting(toggleItalic: true);
      } else if (prefix == '<u>') {
        _blockController.toggleFormatting(toggleUnderline: true);
      } else if (prefix == '~~') {
        _blockController.toggleFormatting(toggleStrikethrough: true);
      } else if (prefix == '<sub>') {
        _blockController.toggleFormatting(toggleSubscript: true);
      } else if (prefix == '<sup>') {
        _blockController.toggleFormatting(toggleSuperscript: true);
      } else if (prefix == '`') {
        _blockController.toggleFormatting(toggleCode: true);
      } else if (prefix == r'$') {
        _blockController.toggleFormatting(toggleLatex: true);
      } else if (prefix.startsWith('<mark style="background:') || prefix == '==') {
        final hexMatch = RegExp(r'#([A-Fa-f0-9]+)').firstMatch(prefix);
        final color = hexMatch != null ? _parseHex(hexMatch.group(0)!) : const Color(0xFFFACC15);
        _blockController.toggleFormatting(setHighlightColor: color);
      } else if (prefix.startsWith('<span style="color:') || prefix.startsWith('<font color=')) {
        final hexMatch = RegExp(r'#([A-Fa-f0-9]+)').firstMatch(prefix);
        if (hexMatch != null) {
          final color = _parseHex(hexMatch.group(0)!);
          _blockController.toggleFormatting(setTextColor: color);
        }
      } else if (prefix.startsWith('<span style="font-size:')) {
        final sizeMatch = RegExp(r'font-size:\s*([0-9.]+)px').firstMatch(prefix);
        if (sizeMatch != null) {
          final size = double.tryParse(sizeMatch.group(1)!);
          if (size != null) {
            _blockController.toggleFormatting(setFontSize: size);
          }
        }
      } else {
        // Para snippets (como listas)
        insertSnippetAtActive('$prefix$suffix');
        return; // insertSnippetAtActive já atualiza o sync e o focus
      }

      _lastSelection = _blockController.selection;
      _syncBlockContent();
      widget.onActiveStylesChanged?.call(getActiveStyles());
      _blockFocusNode.requestFocus();
    }
  }

  /// Aplica cor do texto via WYSIWYG Spans
  void applyTextColor(Color color) {
    if (_editingBlockIndex == null) editLastBlock();
    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }
      _blockController.toggleFormatting(setTextColor: color);
      _lastSelection = _blockController.selection;
      _syncBlockContent();
      widget.onActiveStylesChanged?.call(getActiveStyles());
      _blockFocusNode.requestFocus();
    }
  }

  /// Aplica tamanho da fonte via WYSIWYG Spans
  void applyFontSize(double size) {
    if (_editingBlockIndex == null) editLastBlock();
    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }
      _blockController.toggleFormatting(setFontSize: size);
      _lastSelection = _blockController.selection;
      _syncBlockContent();
      widget.onActiveStylesChanged?.call(getActiveStyles());
      _blockFocusNode.requestFocus();
    }
  }

  /// Aplica família de fonte via WYSIWYG Spans
  void applyFontFamily(String family) {
    if (_editingBlockIndex == null) editLastBlock();
    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }
      _blockController.toggleFormatting(setFontFamily: family);
      _lastSelection = _blockController.selection;
      _syncBlockContent();
      widget.onActiveStylesChanged?.call(getActiveStyles());
      _blockFocusNode.requestFocus();
    }
  }

  /// Aplica cor de destaque / marca-texto via WYSIWYG Spans
  void applyHighlightColor(Color? color) {
    if (_editingBlockIndex == null) editLastBlock();
    if (_editingBlockIndex != null) {
      if (_lastSelection.isValid && _lastSelection.start >= 0) {
        _blockController.selection = _lastSelection;
      }
      _blockController.toggleFormatting(setHighlightColor: color);
      _lastSelection = _blockController.selection;
      _syncBlockContent();
      widget.onActiveStylesChanged?.call(getActiveStyles());
      _blockFocusNode.requestFocus();
    }
  }

  Color _parseHex(String hex) {
    try {
      String clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return const Color(0xFF00E1FF);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MoscaroTokens.isLight;
    final textPrimary = widget.card.textColor ?? MoscaroTokens.textPrimary;
    final themeAccent = MoscaroTokens.auroraBlue;
    final fontFamily = widget.card.fontFamily;
    final fontSize = widget.card.fontSize;

    if (!_isCacheValid(isLight, textPrimary, themeAccent, fontFamily, fontSize)) {
      _updateCache(isLight, textPrimary, themeAccent, fontFamily, fontSize);
    }

    final blocks = _cachedParsedBlocks!;
    final availableBodyHeight = math.max(60.0, widget.card.height - 46.0);

    if (widget.card.content.trim().isEmpty && !widget.card.content.contains('\n---\n') && _editingBlockIndex == null) {
      return _buildPlaceholderSuggestionView(
        availableBodyHeight: availableBodyHeight,
        isLight: isLight,
        themeAccent: themeAccent,
        textPrimary: textPrimary,
        fontFamily: fontFamily,
        fontSize: fontSize,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectCard?.call(),
      onDoubleTapDown: (details) {
        _lastEmptyAreaDoubleTapPos = details.localPosition;
      },
      onDoubleTap: () {
        widget.onSelectCard?.call();
        _handleDoubleTapOnEmptyArea(_lastEmptyAreaDoubleTapPos ?? Offset.zero);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(minHeight: availableBodyHeight),
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...blocks.map((block) {
                    final isEditing = _editingBlockIndex == block.index;
                    if (isEditing) {
                      return _buildEditingField(
                        block,
                        isLight,
                        themeAccent,
                        textPrimary,
                        fontFamily,
                        fontSize,
                      );
                    }
                    return _buildRenderedBlock(
                      block,
                      isLight,
                      themeAccent,
                      textPrimary,
                      fontFamily,
                      fontSize,
                    );
                  }),
                  if (_editingBlockIndex != null && _editingBlockIndex! >= blocks.length)
                    _buildEditingField(
                      ParsedContentBlock(
                        index: _editingBlockIndex!,
                        type: BlockType.markdownText,
                        rawText: _blockController.text,
                      ),
                      isLight,
                      themeAccent,
                      textPrimary,
                      fontFamily,
                      fontSize,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderSuggestionView({
    required double availableBodyHeight,
    required bool isLight,
    required Color themeAccent,
    required Color textPrimary,
    required String fontFamily,
    required double fontSize,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectCard?.call(),
      onDoubleTap: () {
        widget.onSelectCard?.call();
        _startEditingBlock(const ParsedContentBlock(
          index: 0,
          type: BlockType.markdownText,
          rawText: '',
        ));
      },
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: availableBodyHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Card STEM',
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.35),
                fontFamily: fontFamily,
                fontSize: fontSize + 2.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Clique duas vezes para digitar texto, fórmulas LaTeX (\$E=mc^2\$), diagramas Mermaid ou "/" para comandos...',
              style: TextStyle(
                color: textPrimary.withValues(alpha: 0.28),
                fontFamily: fontFamily,
                fontSize: fontSize,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingField(
    ParsedContentBlock block,
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    String fontFamily,
    double fontSize,
  ) {
    double effectiveFontSize = fontSize;
    for (final s in _blockController.styleSpans) {
      if (s.fontSize != null && s.fontSize! > effectiveFontSize) {
        effectiveFontSize = s.fontSize!;
      }
    }
    if (_blockController.hasActiveTypingStyle && _blockController.typingStyle.fontSize != null) {
      if (_blockController.typingStyle.fontSize! > effectiveFontSize) {
        effectiveFontSize = _blockController.typingStyle.fontSize!;
      }
    }

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          // 1. Enter: divide bloco ou cria novo bloco abaixo (Notion style)
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            final isShift = HardwareKeyboard.instance.isShiftPressed;
            final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
            if (isShift) {
              // Shift+Enter: quebra de linha suave dentro do mesmo bloco
              return KeyEventResult.ignored;
            } else if (!isCtrl) {
              _handleEnterSplitBlock(block.index);
              return KeyEventResult.handled;
            }
          }

          // 2. Backspace suave estilo Notion:
          // Se o bloco tiver conteúdo, o backspace apaga caracteres e termos normalmente,
          // permitindo editar parâmetros e fórmulas sem apagar a equação inteira acidentalmente.
          // Se o usuário apagar todo o conteúdo, o bloco fica em branco.
          // O bloco só é excluído e mesclado se o usuário pressionar Backspace mais uma vez enquanto o bloco já estiver vazio!
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_blockController.text.isNotEmpty) {
              return KeyEventResult.ignored;
            } else {
              // Bloco está completamente vazio
              if (block.index > 0) {
                // KeyRepeatEvent (segurar Backspace continuamente) NUNCA deve mesclar ou excluir blocos
                if (event is KeyRepeatEvent) {
                  return KeyEventResult.handled;
                }

                // Se o bloco acabou de ficar vazio (ex: usuário estava apagando caracteres),
                // exigimos uma pausa mínima para que a tecla seja solta e pressionada novamente com intenção consciente.
                final becameEmptyRecently = _timeBecameEmpty != null &&
                    DateTime.now().difference(_timeBecameEmpty!).inMilliseconds < 350;

                if (becameEmptyRecently) {
                  // Primeiro instante em que o bloco esvaziou: consome o evento e deixa o bloco em branco!
                  return KeyEventResult.handled;
                }

                // O bloco já estava vazio e o usuário pressionou Backspace mais uma vez de forma intencional:
                _handleBackspaceMergeBlock(block.index);
                return KeyEventResult.handled;
              }
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
            _blockController.undo();
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
            _blockController.undo();
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
            _blockController.redo();
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () {
            _blockController.redo();
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () {
            _blockController.redo();
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
            _blockController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _blockController.text.length,
            );
          },
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () {
            _blockController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _blockController.text.length,
            );
          },
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
            createNewBlockBelow(block.index);
          },
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
            _blockController.toggleFormatting(toggleBold: true);
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
            _blockController.toggleFormatting(toggleItalic: true);
            _syncBlockContent();
          },
          const SingleActivator(LogicalKeyboardKey.keyU, control: true): () {
            _blockController.toggleFormatting(toggleUnderline: true);
            _syncBlockContent();
          },
        },
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Posiciona o cursor no final do texto e foca
              _blockController.selection = TextSelection.collapsed(offset: _blockController.text.length);
              _blockFocusNode.requestFocus();
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: math.max(6.0, effectiveFontSize * 0.22),
              ),
              decoration: BoxDecoration(
                color: themeAccent.withValues(alpha: isLight ? 0.06 : 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeAccent.withValues(alpha: 0.5), width: 1.0),
              ),
              child: TextField(
                controller: _blockController,
                focusNode: _blockFocusNode,
                maxLines: null,
                minLines: 1,
                style: TextStyle(
                  color: textPrimary,
                  fontFamily: fontFamily,
                  fontSize: effectiveFontSize,
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(left: 6, top: 2, bottom: 2, right: 88),
                ),
                onChanged: (val) => _syncBlockContent(),
              ),
            ),
          ),

          // Botões de Ação do Bloco no Canto Superior Direito (100% visíveis dentro do bloco)
          Positioned(
            top: 4,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF8FAFC).withValues(alpha: 0.95) : MoscaroTokens.glassTint,
                borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
                border: Border.all(
                  color: isLight ? MoscaroTokens.borderSubtle : themeAccent.withValues(alpha: 0.45),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => createNewBlockBelow(block.index),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: 'Novo Bloco (Ctrl+Enter)',
                        child: SvgIcon(name: 'plus', size: 12, color: themeAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => deleteBlock(block.index),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Tooltip(
                        message: 'Excluir Bloco',
                        child: SvgIcon(name: 'trash', size: 12, color: Color(0xFFFF007A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: commitBlockEdit,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: 'Concluir Edição',
                        child: SvgIcon(name: 'check', size: 12, color: themeAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 1. Popover de Slash Commands (/)
          if (_showSlashMenu)
            Positioned(
              left: 0,
              top: 36,
              child: CardSlashCommandPopover(
                query: _slashQuery,
                isLight: isLight,
                themeAccent: themeAccent,
                textPrimary: textPrimary,
                blur: MoscaroTokens.blurSigma,
                onClose: () => setState(() => _showSlashMenu = false),
                onSelectCommand: (cmd) {
                  if (cmd.key.contains('latex')) {
                    final text = _blockController.text;
                    final lastSlash = text.lastIndexOf('/');
                    if (lastSlash >= 0) {
                      _blockController.text = text.substring(0, lastSlash).trimRight();
                    }
                    setState(() => _showSlashMenu = false);
                    openLatexEditor(
                      isBlock: true,
                      onCustomApply: (mathSnippet) {
                        insertSnippetAtActive(mathSnippet);
                      },
                    );
                    return;
                  }

                  final text = _blockController.text;
                  final lastSlash = text.lastIndexOf('/');
                  final beforeSlash = lastSlash >= 0 ? text.substring(0, lastSlash).trimRight() : '';

                  final currentBlocks = _parseContentIntoBlocks(widget.card.content);
                  final updatedBlocks = <String>[];

                  // Se o bloco atual só continha o slash (ou estava vazio), ele é substituído pelo comando
                  if (beforeSlash.isEmpty) {
                    for (int i = 0; i < currentBlocks.length; i++) {
                      if (i == _editingBlockIndex) {
                        updatedBlocks.add(cmd.snippet);
                      } else {
                        updatedBlocks.add(currentBlocks[i].rawText);
                      }
                    }
                    final finalStr = updatedBlocks.join('\n---\n');
                    widget.onContentChanged(finalStr);
                    setState(() {
                      _blockController.loadFromFormattedText(cmd.snippet);
                      _blockController.selection = TextSelection.collapsed(offset: cmd.snippet.length);
                      _showSlashMenu = false;
                    });
                  } else {
                    // Se já havia conteúdo antes do slash, preserva o bloco anterior e CRIA UM NOVO BLOCO ABAIXO
                    for (int i = 0; i < currentBlocks.length; i++) {
                      if (i == _editingBlockIndex) {
                        updatedBlocks.add(beforeSlash);
                        updatedBlocks.add(cmd.snippet);
                      } else {
                        updatedBlocks.add(currentBlocks[i].rawText);
                      }
                    }
                    final finalStr = updatedBlocks.join('\n---\n');
                    widget.onContentChanged(finalStr);
                    final newIdx = (block.index) + 1;
                    setState(() {
                      _editingBlockIndex = newIdx;
                      _blockController.loadFromFormattedText(cmd.snippet);
                      _blockController.selection = TextSelection.collapsed(offset: cmd.snippet.length);
                      _showSlashMenu = false;
                    });
                  }
                  _blockFocusNode.requestFocus();
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildRenderedBlock(
    ParsedContentBlock block,
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    String fontFamily,
    double fontSize,
  ) {
    final isHovered = _hoveredBlockIndex == block.index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredBlockIndex = block.index),
      onExit: (_) => setState(() => _hoveredBlockIndex = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelectCard?.call(),
        onDoubleTap: () {
          widget.onSelectCard?.call();
          _startEditingBlock(block);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              constraints: const BoxConstraints(minHeight: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovered ? themeAccent.withValues(alpha: 0.3) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: _cachedBlockWidgets[block.index] ?? _buildBlockContent(block, isLight, themeAccent, textPrimary, fontFamily, fontSize),
            ),

            // Controles de Ação de Bloco no Hover no Padrão Moscaro Glass v2 no Canto Superior Direito
            if (isHovered && widget.isInteractive)
              Positioned(
                top: 4,
                right: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
                  child: (MoscaroTokens.enableCardsBlur && MoscaroTokens.blurSigma > 0)
                      ? BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: MoscaroTokens.blurSigma,
                            sigmaY: MoscaroTokens.blurSigma,
                          ),
                          child: _buildHoverActionsContainer(isLight, themeAccent, textPrimary, block),
                        )
                      : _buildHoverActionsContainer(isLight, themeAccent, textPrimary, block),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoverActionsContainer(bool isLight, Color themeAccent, Color textPrimary, ParsedContentBlock block) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF8FAFC).withValues(alpha: 0.95)
            : MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
        border: Border.all(
          color: isLight
              ? MoscaroTokens.borderSubtle
              : themeAccent.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _startEditingBlock(block),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Tooltip(
                message: 'Editar Bloco',
                child: SvgIcon(
                  name: 'pen',
                  size: 12,
                  color: textPrimary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => createNewBlockBelow(block.index),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Tooltip(
                message: 'Novo Bloco Abaixo',
                child: SvgIcon(
                  name: 'plus',
                  size: 12,
                  color: themeAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => deleteBlock(block.index),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Tooltip(
                message: 'Excluir Bloco',
                child: SvgIcon(
                  name: 'trash',
                  size: 12,
                  color: Color(0xFFFF007A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockContent(
    ParsedContentBlock block,
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    String fontFamily,
    double fontSize,
  ) {
    switch (block.type) {
      case BlockType.latexBlock:
        return _buildLatexBlockView(block, isLight, themeAccent, textPrimary, fontSize);
      case BlockType.codeBlock:
        return _buildCodeBlockView(block, isLight, themeAccent, textPrimary, fontSize);
      case BlockType.mermaidBlock:
        return MermaidDiagramPainterView(
          mermaidCode: block.rawText,
          isLight: isLight,
          themeAccent: themeAccent,
          textPrimary: textPrimary,
          fontSize: fontSize,
        );
      case BlockType.calloutBlock:
        return _buildCalloutBlockView(block, isLight, themeAccent, textPrimary, fontFamily, fontSize);
      case BlockType.heading:
      case BlockType.markdownText:
        return _buildMarkdownTextView(block.rawText, isLight, themeAccent, textPrimary, fontFamily, fontSize);
    }
  }

  Widget _buildCalloutBlockView(
    ParsedContentBlock block,
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    String fontFamily,
    double fontSize,
  ) {
    final lines = block.rawText.split('\n');
    String customTitle = '';
    final contentLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('> [!')) {
        // Verifica se há título customizado após o colchete, ex: > [!TIP] Meu Titulo
        final closeBracket = trimmed.indexOf(']');
        if (closeBracket != -1 && closeBracket < trimmed.length - 1) {
          customTitle = trimmed.substring(closeBracket + 1).trim();
        }
        continue;
      }
      if (trimmed.startsWith('>')) {
        contentLines.add(trimmed.substring(1).trimLeft());
      } else if (trimmed.isNotEmpty) {
        contentLines.add(trimmed);
      }
    }

    // Se estiver vazio, exibe ao menos um placeholder informativo
    if (contentLines.isEmpty) {
      contentLines.add('Clique duas vezes para editar o conteúdo do callout...');
    }

    return StemCalloutBoxView(
      type: block.calloutType ?? StemCalloutType.tip,
      title: customTitle,
      isLight: isLight,
      fontSize: fontSize,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentLines.map((l) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                children: _parseRichInlineSpan(
                  l,
                  textPrimary: isLight ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  fontFamily: fontFamily,
                  fontSize: fontSize * 0.95,
                  themeAccent: themeAccent,
                  isLight: isLight,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLatexBlockView(ParsedContentBlock block, bool isLight, Color themeAccent, Color textPrimary, double fontSize) {
    String mathStr = block.rawText.trim();
    if (mathStr.startsWith(r'$$')) mathStr = mathStr.substring(2);
    if (mathStr.endsWith(r'$$')) mathStr = mathStr.substring(0, mathStr.length - 2);
    mathStr = mathStr.trim();

    double effectiveFontSize = fontSize * 1.15;
    Color effectiveTextColor = textPrimary;
    final sizeMatch = RegExp(r'<span style="font-size:\s*([0-9.]+)px">').firstMatch(mathStr);
    if (sizeMatch != null) {
      effectiveFontSize = double.tryParse(sizeMatch.group(1)!) ?? effectiveFontSize;
    }
    final colorMatch = RegExp(r'<span style="color:\s*([^"]+)">|<font color="([^"]+)">').firstMatch(mathStr);
    if (colorMatch != null) {
      final hex = colorMatch.group(1) ?? colorMatch.group(2) ?? '';
      effectiveTextColor = _parseHexColor(hex, textPrimary);
    }

    // Normaliza ambientes como gathered para aligned e remove quaisquer tags HTML acidentais
    final cleanMathStr = mathStr
        .replaceAll(RegExp(r'</?(span|font|mark|b|i|u|sub|sup)[^>]*>', caseSensitive: false), '')
        .replaceAll(r'\begin{gathered}', r'\begin{aligned}')
        .replaceAll(r'\end{gathered}', r'\end{aligned}')
        .trim();

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: themeAccent.withValues(alpha: 0.3), width: 0.8),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => widget.onSelectCard?.call(),
          onDoubleTap: () {
            widget.onSelectCard?.call();
            _startEditingBlock(block);
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Math.tex(
              cleanMathStr,
              textStyle: TextStyle(
                color: effectiveTextColor,
                fontSize: effectiveFontSize,
              ),
              onErrorFallback: (err) => Text(
                cleanMathStr,
                style: TextStyle(color: const Color(0xFFFF007A), fontSize: effectiveFontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlockView(ParsedContentBlock block, bool isLight, Color themeAccent, Color textPrimary, double fontSize) {
    String code = block.rawText.trim();
    if (code.startsWith('```')) {
      final firstLineEnd = code.indexOf('\n');
      if (firstLineEnd != -1) {
        code = code.substring(firstLineEnd + 1);
      }
    }
    if (code.endsWith('```')) {
      code = code.substring(0, code.length - 3).trimRight();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFF0F172A).withValues(alpha: 0.06) : const Color(0xFF070B14).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeAccent.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (block.language != null && block.language!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                block.language!.toUpperCase(),
                style: TextStyle(
                  color: themeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          SelectableText(
            code,
            style: TextStyle(
              fontFamily: 'Fira Code',
              color: textPrimary,
              fontSize: fontSize * 0.92,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Parser e Renderizador Rico de Markdown + HTML + KaTeX Inline + Checklists com Progresso
  // =========================================================================

  Widget _buildMarkdownTextView(
    String raw,
    bool isLight,
    Color themeAccent,
    Color textPrimary,
    String fontFamily,
    double fontSize,
  ) {
    final lines = raw.split('\n');

    // Identificação de Checklists e cálculo de progresso
    int totalChecklistItems = 0;
    int checkedCount = 0;
    for (final l in lines) {
      final t = l.trim();
      if (t.startsWith('- [ ] ') || t.startsWith('- [x] ') || t.startsWith('- [X] ')) {
        totalChecklistItems++;
        if (t.startsWith('- [x] ') || t.startsWith('- [X] ')) {
          checkedCount++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de Progresso Dinâmica em Checklists
        if (totalChecklistItems > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 6, top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MoscaroTokens.cardProgressColor.withValues(alpha: isLight ? 0.08 : 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MoscaroTokens.cardProgressColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalChecklistItems > 0 ? (checkedCount / totalChecklistItems) : 0.0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(MoscaroTokens.cardProgressColor),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$checkedCount/$totalChecklistItems • ${(totalChecklistItems > 0 ? (checkedCount / totalChecklistItems * 100).round() : 0)}%',
                  style: TextStyle(
                    color: MoscaroTokens.cardProgressColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        ...lines.map((line) {
          final trimmed = line.trim();

          // Linhas em branco ocupam altura normal para preservar espaçamento e blocos vazios
          if (trimmed.isEmpty) {
            return SizedBox(height: fontSize * 1.3);
          }

          // 1. Checklists (- [ ] / - [x])
          if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
            final isChecked = trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ');
            final label = trimmed.substring(6);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      final updatedLine = isChecked ? '- [ ] $label' : '- [x] $label';
                      final updatedContent = raw.replaceFirst(line, updatedLine);
                      widget.onContentChanged(updatedContent);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: fontSize * 1.15,
                      color: isChecked ? MoscaroTokens.cardProgressColor : textPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _parseRichInlineSpan(
                          label,
                          textPrimary: isChecked ? textPrimary.withValues(alpha: 0.6) : textPrimary,
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                          themeAccent: themeAccent,
                          isLight: isLight,
                          strikethrough: isChecked,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 2. Listas com marcadores (- ou *)
          if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            final label = trimmed.substring(2);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: themeAccent,
                      fontSize: fontSize * 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _parseRichInlineSpan(
                          label,
                          textPrimary: textPrimary,
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                          themeAccent: themeAccent,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 3. Listas numeradas (1. 2. etc)
          final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
          if (numMatch != null) {
            final numStr = numMatch.group(1)!;
            final label = numMatch.group(2)!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$numStr. ',
                    style: TextStyle(
                      color: themeAccent,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _parseRichInlineSpan(
                          label,
                          textPrimary: textPrimary,
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                          themeAccent: themeAccent,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 4. Cabeçalhos (#, ##, ###)
          if (trimmed.startsWith('# ') || trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
            int level = 1;
            String text = trimmed;
            if (trimmed.startsWith('### ')) {
              level = 3;
              text = trimmed.substring(4);
            } else if (trimmed.startsWith('## ')) {
              level = 2;
              text = trimmed.substring(3);
            } else if (trimmed.startsWith('# ')) {
              level = 1;
              text = trimmed.substring(2);
            }
            final double hSize = level == 1 ? fontSize * 1.5 : (level == 2 ? fontSize * 1.3 : fontSize * 1.15);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: _parseRichInlineSpan(
                    text,
                    textPrimary: textPrimary,
                    fontFamily: fontFamily,
                    fontSize: hSize,
                    themeAccent: themeAccent,
                    isLight: isLight,
                    isBold: true,
                  ),
                ),
              ),
            );
          }

          // 5. Linhas de Citação ou Callout em bloco de texto
          if (trimmed.startsWith('> [!')) {
            final type = _detectCalloutType(trimmed);
            final closeBracket = trimmed.indexOf(']');
            final customTitle = (closeBracket != -1 && closeBracket < trimmed.length - 1)
                ? trimmed.substring(closeBracket + 1).trim()
                : '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: StemCalloutBoxView(
                type: type,
                title: customTitle,
                isLight: isLight,
                fontSize: fontSize,
                content: const SizedBox.shrink(),
              ),
            );
          } else if (trimmed.startsWith('>')) {
            final quoteText = trimmed.substring(1).trim();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: themeAccent.withValues(alpha: isLight ? 0.05 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: themeAccent, width: 3.0),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: _parseRichInlineSpan(
                      quoteText,
                      textPrimary: isLight ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      fontFamily: fontFamily,
                      fontSize: fontSize,
                      themeAccent: themeAccent,
                      isLight: isLight,
                      isItalic: true,
                    ),
                  ),
                ),
              ),
            );
          }

          // 6. Bloco de Equação LaTeX ($$ ... $$ ou linhas iniciando com comandos matemáticos como \int, \frac, \sum, \sqrt, \begin, \vec, \matrix, \lim)
          if ((trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$') && trimmed.length > 2) ||
              (trimmed.startsWith(r'$') && trimmed.endsWith(r'$') && trimmed.length > 2)) {
            String mathSnippet = trimmed;
            if (mathSnippet.startsWith(r'$$') && mathSnippet.endsWith(r'$$')) {
              mathSnippet = mathSnippet.substring(2, mathSnippet.length - 2).trim();
            } else if (mathSnippet.startsWith(r'$') && mathSnippet.endsWith(r'$')) {
              mathSnippet = mathSnippet.substring(1, mathSnippet.length - 1).trim();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Math.tex(
                  mathSnippet,
                  textStyle: TextStyle(
                    color: textPrimary,
                    fontSize: fontSize * 1.15,
                  ),
                  onErrorFallback: (_) => Text(line, style: TextStyle(color: textPrimary, fontSize: fontSize)),
                ),
              ),
            );
          } else if (_isMathCommandLine(trimmed)) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Math.tex(
                  trimmed,
                  textStyle: TextStyle(
                    color: textPrimary,
                    fontSize: fontSize * 1.15,
                  ),
                  onErrorFallback: (_) => Text(line, style: TextStyle(color: textPrimary, fontSize: fontSize)),
                ),
              ),
            );
          }

          // 6. Parágrafo Comum com Parse Rico de Inline (HTML, KaTeX, Cores, etc)
          return Text.rich(
            TextSpan(
              children: _parseRichInlineSpan(
                line,
                textPrimary: textPrimary,
                fontFamily: fontFamily,
                fontSize: fontSize,
                themeAccent: themeAccent,
                isLight: isLight,
              ),
            ),
          );
        }),
      ],
    );
  }

  static bool _isMathCommandLine(String trimmed) {
    if (trimmed.isEmpty || trimmed.startsWith(r'\\')) return false;
    const prefixes = [
      r'\int', r'\iint', r'\iiint', r'\oint',
      r'\frac', r'\cfrac', r'\dfrac',
      r'\sum', r'\prod', r'\coprod',
      r'\sqrt', r'\root',
      r'\lim', r'\sup', r'\inf', r'\max', r'\min',
      r'\begin', r'\matrix', r'\pmatrix', r'\bmatrix', r'\vmatrix', r'\Bmatrix',
      r'\vec', r'\hat', r'\bar', r'\dot', r'\ddot',
      r'\tan', r'\sin', r'\cos', r'\sec', r'\csc', r'\cot',
      r'\arcsin', r'\arccos', r'\arctan',
      r'\log', r'\ln', r'\exp',
      r'\quad', r'\qquad', r'\left', r'\right',
      r'\alpha', r'\beta', r'\gamma', r'\theta', r'\lambda', r'\pi',
      r'\sigma', r'\omega', r'\Delta', r'\partial', r'\nabla',
    ];
    return prefixes.any((p) => trimmed.startsWith(p));
  }

  static String _normalizeInlineMath(String line) {
    if (line.isEmpty || line.contains(r'$') || !line.contains(r'\')) {
      return line;
    }
    // Verifica se contém comandos LaTeX
    if (!RegExp(r'\\[a-zA-Z]+').hasMatch(line)) {
      return line;
    }

    // Se a linha inteira for puramente uma fórmula (sem palavras naturais fora de \text{...}):
    final textWithoutLatex = line.replaceAll(RegExp(r'\\[a-zA-Z]+'), '').replaceAll(RegExp(r'\{[^\}]*\}'), '');
    final hasNaturalWords = RegExp(r'\b[a-zA-ZÀ-ÿ]{3,}\b').hasMatch(textWithoutLatex);
    if (!hasNaturalWords) {
      return '\$$line\$';
    }

    // Delimita expressões matemáticas soltas separadas por palavras conectivas comuns em STEM
    final delimiters = RegExp(
      r'(\b(?:Sabendo\s+que|sabendo\s+que|Dado\s+que|dado\s+que|Calcule|calcule|Determine|determine|Obtenha|obtenha|onde|Onde|para|Para|com|Com|se|Se|então|entao|Então|Entao|logo|Logo|portanto|Portanto|quando|Quando|sendo|Sendo)\b|\s+\be\b\s+|\s+\bou\b\s+)',
    );

    final parts = line.split(delimiters);
    final matches = delimiters.allMatches(line).toList();
    final reconstructed = <String>[];

    for (int i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.isNotEmpty) {
        if (p.contains(r'\') && RegExp(r'\\[a-zA-Z]+').hasMatch(p)) {
          final leading = p.startsWith(' ') ? ' ' : '';
          final trailingSpace = p.endsWith(' ') ? ' ' : '';
          var trimmed = p.trim();
          var trailingPunct = '';
          while (trimmed.isNotEmpty && (trimmed.endsWith('.') || trimmed.endsWith(',') || trimmed.endsWith(';') || trimmed.endsWith(':'))) {
            trailingPunct = trimmed[trimmed.length - 1] + trailingPunct;
            trimmed = trimmed.substring(0, trimmed.length - 1).trim();
          }
          if (trimmed.isNotEmpty) {
            reconstructed.add('$leading\$$trimmed\$$trailingPunct$trailingSpace');
          } else {
            reconstructed.add(p);
          }
        } else {
          reconstructed.add(p);
        }
      }
      if (i < matches.length) {
        reconstructed.add(matches[i].group(0)!);
      }
    }

    return reconstructed.join('');
  }

  /// Tokenizador que converte tags HTML, Markdown e KaTeX inline em InlineSpans autênticos
  List<InlineSpan> _parseRichInlineSpan(
    String text, {
    required Color textPrimary,
    required String fontFamily,
    required double fontSize,
    required Color themeAccent,
    required bool isLight,
    bool isBold = false,
    bool isItalic = false,
    bool strikethrough = false,
  }) {
    if (text.isEmpty) return [];

    final normalizedText = _normalizeInlineMath(text);
    final spans = <InlineSpan>[];

    // Regex de padrões inline: KaTeX ($$...$$ / $...$), HTML Span (<span style="...">), Underline (<u>...</u>), Highlight (==...== / <mark>...), Bold (**...**), Italic (*...*), Sub/Sup, Code (`...`)
    final pattern = RegExp(
      r'(<span style="font-size:\s*([0-9.]+)px">([\s\S]*?)<\/span>)|' // 1,2,3: Font Size Span
      r'(<span style="color:\s*([^"]+)">([\s\S]*?)<\/span>)|' // 4,5,6: Color Span
      r'(<font color="([^"]+)">([\s\S]*?)<\/font>)|' // 7,8,9: Font Color
      r'(<u>([\s\S]*?)<\/u>)|' // 10,11: Underline
      r'(<mark style="background:\s*([^"]+)">([\s\S]*?)<\/mark>)|' // 12,13,14: Styled Mark
      r'(<mark>([\s\S]*?)<\/mark>)|' // 15,16: Plain Mark
      r'(==([\s\S]*?)==)|' // 17,18: ==Highlight==
      r'(<sub>([\s\S]*?)<\/sub>)|' // 19,20: Subscript
      r'(<sup>([\s\S]*?)<\/sup>)|' // 21,22: Superscript
      r'(\*\*([\s\S]*?)\*\*)|' // 23,24: **Bold**
      r'(\*([^\*\n]+)\*)|' // 25,26: *Italic*
      r'(`([^`\n]+)`)|' // 27,28: `Code`
      r'(\$\$[\s\S]*?\$\$)|' // 29: Display Math $$...$$
      r'(\$[^$\n]+\$)|' // 30: Inline Math $...$
      r'(~~([\s\S]*?)~~)', // 31,32: Strikethrough
    );

    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(normalizedText)) {
      if (match.start > lastMatchEnd) {
        final plain = text.substring(lastMatchEnd, match.start);
        spans.add(TextSpan(
          text: plain,
          style: TextStyle(
            color: textPrimary,
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
            height: 1.45,
          ),
        ));
      }

      final fullMatch = match.group(0)!;

      // 1. Font Size Span (<span style="font-size: 20px">...</span>)
      if (match.group(1) != null) {
        final sizeStr = match.group(2) ?? '';
        final innerText = match.group(3) ?? '';
        final customFontSize = double.tryParse(sizeStr) ?? fontSize;
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: textPrimary,
          fontFamily: fontFamily,
          fontSize: customFontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ));
      }
      // 2 & 3. Color Span (<span style="color: #HEX">...</span> ou <font color="#HEX">...</span>)
      else if (match.group(4) != null || match.group(7) != null) {
        final hexStr = match.group(5) ?? match.group(8) ?? '';
        final innerText = match.group(6) ?? match.group(9) ?? '';
        final color = _parseHexColor(hexStr, textPrimary);
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: color,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ));
      }
      // 4. Underline (<u>...</u>)
      else if (match.group(10) != null) {
        final innerText = match.group(11)!;
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: textPrimary,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ).map((s) {
          if (s is TextSpan) {
            return TextSpan(
              text: s.text,
              children: s.children,
              style: (s.style ?? TextStyle(color: textPrimary, fontSize: fontSize)).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: themeAccent,
                decorationThickness: 1.5,
              ),
            );
          }
          return s;
        }));
      }
      // 5. Styled Mark (<mark style="background: #HEX">...</mark>)
      else if (match.group(12) != null) {
        final bgHex = match.group(13) ?? '#FACC15';
        final innerText = match.group(14) ?? '';
        final bgColor = _parseHexColor(bgHex, const Color(0xFFFACC15)).withValues(alpha: 0.38);
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: isLight ? Colors.black : Colors.white,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ).map((s) {
          if (s is TextSpan) {
            return TextSpan(
              text: s.text,
              children: s.children,
              style: (s.style ?? TextStyle(fontSize: fontSize)).copyWith(
                backgroundColor: bgColor,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            );
          }
          return s;
        }));
      }
      // 6 & 7. Highlight (==...== ou plain <mark>...</mark>)
      else if (match.group(15) != null || match.group(17) != null) {
        final innerText = match.group(16) ?? match.group(18) ?? '';
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: isLight ? Colors.black : Colors.white,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ).map((s) {
          if (s is TextSpan) {
            return TextSpan(
              text: s.text,
              children: s.children,
              style: (s.style ?? TextStyle(fontSize: fontSize)).copyWith(
                backgroundColor: const Color(0xFFFACC15).withValues(alpha: 0.38),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            );
          }
          return s;
        }));
      }
      // 8. Subscript (<sub>...</sub>)
      else if (match.group(19) != null) {
        final innerText = match.group(20)!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.translate(
            offset: const Offset(0, 3),
            child: Text.rich(
              TextSpan(
                children: _parseRichInlineSpan(
                  innerText,
                  textPrimary: textPrimary,
                  fontFamily: fontFamily,
                  fontSize: fontSize * 0.8,
                  themeAccent: themeAccent,
                  isLight: isLight,
                  isBold: isBold,
                  isItalic: isItalic,
                  strikethrough: strikethrough,
                ),
              ),
            ),
          ),
        ));
      }
      // 9. Superscript (<sup>...</sup>)
      else if (match.group(21) != null) {
        final innerText = match.group(22)!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Text.rich(
              TextSpan(
                children: _parseRichInlineSpan(
                  innerText,
                  textPrimary: textPrimary,
                  fontFamily: fontFamily,
                  fontSize: fontSize * 0.8,
                  themeAccent: themeAccent,
                  isLight: isLight,
                  isBold: isBold,
                  isItalic: isItalic,
                  strikethrough: strikethrough,
                ),
              ),
            ),
          ),
        ));
      }
      // 10. Bold (**...**)
      else if (match.group(23) != null) {
        final innerText = match.group(24)!;
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: textPrimary,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: true,
          isItalic: isItalic,
          strikethrough: strikethrough,
        ));
      }
      // 11. Italic (*...*)
      else if (match.group(25) != null) {
        final innerText = match.group(26)!;
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: textPrimary,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: true,
          strikethrough: strikethrough,
        ));
      }
      // 12. Inline Code (`...`)
      else if (match.group(27) != null) {
        final innerText = match.group(28)!;
        spans.add(TextSpan(
          text: innerText,
          style: TextStyle(
            color: themeAccent,
            fontFamily: 'Fira Code',
            fontSize: fontSize * 0.9,
            backgroundColor: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08),
          ),
        ));
      }
      // 13. KaTeX ($$...$$ ou $...$)
      else if (match.group(29) != null || match.group(30) != null) {
        String mathSnippet = fullMatch;
        if (mathSnippet.startsWith(r'$$') && mathSnippet.endsWith(r'$$') && mathSnippet.length >= 4) {
          mathSnippet = mathSnippet.substring(2, mathSnippet.length - 2).trim();
        } else if (mathSnippet.startsWith(r'$') && mathSnippet.endsWith(r'$') && mathSnippet.length >= 2) {
          mathSnippet = mathSnippet.substring(1, mathSnippet.length - 1).trim();
        }

        double mathFontSize = fontSize * 1.05;
        Color mathTextColor = textPrimary;
        final sizeMatch = RegExp(r'<span style="font-size:\s*([0-9.]+)px">').firstMatch(mathSnippet);
        if (sizeMatch != null) {
          mathFontSize = double.tryParse(sizeMatch.group(1)!) ?? mathFontSize;
        }
        final colorMatch = RegExp(r'<span style="color:\s*([^"]+)">|<font color="([^"]+)">').firstMatch(mathSnippet);
        if (colorMatch != null) {
          final hex = colorMatch.group(1) ?? colorMatch.group(2) ?? '';
          mathTextColor = _parseHexColor(hex, textPrimary);
        }

        final cleanMath = mathSnippet
            .replaceAll(RegExp(r'</?(span|font|mark|b|i|u|sub|sup)[^>]*>', caseSensitive: false), '')
            .replaceAll(r'\begin{gathered}', r'\begin{aligned}')
            .replaceAll(r'\end{gathered}', r'\end{aligned}')
            .trim();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Math.tex(
                cleanMath,
                textStyle: TextStyle(
                  color: mathTextColor,
                  fontSize: mathFontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
                onErrorFallback: (err) => Text(
                  cleanMath,
                  style: TextStyle(color: const Color(0xFFFF007A), fontSize: mathFontSize),
                ),
              ),
            ),
          ),
        ));
      }
      // 14. Strikethrough (~~...~~)
      else if (match.group(31) != null) {
        final innerText = match.group(32)!;
        spans.addAll(_parseRichInlineSpan(
          innerText,
          textPrimary: textPrimary,
          fontFamily: fontFamily,
          fontSize: fontSize,
          themeAccent: themeAccent,
          isLight: isLight,
          isBold: isBold,
          isItalic: isItalic,
          strikethrough: true,
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < normalizedText.length) {
      final remaining = normalizedText.substring(lastMatchEnd);
      spans.add(TextSpan(
        text: remaining,
        style: TextStyle(
          color: textPrimary,
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
          height: 1.45,
        ),
      ));
    }

    return spans;
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}

