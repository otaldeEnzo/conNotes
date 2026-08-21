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
import 'stem_callout_box_view.dart';

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
  final bool isInteractive;

  const MarkdownLatexBlockView({
    super.key,
    required this.card,
    required this.onContentChanged,
    this.onActiveStylesChanged,
    this.isInteractive = true,
  });

  @override
  State<MarkdownLatexBlockView> createState() => MarkdownLatexBlockViewState();
}

class MarkdownLatexBlockViewState extends State<MarkdownLatexBlockView> {
  int? _editingBlockIndex;
  int? _hoveredBlockIndex;
  late MoscaroRichTextController _blockController;
  late FocusNode _blockFocusNode;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);

  // Estados de Popovers Dinâmicos
  bool _showSlashMenu = false;
  String _slashQuery = '';

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
      if (sel.end > sel.start) {
        _lastSelection = sel;
      }
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
    final sel = _blockController.selection;

    // Se houver estilo de digitação ativo e o cursor estiver parado (sem seleção)
    if (_blockController.hasActiveTypingStyle && (!sel.isValid || sel.isCollapsed)) {
      final ts = _blockController.typingStyle;
      return CardActiveTextStyles(
        isBold: ts.isBold,
        isItalic: ts.isItalic,
        isUnderline: ts.isUnderline,
        isStrikethrough: ts.isStrikethrough,
        isSubscript: ts.isSubscript,
        isSuperscript: ts.isSuperscript,
        isCode: ts.isCode,
        isLatex: ts.isLatex,
        textColor: ts.textColor,
        highlightColor: ts.highlightColor,
        fontSize: ts.fontSize,
      );
    }

    if (!sel.isValid || sel.start < 0) return const CardActiveTextStyles();

    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);

    // Procura spans que tocam o cursor ou a seleção
    final matchingSpans = _blockController.styleSpans.where((s) {
      if (start == end) {
        return s.start <= start && s.end >= start;
      } else {
        return s.start < end && s.end > start;
      }
    }).toList();

    return CardActiveTextStyles(
      isBold: matchingSpans.any((s) => s.isBold),
      isItalic: matchingSpans.any((s) => s.isItalic),
      isUnderline: matchingSpans.any((s) => s.isUnderline),
      isStrikethrough: matchingSpans.any((s) => s.isStrikethrough),
      isSubscript: matchingSpans.any((s) => s.isSubscript),
      isSuperscript: matchingSpans.any((s) => s.isSuperscript),
      isCode: matchingSpans.any((s) => s.isCode),
      isLatex: matchingSpans.any((s) => s.isLatex),
      textColor: matchingSpans.cast<RichStyleSpan?>().firstWhere((s) => s?.textColor != null, orElse: () => null)?.textColor,
      highlightColor: matchingSpans.cast<RichStyleSpan?>().firstWhere((s) => s?.highlightColor != null, orElse: () => null)?.highlightColor,
      fontSize: matchingSpans.cast<RichStyleSpan?>().firstWhere((s) => s?.fontSize != null, orElse: () => null)?.fontSize,
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
    if (content.trim().isEmpty) {
      return [
        const ParsedContentBlock(
          index: 0,
          type: BlockType.markdownText,
          rawText: '',
        ),
      ];
    }

    final rawChunks = content.split('\n---\n');
    return rawChunks.asMap().entries.map((entry) {
      final raw = entry.value.trim();
      if (raw.startsWith('```mermaid')) {
        return ParsedContentBlock(index: entry.key, type: BlockType.mermaidBlock, rawText: raw, language: 'mermaid');
      } else if (raw.startsWith('```')) {
        return ParsedContentBlock(index: entry.key, type: BlockType.codeBlock, rawText: raw);
      } else if (raw.startsWith(r'$$')) {
        return ParsedContentBlock(index: entry.key, type: BlockType.latexBlock, rawText: raw);
      } else if (raw.startsWith('> [!')) {
        return ParsedContentBlock(index: entry.key, type: BlockType.calloutBlock, rawText: raw);
      } else if (raw.startsWith('# ') || raw.startsWith('## ') || raw.startsWith('### ')) {
        return ParsedContentBlock(index: entry.key, type: BlockType.heading, rawText: raw);
      }
      return ParsedContentBlock(index: entry.key, type: BlockType.markdownText, rawText: entry.value);
    }).toList();
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

  /// Salva as alterações do bloco ativo sem fechar o modo de edição
  void _syncBlockContent() {
    if (_editingBlockIndex == null) return;
    final currentBlocks = _parseContentIntoBlocks(widget.card.content);
    final updatedBlocks = <String>[];

    for (int i = 0; i < currentBlocks.length; i++) {
      if (i == _editingBlockIndex) {
        updatedBlocks.add(_blockController.toFormattedText());
      } else {
        updatedBlocks.add(currentBlocks[i].rawText);
      }
    }
    widget.onContentChanged(updatedBlocks.join('\n---\n'));
  }

  /// Conclui a edição do bloco e fecha a caixa de edição
  void _commitBlockEdit() {
    if (_editingBlockIndex == null) return;
    _syncBlockContent();
    setState(() {
      _editingBlockIndex = null;
      _showSlashMenu = false;
    });
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
    setState(() {
      _editingBlockIndex = targetIndex;
      _blockController.loadFromFormattedText('Novo Bloco');
      _blockController.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      _showSlashMenu = false;
    });
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

  /// Insere um snippet no bloco ativo ou no final do card sem fechar o bloco
  void insertSnippetAtActive(String snippet) {
    if (_editingBlockIndex != null) {
      final text = _blockController.text;
      final sel = _blockController.selection;
      if (sel.isValid && sel.start >= 0 && sel.end >= 0) {
        final newText = text.replaceRange(sel.start, sel.end, snippet);
        _blockController.text = newText;
        _blockController.selection = TextSelection.collapsed(offset: sel.start + snippet.length);
        _syncBlockContent();
      } else {
        final newText = '$text$snippet';
        _blockController.text = newText;
        _blockController.selection = TextSelection.collapsed(offset: newText.length);
        _syncBlockContent();
      }
    } else {
      final current = widget.card.content;
      final updated = current.isEmpty ? snippet : '$current\n\n$snippet';
      widget.onContentChanged(updated);
    }
  }

  /// Aplica ou remove (toggle) formatação no texto selecionado ou ativa typingStyle para os próximos caracteres
  void wrapSelection({required String prefix, required String suffix}) {
    if (_editingBlockIndex == null) {
      editLastBlock();
    }

    if (_editingBlockIndex != null) {
      // Restaura a seleção salva se o TextField perdeu foco ao clicar na barra superior
      if (_lastSelection.isValid && _lastSelection.start >= 0 && _lastSelection.end > _lastSelection.start) {
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
        insertSnippetAtActive('$prefix$suffix');
      }

      _lastSelection = _blockController.selection;
      _syncBlockContent();
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

    final blocks = _parseContentIntoBlocks(widget.card.content);
    final availableBodyHeight = math.max(80.0, widget.card.height - 46.0);
    final isSingleBlock = blocks.length <= 1;

    if (widget.card.content.trim().isEmpty && _editingBlockIndex == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _startEditingBlock(const ParsedContentBlock(
            index: 0,
            type: BlockType.markdownText,
            rawText: '',
          ));
        },
        onDoubleTap: () {
          _startEditingBlock(const ParsedContentBlock(
            index: 0,
            type: BlockType.markdownText,
            rawText: '',
          ));
        },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: availableBodyHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          alignment: Alignment.topLeft,
          child: Text(
            'Clique para adicionar texto, fórmulas \$LaTeX\$, callouts ou diagramas...\n(Digite "/" para comandos rápidos ou Ctrl+Enter para novos blocos)',
            style: TextStyle(
              color: textPrimary.withValues(alpha: 0.45),
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: availableBodyHeight),
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
                  minHeight: isSingleBlock ? availableBodyHeight - 20.0 : 60.0,
                );
              }
              return _buildRenderedBlock(
                block,
                isLight,
                themeAccent,
                textPrimary,
                fontFamily,
                fontSize,
                minHeight: isSingleBlock ? availableBodyHeight - 20.0 : 36.0,
              );
            }),
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
    double fontSize, {
    double minHeight = 60.0,
  }) {
    return TapRegion(
      groupId: 'card_block_editor_${widget.card.id}',
      onTapOutside: (_) {
        if (_editingBlockIndex == block.index) {
          _commitBlockEdit();
        }
      },
      child: CallbackShortcuts(
        bindings: {
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
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minHeight),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.only(left: 10, right: 80, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: themeAccent.withValues(alpha: isLight ? 0.08 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeAccent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: themeAccent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _blockController,
                  focusNode: _blockFocusNode,
                  maxLines: null,
                  minLines: minHeight > 100 ? 3 : 1,
                  style: TextStyle(
                    color: textPrimary,
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => _syncBlockContent(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ctrl+Enter: Novo Bloco • "/" Comandos • Ctrl+A: Selecionar tudo',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary.withValues(alpha: 0.45),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),

          // Botões de Ação do Bloco no Canto Superior Direito
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        child: Icon(Icons.add_circle_outline_rounded, size: 14, color: themeAccent),
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
                        child: Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFFF007A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _commitBlockEdit,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: 'Concluir Edição',
                        child: Icon(Icons.check_circle_outline_rounded, size: 15, color: themeAccent),
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
                  final text = _blockController.text;
                  final lastSlash = text.lastIndexOf('/');
                  if (lastSlash >= 0) {
                    _blockController.text = text.substring(0, lastSlash) + cmd.snippet;
                  } else {
                    _blockController.text = cmd.snippet;
                  }
                  _blockController.selection = TextSelection.collapsed(offset: _blockController.text.length);
                  _syncBlockContent();
                  setState(() => _showSlashMenu = false);
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
    double fontSize, {
    double minHeight = 36.0,
  }) {
    final isHovered = _hoveredBlockIndex == block.index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredBlockIndex = block.index),
      onExit: (_) => setState(() => _hoveredBlockIndex = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _startEditingBlock(block),
        onDoubleTap: () => _startEditingBlock(block),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: minHeight),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovered ? themeAccent.withValues(alpha: 0.3) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: _buildBlockContent(block, isLight, themeAccent, textPrimary, fontFamily, fontSize),
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
              padding: const EdgeInsets.all(2),
              child: Tooltip(
                message: 'Editar Bloco',
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 14,
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
              padding: const EdgeInsets.all(2),
              child: Tooltip(
                message: 'Novo Bloco Abaixo',
                child: Icon(Icons.add_rounded, size: 14, color: themeAccent),
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
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
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
        return _buildLatexBlockView(block.rawText, isLight, themeAccent, textPrimary, fontSize);
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
    String title = '';
    final contentLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('> [!')) {
        continue;
      }
      if (trimmed.startsWith('>')) {
        contentLines.add(trimmed.substring(1).trimLeft());
      } else {
        contentLines.add(line);
      }
    }

    return StemCalloutBoxView(
      type: block.calloutType ?? StemCalloutType.tip,
      title: title,
      isLight: isLight,
      fontSize: fontSize,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentLines.map((l) {
          return Text.rich(
            TextSpan(
              children: _parseRichInlineSpan(
                l,
                textPrimary: textPrimary,
                fontFamily: fontFamily,
                fontSize: fontSize * 0.95,
                themeAccent: themeAccent,
                isLight: isLight,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLatexBlockView(String raw, bool isLight, Color themeAccent, Color textPrimary, double fontSize) {
    String mathStr = raw.trim();
    if (mathStr.startsWith(r'$$')) mathStr = mathStr.substring(2);
    if (mathStr.endsWith(r'$$')) mathStr = mathStr.substring(0, mathStr.length - 2);
    mathStr = mathStr.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeAccent.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Math.tex(
        mathStr,
        textStyle: TextStyle(
          color: textPrimary,
          fontSize: fontSize * 1.15,
        ),
        onErrorFallback: (err) => Text(
          raw,
          style: TextStyle(color: const Color(0xFFFF007A), fontSize: fontSize),
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

          // 5. Bloco de Equação LaTeX ($$ ... $$ ou linhas iniciando com comandos matemáticos como \int, \frac, \sum, \sqrt, \begin, \vec, \matrix, \lim)
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
          } else if ((trimmed.startsWith(r'\int') ||
                      trimmed.startsWith(r'\frac') ||
                      trimmed.startsWith(r'\sum') ||
                      trimmed.startsWith(r'\sqrt') ||
                      trimmed.startsWith(r'\lim') ||
                      trimmed.startsWith(r'\begin') ||
                      trimmed.startsWith(r'\vec') ||
                      trimmed.startsWith(r'\matrix')) &&
                     !trimmed.startsWith(r'\\')) {
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text.rich(
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
            ),
          );
        }),
      ],
    );
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

    final spans = <InlineSpan>[];

    // Regex de padrões inline: KaTeX ($...$), HTML Span (<span style="...">), Underline (<u>...</u>), Highlight (==...== / <mark>...), Bold (**...**), Italic (*...*), Sub/Sup, Code (`...`)
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
      r'(\$[^$\n]+\$)', // 29: Inline Math $...$
    );

    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
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
      // 13. Inline KaTeX ($...$)
      else if (match.group(29) != null) {
        final mathSnippet = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            mathSnippet,
            textStyle: TextStyle(
              color: textPrimary,
              fontSize: fontSize * 1.05,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            onErrorFallback: (err) => Text(
              fullMatch,
              style: TextStyle(color: const Color(0xFFFF007A), fontSize: fontSize),
            ),
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final remaining = text.substring(lastMatchEnd);
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
