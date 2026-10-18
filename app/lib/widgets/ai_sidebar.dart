import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/ai_message_model.dart';
import '../models/ai_provider_models.dart';
import '../services/ai_service_bridge.dart';
import '../services/settings_service.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'ai_message_bubble_view.dart';
import 'ai_model_selector_pill.dart';
import 'ai_scope_selector_pill.dart';
import 'prompt_input_box.dart';
import 'settings_models.dart';
import 'svg_icon.dart';

/// Painel Lateral Direito da IA em Vidro Líquido Moscaro v2 com Chat Reativo, Seletores e Drag and Drop
class AiSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final List<AiMessage> messages;
  final bool isStreaming;
  final AiModelDefinition activeModel;
  final AiScopeType activeScope;
  final ValueChanged<AiModelDefinition> onSelectModel;
  final ValueChanged<AiScopeType> onSelectScope;
  final void Function(String prompt, List<String> attachedImagesBase64) onSubmitPrompt;
  final List<String> availableNoteTitles;
  final VoidCallback onClearChat;
  final ValueChanged<AiMessage> onInsertIntoCanvas;
  final VoidCallback onOpenSettings;
  final VoidCallback? onSelectCanvasArea;

  const AiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.messages,
    required this.isStreaming,
    required this.activeModel,
    required this.activeScope,
    required this.onSelectModel,
    required this.onSelectScope,
    required this.onSubmitPrompt,
    this.availableNoteTitles = const [],
    required this.onClearChat,
    required this.onInsertIntoCanvas,
    required this.onOpenSettings,
    this.onSelectCanvasArea,
  });

  @override
  State<AiSidebar> createState() => AiSidebarState();
}

