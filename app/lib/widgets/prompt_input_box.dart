import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
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

/// Caixa de Prompt de IA com suporte a Anexo de Imagens, Menções @notas, Borda Aurora e Moscaro v2
class PromptInputBox extends StatefulWidget {
  final void Function(String prompt, String? attachedImageBase64) onSubmit;
  final List<String> availableNoteTitles;
  final double width;

  const PromptInputBox({
    super.key,
    required this.onSubmit,
    this.availableNoteTitles = const [],
    this.width = 540,
  });

  @override
  State<PromptInputBox> createState() => _PromptInputBoxState();
}

class _PromptInputBoxState extends State<PromptInputBox> with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _attachedImageBase64;
  Uint8List? _attachedImageBytes;

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
    )..repeat();

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
        _handlePaste();
      }
      return KeyEventResult.ignored;
    };

    _textController.addListener(_handleTextChange);
    _focusNode.addListener(() {
      globalIsEditingText = _focusNode.hasFocus;
    });
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
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      );

      if (result != null && result.isNotEmpty) {
        final path = result.first.path;
        if (path != null) {
          final file = File(path);
          final bytes = await file.readAsBytes();
          setState(() {
            _attachedImageBytes = bytes;
            _attachedImageBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePaste() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _attachedImageBytes = bytes;
          _attachedImageBase64 = base64Encode(bytes);
        });
      }
    } catch (_) {}
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImageBase64 == null) return;

    widget.onSubmit(text, _attachedImageBase64);
    _textController.clear();
    setState(() {
      _attachedImageBase64 = null;
      _attachedImageBytes = null;
      _showMentionMenu = false;
    });
  }

  @override
  void dispose() {
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
                            style: const TextStyle(
                              color: Colors.white,
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

        // Miniatura da Imagem Anexada
        if (_attachedImageBytes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    _attachedImageBytes!,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Imagem anexada para análise multimodal',
                    style: TextStyle(color: MoscaroTokens.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: MoscaroTokens.textMuted, size: 16),
                  onPressed: () {
                    setState(() {
                      _attachedImageBase64 = null;
                      _attachedImageBytes = null;
                    });
                  },
                ),
              ],
            ).moscaroV2(
              backgroundColor: theme.backgroundSurface.withValues(alpha: 0.32),
              borderColor: accent.withValues(alpha: 0.45),
              borderRadius: 10,
              padding: const EdgeInsets.all(6),
              enableBlur: true,
            ),
          ),

        // Campo Principal do Prompt com Borda Aurora
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, child) {
            return CustomPaint(
              painter: AuroraBorderPainter(
                animationValue: _auroraController.value,
                borderRadius: MoscaroTokens.radiusInput,
                borderWidth: MoscaroTokens.borderWidthAurora,
              ),
              child: SizedBox(
                width: widget.width,
                child: Row(
                  children: [
                    // Botão de Anexo de Imagem (SVG Icon)
                    IconButton(
                      tooltip: 'Anexar Imagem',
                      icon: SvgIcon(assetName: 'brush', color: accent, size: 16),
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Pergunte à IA (use @ para citar notas)...',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_upward, color: accent, size: 20),
                      onPressed: _handleSend,
                    ),
                  ],
                ),
              ).moscaroV2(
                borderRadius: MoscaroTokens.radiusInput,
                borderWidth: 0,
                padding: EdgeInsets.zero,
              ),
            );
          },
        ),
      ],
    );
  }
}
