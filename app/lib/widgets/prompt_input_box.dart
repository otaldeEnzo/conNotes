import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../models/canvas_card_model.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'aurora_border_painter.dart';
import 'svg_icon.dart';

/// Caixa de Prompt de IA com suporte a Anexo de Imagens, Seleção de Área do Canvas, Menções @notas, Borda Aurora e Moscaro v2
class PromptInputBox extends StatefulWidget {
  final void Function(String prompt, List<String> attachedImagesBase64) onSubmit;
  final VoidCallback? onSelectCanvasArea;
  final List<String> availableNoteTitles;
  final double width;
  final bool isActive;

  const PromptInputBox({
    super.key,
    required this.onSubmit,
    this.onSelectCanvasArea,
    this.availableNoteTitles = const [],
    this.width = 540,
    this.isActive = true,
  });

  @override
  State<PromptInputBox> createState() => PromptInputBoxState();
}

class PromptInputBoxState extends State<PromptInputBox> with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<({Uint8List bytes, String base64})> _attachedImages = [];
  String? _attachedTextReference;

  /// Solicita foco imediato para digitação no campo de prompt
  void focus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void unfocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    globalIsEditingText = false;
  }

  /// Permite que chamadores externos (ex: Captura de Área do Canvas ou Card de Mídia)
  /// anexem uma imagem diretamente ao prompt box com foco, anexando à lista de imagens.
  void attachImage({
    required Uint8List bytes,
    required String base64,
    String? defaultPrompt,
    bool clearPrompt = false,
  }) {
    setState(() {
      _attachedImages.add((bytes: bytes, base64: base64));
      if (clearPrompt) {
        _textController.clear();
      } else if (defaultPrompt != null && _textController.text.trim().isEmpty) {
        _textController.text = defaultPrompt;
      }
    });
    _focusNode.requestFocus();
  }

  /// Permite que chamadores externos anexem um trecho de texto selecionado
  /// como citação de referência destacada acima da barra de digitação.
  void attachTextReference(String text, {String? defaultPrompt}) {
    setState(() {
      _attachedTextReference = text.trim();
      if (defaultPrompt != null && _textController.text.trim().isEmpty) {
        _textController.text = defaultPrompt;
      }
    });
    _focusNode.requestFocus();
  }

  // Estado do menu de menções @
  bool _showMentionMenu = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isActive) {
      _auroraController.repeat();
    }

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
        _handlePaste();
      }
      return KeyEventResult.ignored;
    };

    _textController.addListener(_handleTextChange);
    _focusNode.addListener(_syncFocusState);
  }

  void _syncFocusState() {
    globalIsEditingText = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant PromptInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_auroraController.isAnimating) {
          _auroraController.repeat();
        }
      } else {
        _auroraController.stop();
        if (_showMentionMenu) {
          setState(() => _showMentionMenu = false);
        }
        unfocus();
      }
    }
  }

  void _handleTextChange() {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid || !selection.isCollapsed) {
      if (_showMentionMenu) setState(() => _showMentionMenu = false);
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor <= 0) {
      if (_showMentionMenu) setState(() => _showMentionMenu = false);
      return;
    }

    final textBeforeCursor = text.substring(0, cursor);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final isStartOrAfterSpace = lastAt == 0 ||
          textBeforeCursor[lastAt - 1] == ' ' ||
          textBeforeCursor[lastAt - 1] == '\n';

      final query = textBeforeCursor.substring(lastAt + 1);
      final hasSpace = query.contains(' ') || query.contains('\n');

      if (isStartOrAfterSpace && !hasSpace) {
        setState(() {
          _showMentionMenu = true;
          _mentionQuery = query.toLowerCase();
          _mentionStartIndex = lastAt;
        });
        return;
      }
    }

    if (_showMentionMenu) {
      setState(() => _showMentionMenu = false);
    }
  }

  void _insertMention(String noteTitle) {
    if (_mentionStartIndex == -1) return;

    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    final cleanTitle = noteTitle.replaceAll(' ', '_');

    final before = text.substring(0, _mentionStartIndex);
    final after = cursor < text.length ? text.substring(cursor) : '';

    final newText = '$before@$cleanTitle $after';
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (before.length + cleanTitle.length + 2)),
    );

    setState(() {
      _showMentionMenu = false;
      _mentionQuery = '';
      _mentionStartIndex = -1;
    });
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        allowMultiple: true,
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          Uint8List? bytes;
          final path = file.path;
          if (path != null && path.isNotEmpty) {
            final f = File(path);
            if (await f.exists()) {
              bytes = await f.readAsBytes();
            }
          }
          if (bytes == null) {
            try {
              bytes = await file.readAsBytes();
            } catch (_) {}
          }

          if (bytes != null && bytes.isNotEmpty) {
            setState(() {
              _attachedImages.add((
                bytes: bytes!,
                base64: base64Encode(bytes),
              ));
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePaste() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _attachedImages.add((
            bytes: bytes,
            base64: base64Encode(bytes),
          ));
        });
      }
    } catch (_) {}
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImages.isEmpty && _attachedTextReference == null) return;

    final String promptToSend;
    if (_attachedTextReference != null && _attachedTextReference!.isNotEmpty) {
      if (text.isEmpty) {
        promptToSend = 'Analise e explique detalhadamente o seguinte trecho selecionado do documento:\n\n> "$_attachedTextReference"';
      } else {
        promptToSend = 'Referência do documento:\n> "$_attachedTextReference"\n\n$text';
      }
    } else {
      promptToSend = text;
    }

    final imagesToSend = _attachedImages.map((e) => e.base64).toList();
    widget.onSubmit(promptToSend, imagesToSend);
    _textController.clear();
    setState(() {
      _attachedImages.clear();
      _attachedTextReference = null;
      _showMentionMenu = false;
    });
  }

  @override
  void dispose() {
    if (_focusNode.hasFocus) {
      globalIsEditingText = false;
    }
    _focusNode.removeListener(_syncFocusState);
    _focusNode.dispose();
    _auroraController.dispose();
    _textController.removeListener(_handleTextChange);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;

    final filteredNotes = widget.availableNoteTitles.where((title) {
      if (_mentionQuery.isEmpty) return true;
      return title.toLowerCase().contains(_mentionQuery);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Menu Flutuante de Menções @notas
        if (_showMentionMenu && filteredNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: filteredNotes.length,
                itemBuilder: (context, idx) {
                  final noteTitle = filteredNotes[idx];
                  return InkWell(
                    onTap: () => _insertMention(noteTitle),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          SvgIcon(assetName: 'file', color: accent, size: 13),
                          const SizedBox(width: 8),
                          Text(
                            '@$noteTitle',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ).moscaroV2(
              backgroundColor: theme.backgroundSurface.withValues(alpha: 0.32),
              borderColor: accent.withValues(alpha: 0.45),
              borderRadius: 12,
              padding: EdgeInsets.zero,
              enableBlur: true,
            ),
          ),

        // Miniaturas das Imagens Anexadas (Múltiplas Imagens)
        if (_attachedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_attachedImages.length, (index) {
                    final img = _attachedImages[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        right: index < _attachedImages.length - 1 ? 10 : 4,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.memory(
                                img.bytes,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _attachedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: theme.backgroundSurface.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: SvgIcon(
                                      assetName: 'close',
                                      color: MoscaroTokens.textPrimary,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ).moscaroV2(
              backgroundColor: theme.backgroundSurface.withValues(alpha: 0.32),
              borderColor: accent.withValues(alpha: 0.45),
              borderRadius: 10,
              padding: EdgeInsets.zero,
              enableBlur: true,
            ),
          ),

        // Trecho de Referência Anexado (Citação do PDF / STEM)
        if (_attachedTextReference != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: SvgIcon(name: 'highlighter', color: accent, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Referência Citada',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _attachedTextReference!.replaceAll('\n', ' '),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover referência',
                  icon: SvgIcon(name: 'close', color: MoscaroTokens.textMuted, size: 14),
                  onPressed: () {
                    setState(() {
                      _attachedTextReference = null;
                    });
                  },
                ),
              ],
            ).moscaroV2(
              backgroundColor: theme.backgroundSurface.withValues(alpha: 0.32),
              borderColor: accent.withValues(alpha: 0.45),
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              enableBlur: true,
            ),
          ),

        // Campo Principal do Prompt com Borda Aurora e Seleção Externa
        SizedBox(
          width: widget.width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _auroraController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: AuroraBorderPainter(
                        animationValue: _auroraController.value,
                        borderRadius: MoscaroTokens.radiusInput,
                        borderWidth: MoscaroTokens.borderWidthAurora,
                      ),
                      child: Row(
                        children: [
                          // Botão de Anexo de Imagem (SVG Icon) - À ESQUERDA
                          IconButton(
                            tooltip: 'Anexar Imagem',
                            icon: SvgIcon(assetName: 'image', color: accent, size: 16),
                            hoverColor: accent.withValues(alpha: 0.15),
                            onPressed: _pickImage,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              style: TextStyle(color: textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Pergunte à IA (use @ para citar notas)...',
                                hintStyle: TextStyle(
                                  color: textSecondary.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              ),
                              onSubmitted: (_) => _handleSend(),
                            ),
                          ),
                          // Botão de Enviar (SVG Icon) - DENTRO À DIREITA
                          IconButton(
                            tooltip: 'Enviar (Enter)',
                            icon: SvgIcon(assetName: 'send', color: accent, size: 16),
                            hoverColor: accent.withValues(alpha: 0.15),
                            onPressed: _handleSend,
                          ),
                        ],
                      ).moscaroV2(
                        borderRadius: MoscaroTokens.radiusInput,
                        borderWidth: 0,
                        padding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
              // Botão de Seleção de Área do Canvas (SVG Icon) - FORA À DIREITA
              if (widget.onSelectCanvasArea != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Selecionar Área do Canvas para IA',
                  icon: SvgIcon(assetName: 'crop', color: accent, size: 18),
                  hoverColor: accent.withValues(alpha: 0.15),
                  onPressed: widget.onSelectCanvasArea,
                ).moscaroV2(
                  backgroundColor: theme.backgroundSurface.withValues(alpha: 0.35),
                  borderColor: accent.withValues(alpha: 0.45),
                  borderRadius: MoscaroTokens.radiusInput,
                  padding: EdgeInsets.zero,
                  enableBlur: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