class AiSidebarState extends State<AiSidebar> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<PromptInputBoxState> promptInputKey = GlobalKey<PromptInputBoxState>();
  final GlobalKey _latestResponseKey = GlobalKey();
  bool _isModelMenuOpen = false;
  bool _isScopeMenuOpen = false;
  bool _showScrollToBottom = false;
  double? _customWidth;
  double? _customFontSize;
  bool _isResizing = false;
  double _dragStartGlobalX = 0.0;
  double _dragStartWidth = 480.0;
  int _lastResizeTime = 0;

  /// Permite anexar imagem externamente (captura do canvas ou card de mídia)
  void attachImage({
    required Uint8List bytes,
    required String base64,
    String? defaultPrompt,
    bool clearPrompt = false,
  }) {
    promptInputKey.currentState?.attachImage(
      bytes: bytes,
      base64: base64,
      defaultPrompt: defaultPrompt,
      clearPrompt: clearPrompt,
    );
  }

  /// Permite anexar texto de referência externamente (seleção em documento PDF)
  void attachTextReference(String text, {String? defaultPrompt}) {
    promptInputKey.currentState?.attachTextReference(
      text,
      defaultPrompt: defaultPrompt,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollPosition);
    final settings = SettingsService.instance.settings;
    _customWidth = settings.aiSidebarWidth;
    _customFontSize = settings.aiSidebarFontSize;
    if (widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        promptInputKey.currentState?.focus();
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && widget.isOpen) {
          promptInputKey.currentState?.focus();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients || widget.messages.isEmpty) {
      if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 20) {
      if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
      return;
    }
    final isNotAtBottom = _scrollController.offset < position.maxScrollExtent - 60;
    if (isNotAtBottom != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isNotAtBottom;
      });
    }
  }

  @override
  void didUpdateWidget(covariant AiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settings = SettingsService.instance.settings;
    if (!_isResizing) {
      _customWidth = settings.aiSidebarWidth;
    }
    _customFontSize = settings.aiSidebarFontSize;
    if (!widget.isOpen && oldWidget.isOpen) {
      if (_isModelMenuOpen || _isScopeMenuOpen) {
        setState(() {
          _isModelMenuOpen = false;
          _isScopeMenuOpen = false;
        });
      }
      promptInputKey.currentState?.unfocus();
    }
    if (widget.isOpen && !oldWidget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        promptInputKey.currentState?.focus();
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && widget.isOpen) {
          promptInputKey.currentState?.focus();
        }
      });
    }
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkScrollPosition();
      });
    }
  }

  /// Rola o chat suavemente priorizando a visualização do topo da resposta gerada
  void _scrollToNewResponse() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final targetContext = _latestResponseKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.05,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final currentWidth = _customWidth ?? settings.aiSidebarWidth;

    return AnimatedPositioned(
      duration: _isResizing ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      right: widget.isOpen ? 24 : -(currentWidth + 60),
      top: 48,
      bottom: 24,
      child: IgnorePointer(
        ignoring: !widget.isOpen,
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              MoscaroThemeController.instance,
              SettingsService.instance,
            ]),
            builder: (context, _) {
              return _buildSidebarContainer();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContainer() {
    final settings = SettingsService.instance.settings;
    final currentWidth = _customWidth ?? settings.aiSidebarWidth;
    final currentFontSize = _customFontSize ?? settings.aiSidebarFontSize;
    final availableModels = AiServiceBridge.instance.getAvailableModels(settings);
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final isExpanded = currentWidth >= 620.0;

    return SizedBox(
      width: currentWidth,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header com Titulo e Acoes Rapidas (Anti-overflow Responsivo)
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgIcon(assetName: 'ai', color: accent, size: 19),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  currentWidth < 410 ? 'Assistente IA' : 'Assistente STEM IA',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Seletor de Tamanho de Fonte Moscaro v2
                            _buildFontSizePill(
                              settings: settings,
                              currentFontSize: currentFontSize,
                              accent: accent,
                              textSecondary: textSecondary,
                            ),
                            const SizedBox(width: 4),

                            // Botao Alternar Modo Expandido / Padrao
                            IconButton(
                              tooltip: isExpanded ? 'Modo Padrao (480px)' : 'Modo Estudo Amplo (700px)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: Icon(
                                isExpanded ? Icons.view_sidebar_rounded : Icons.open_in_full_rounded,
                                color: isExpanded ? accent : textSecondary,
                                size: 15,
                              ),
                              onPressed: () {
                                final targetWidth = isExpanded ? 480.0 : 700.0;
                                setState(() => _customWidth = targetWidth);
                                SettingsService.instance.updateSettings(settings.copyWith(aiSidebarWidth: targetWidth));
                              },
                            ),

                            if (widget.messages.isNotEmpty)
                              IconButton(
                                tooltip: 'Limpar Conversa',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                icon: Icon(Icons.delete_outline_rounded, color: textSecondary, size: 17),
                                onPressed: widget.onClearChat,
                              ),
                            IconButton(
                              tooltip: 'Fechar',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: Icon(Icons.close, color: textSecondary, size: 17),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

              // 2. Barra de Seletores (Modelo Ativo + Grau de Consciência)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AiModelSelectorPill(
                      selectedModel: widget.activeModel,
                      isOpen: _isModelMenuOpen,
                      onToggle: () {
                        setState(() {
                          _isModelMenuOpen = !_isModelMenuOpen;
                          if (_isModelMenuOpen) _isScopeMenuOpen = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    AiScopeSelectorPill(
                      selectedScope: widget.activeScope,
                      isOpen: _isScopeMenuOpen,
                      onToggle: () {
                        setState(() {
                          _isScopeMenuOpen = !_isScopeMenuOpen;
                          if (_isScopeMenuOpen) _isModelMenuOpen = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 8),

              // 3. Lista de Mensagens do Chat com RepaintBoundary, Seleção Nativa de Texto e HUD Scroll-to-Bottom
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: widget.messages.isEmpty
                          ? _buildEmptyState(accent)
                          : RepaintBoundary(
                              child: SelectionArea(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  addRepaintBoundaries: true,
                                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                                  itemCount: widget.messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = widget.messages[index];
                                    final isLatest = index == widget.messages.length - 1;
                                    return KeyedSubtree(
                                      key: isLatest ? _latestResponseKey : ValueKey(msg.id),
                                      child: AiMessageBubbleView(
                                        message: msg,
                                        fontSize: currentFontSize,
                                        onInsertIntoCanvas: widget.onInsertIntoCanvas,
                                        onFollowUpPrompt: (prompt) => widget.onSubmitPrompt(prompt, const []),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),

                    // Botao Flutuante Moscaro v2 Scroll-to-Bottom
                    Positioned(
                      bottom: 8,
                      child: IgnorePointer(
                        ignoring: !_showScrollToBottom,
                        child: AnimatedOpacity(
                          opacity: _showScrollToBottom ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: AnimatedScale(
                            scale: _showScrollToBottom ? 1.0 : 0.6,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: SelectionContainer.disabled(
                              child: _MoscaroScrollToBottomButton(
                                accent: accent,
                                onTap: _scrollToNewResponse,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 4. Caixa de Entrada de Prompt com Anexos e Menções @notas
              PromptInputBox(
                key: promptInputKey,
                onSelectCanvasArea: widget.onSelectCanvasArea,
                availableNoteTitles: widget.availableNoteTitles,
                onSubmit: (prompt, attachedImages) {
                  setState(() {
                    _isModelMenuOpen = false;
                    _isScopeMenuOpen = false;
                  });
                  widget.onSubmitPrompt(prompt, attachedImages);
                },
                width: currentWidth - 36,
              ),
            ],
          ),

          // Barreira transparente para fechar os menus suspensos ao clicar fora
          if (_isModelMenuOpen || _isScopeMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isModelMenuOpen = false;
                    _isScopeMenuOpen = false;
                  });
                },
              ),
            ),

          // Gavetas sobrepostas ao chat (Moscaro Glassmorphism com Animação Fluida)
          Positioned(
            top: 92,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.06),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isModelMenuOpen
                  ? KeyedSubtree(
                      key: const ValueKey('model_menu'),
                      child: _buildModelDropdownInline(availableModels, theme, accent),
                    )
                  : (_isScopeMenuOpen
                      ? KeyedSubtree(
                          key: const ValueKey('scope_menu'),
                          child: _buildScopeDropdownInline(theme, accent),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty_menu'))),
            ),
          ),
        ],
      ).moscaroV2(
        borderRadius: MoscaroTokens.radiusPanel,
        enableBlur: true,
        padding: const EdgeInsets.all(18),
      ),
    ),

    // 2. Alca Arrastavel na Borda Externa Esquerda da Sidebar
    Positioned(
      left: -7,
      top: 0,
      bottom: 0,
      width: 14,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            _dragStartGlobalX = details.globalPosition.dx;
            _dragStartWidth = currentWidth;
            setState(() => _isResizing = true);
          },
          onHorizontalDragUpdate: (details) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - _lastResizeTime < 16) return;
            final double deltaX = _dragStartGlobalX - details.globalPosition.dx;
            final double newW = (_dragStartWidth + deltaX).clamp(380.0, 840.0);
            if ((newW - (_customWidth ?? _dragStartWidth)).abs() >= 1.5) {
              _lastResizeTime = now;
              setState(() {
                _customWidth = newW;
              });
            }
          },
          onHorizontalDragEnd: (_) {
            setState(() => _isResizing = false);
            if (_customWidth != null) {
              SettingsService.instance.updateSettings(
                SettingsService.instance.settings.copyWith(aiSidebarWidth: _customWidth),
              );
            }
          },
          onHorizontalDragCancel: () {
            setState(() => _isResizing = false);
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: _isResizing ? 4.0 : 2.5,
              height: _isResizing ? 64 : 48,
              decoration: BoxDecoration(
                color: _isResizing ? accent : accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _isResizing ? 0.55 : 0.2),
                    blurRadius: _isResizing ? 10 : 4,
                    spreadRadius: _isResizing ? 1 : 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ],
),
);
}

  /// Seletor segmentado Moscaro v2 para ajuste dinamico do tamanho da fonte da IA
  Widget _buildFontSizePill({
    required AppSettingsState settings,
    required double currentFontSize,
    required Color accent,
    required Color textSecondary,
  }) {
    final bool canDecrement = currentFontSize > 12.0;
    final bool canIncrement = currentFontSize < 20.0;

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoscaroTokens.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Micro-botao Diminuir (-)
            Tooltip(
              message: 'Diminuir fonte (${currentFontSize.round() - 1}pt)',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                onTap: canDecrement
                    ? () {
                        final newSize = (currentFontSize - 1.0).clamp(12.0, 20.0);
                        setState(() => _customFontSize = newSize);
                        SettingsService.instance.updateSettings(
                          settings.copyWith(aiSidebarFontSize: newSize),
                        );
                      }
                    : null,
                child: SizedBox(
                  width: 26,
                  height: 30,
                  child: Center(
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: canDecrement ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Badge central com indicador de tamanho e ponto de acento do tema ativo
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${currentFontSize.round()}pt',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            // Micro-botao Aumentar (+)
            Tooltip(
              message: 'Aumentar fonte (${currentFontSize.round() + 1}pt)',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                onTap: canIncrement
                    ? () {
                        final newSize = (currentFontSize + 1.0).clamp(12.0, 20.0);
                        setState(() => _customFontSize = newSize);
                        SettingsService.instance.updateSettings(
                          settings.copyWith(aiSidebarFontSize: newSize),
                        );
                      }
                    : null,
                child: SizedBox(
                  width: 26,
                  height: 30,
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: canIncrement ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDropdownInline(
    List<AiModelDefinition> availableModels,
    dynamic theme,
    Color accent,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (availableModels.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Nenhuma chave de IA configurada',
                style: TextStyle(color: MoscaroTokens.textSecondary, fontSize: 12),
              ),
            ),
          ] else ...[
            ...availableModels.map((m) {
              final isSelected = m.id == widget.activeModel.id;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  widget.onSelectModel(m);
                  // Feedback visual imediato antes de fechar suavemente
                  await Future.delayed(const Duration(milliseconds: 140));
                  if (mounted) {
                    setState(() {
                      _isModelMenuOpen = false;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.6) : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? accent : Colors.white30,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.displayName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : MoscaroTokens.textPrimary,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            Text(
                              m.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: MoscaroTokens.textSecondary.withValues(alpha: 0.8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      if (m.badge.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            m.badge,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_rounded, color: accent, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
          const Divider(height: 12, color: Colors.white10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _isModelMenuOpen = false;
              });
              widget.onOpenSettings();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SvgIcon(assetName: 'settings', color: accent, size: 14),
                  const SizedBox(width: 8),
                  const Text(
                    'Configurar Chaves de API...',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).moscaroV2(
      borderRadius: 16,
      padding: const EdgeInsets.all(8),
      borderColor: accent.withValues(alpha: 0.5),
      borderWidth: 1.2,
    );
  }

  Widget _buildScopeDropdownInline(
    dynamic theme,
    Color accent,
  ) {
    final scopes = [
      (
        AiScopeType.activeNote,
        'Nota Ativa',
        'Envia apenas os cards e blocos do canvas aberto',
        'grid',
      ),
      (
        AiScopeType.currentNotebook,
        'Caderno Atual',
        'Lê todas as notas e páginas do caderno selecionado',
        'brush',
      ),
      (
        AiScopeType.allNotes,
        'Todas as Notas',
        'Visão global do workspace completo de estudos',
        'palette',
      ),
    ];

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: scopes.map((item) {
          final isSelected = item.$1 == widget.activeScope;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              widget.onSelectScope(item.$1);
              // Feedback visual imediato antes de fechar suavemente
              await Future.delayed(const Duration(milliseconds: 140));
              if (mounted) {
                setState(() {
                  _isScopeMenuOpen = false;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? accent.withValues(alpha: 0.22) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accent.withValues(alpha: 0.6) : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SvgIcon(
                    assetName: item.$4,
                    color: isSelected ? accent : Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: isSelected ? Colors.white : MoscaroTokens.textPrimary,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        Text(
                          item.$3,
                          style: TextStyle(color: MoscaroTokens.textSecondary.withValues(alpha: 0.8), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_rounded, color: accent, size: 16),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ).moscaroV2(
      borderRadius: 16,
      padding: const EdgeInsets.all(8),
      borderColor: accent.withValues(alpha: 0.5),
      borderWidth: 1.2,
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.1),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: SvgIcon(assetName: 'ai', color: accent, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Como posso ajudar no seu estudo?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Faça perguntas de matemática, deduções físicas ou arraste respostas direto para o canvas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MoscaroTokens.textSecondary, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão flutuante animado com estética Moscaro v2 para rolagem ao fim do chat
class _MoscaroScrollToBottomButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;

  const _MoscaroScrollToBottomButton({
    required this.accent,
    required this.onTap,
  });

  @override
  State<_MoscaroScrollToBottomButton> createState() => _MoscaroScrollToBottomButtonState();
}

class _MoscaroScrollToBottomButtonState extends State<_MoscaroScrollToBottomButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final isLight = MoscaroTokens.isLight;

    final bgColor = isLight
        ? (_isHovered ? Colors.white.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.85))
        : (_isHovered
            ? Color.alphaBlend(accent.withValues(alpha: 0.22), MoscaroTokens.backgroundSurface.withValues(alpha: 0.92))
            : Color.alphaBlend(accent.withValues(alpha: 0.12), MoscaroTokens.backgroundSurface.withValues(alpha: 0.85)));

    final borderColor = _isHovered
        ? accent.withValues(alpha: 0.75)
        : accent.withValues(alpha: 0.40);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isHovered ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Tooltip(
            message: 'Rolar para o fim',
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _isHovered ? 0.35 : 0.18),
                    blurRadius: _isHovered ? 12 : 8,
                    spreadRadius: _isHovered ? 1.5 : 0.5,
                  ),
                  const BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: SvgIcon(
                  assetName: 'chevron_down',
                  color: accent,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
