import 'dart:ui';
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
  final void Function(String prompt, String? attachedImageBase64) onSubmitPrompt;
  final List<String> availableNoteTitles;
  final VoidCallback onClearChat;
  final ValueChanged<AiMessage> onInsertIntoCanvas;
  final VoidCallback onOpenSettings;

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
  });

  @override
  State<AiSidebar> createState() => _AiSidebarState();
}

class _AiSidebarState extends State<AiSidebar> {
  final ScrollController _scrollController = ScrollController();
  bool _isModelMenuOpen = false;
  bool _isScopeMenuOpen = false;

  @override
  void didUpdateWidget(covariant AiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty && widget.messages.last.content != oldWidget.messages.lastOrNull?.content)) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      right: widget.isOpen ? 24 : -420,
      top: 24,
      bottom: 24,
      child: ListenableBuilder(
        listenable: MoscaroThemeController.instance,
        builder: (context, _) {
          return _buildSidebarContainer();
        },
      ),
    );
  }

  Widget _buildSidebarContainer() {
    final availableModels = AiServiceBridge.instance.getAvailableModels(SettingsService.instance.settings);
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;
    final accentSecondary = theme.accentSecondary;

    return SizedBox(
      width: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header com Título e Ações Rápidas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgIcon(assetName: 'ai', color: accent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Assistente STEM IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (widget.messages.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar Conversa',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                          onPressed: widget.onClearChat,
                        ),
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close, color: Colors.white60, size: 20),
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

              // 3. Lista de Mensagens do Chat
              Expanded(
                child: widget.messages.isEmpty
                    ? _buildEmptyState(accent)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: widget.messages.length,
                        itemBuilder: (context, index) {
                          final msg = widget.messages[index];
                          return AiMessageBubbleView(
                            message: msg,
                            onInsertIntoCanvas: widget.onInsertIntoCanvas,
                            onFollowUpPrompt: (prompt) => widget.onSubmitPrompt(prompt, null),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 8),

              // 4. Caixa de Entrada de Prompt com Anexos e Menções @notas
              PromptInputBox(
                availableNoteTitles: widget.availableNoteTitles,
                onSubmit: (prompt, attachedImage) {
                  setState(() {
                    _isModelMenuOpen = false;
                    _isScopeMenuOpen = false;
                  });
                  widget.onSubmitPrompt(prompt, attachedImage);
                },
                width: 344,
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
      ),
    ).moscaroV2(
      borderRadius: MoscaroTokens.radiusPanel,
      padding: const EdgeInsets.all(18),
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
