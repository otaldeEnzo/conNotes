import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/ai_message_model.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';
import 'moscaro_sleek_scrollbar.dart';
import 'mermaid_diagram_painter_view.dart';

/// Bolha de Mensagem individual no Chat da IA com Suporte a KaTeX, Ações Dinâmicas e Drag and Drop para o Canvas
class AiMessageBubbleView extends StatefulWidget {
  final AiMessage message;
  final ValueChanged<AiMessage>? onInsertIntoCanvas;
  final ValueChanged<String>? onFollowUpPrompt;
  final double fontSize;

  const AiMessageBubbleView({
    super.key,
    required this.message,
    this.onInsertIntoCanvas,
    this.onFollowUpPrompt,
    this.fontSize = 14.5,
  });

  @override
  State<AiMessageBubbleView> createState() => _AiMessageBubbleViewState();
}

class _AiMessageBubbleViewState extends State<AiMessageBubbleView> {
  static final RegExp _suggestionsRegex = RegExp(r'\[(?:SUGESTOES|SUGESTÕES):\s*(.*?)\]', caseSensitive: false);
  static final RegExp _quoteItemsRegex = RegExp(r'["“](.*?)["”]');
  static final RegExp _emojiRegex = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]', unicode: true);
  static final RegExp _leadingNonWordRegex = RegExp(r'^[^\w\s\$\\]+', unicode: true);
  static final RegExp _orderedListRegex = RegExp(r'^\d+\.\s+');
  static final RegExp _orderedListItemRegex = RegExp(r'^(\d+\.)\s+(.*)$');
  static final RegExp _inlineMarkdownMathRegex = RegExp(r'(\$\$(?:\\\$|[^\$])+\$\$|\\\[(?:\\\]|[\s\S])+?\\\]|\$(?:\\\$|[^\$])+\$|\\\((?:\\\)|[\s\S])+?\\\)|`[^`]+`|\*\*[^\*]+\*\*|\*[^\*]+\*)');

  Widget? _cachedFormattedContent;
  List<Widget>? _cachedDynamicButtons;
  String? _lastContent;
  double? _lastFontSize;
  int? _lastAccentValue;
  bool? _lastIsLight;
  bool? _lastIsStreaming;

  final List<Widget> _memoizedCompletedBlocks = [];
  int _memoizedLineIndex = 0;
  String _memoizedPrefix = '';

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final fontSize = widget.fontSize;
    final onInsertIntoCanvas = widget.onInsertIntoCanvas;
    final onFollowUpPrompt = widget.onFollowUpPrompt;

    final isUser = message.role == AiMessageRole.user;
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;
    final glassFilm = MoscaroTokens.glassTint;
    final isLight = MoscaroTokens.isLight;

    if (isUser) {
      return RepaintBoundary(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, left: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(accent.withValues(alpha: 0.16), glassFilm),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: textPrimary,
                fontSize: (fontSize * 0.92).clamp(11.0, 18.0),
                height: 1.38,
              ),
            ),
          ),
        ),
      );
    }

    // Cache e memoizacao de alta performance: re-parse O(1) durante resize da sidebar
    final int accentValue = accent.toARGB32();
    final bool shouldRecompute = _cachedFormattedContent == null ||
        _lastContent != message.content ||
        _lastFontSize != fontSize ||
        _lastAccentValue != accentValue ||
        _lastIsLight != isLight ||
        _lastIsStreaming != message.isStreaming;

    if (shouldRecompute) {
      _lastContent = message.content;
      _lastFontSize = fontSize;
      _lastAccentValue = accentValue;
      _lastIsLight = isLight;
      _lastIsStreaming = message.isStreaming;

      _cachedFormattedContent = RepaintBoundary(
        child: _buildFormattedContent(
          message.content,
          accent,
          fontSize: fontSize,
          isStreaming: message.isStreaming,
        ),
      );
      _cachedDynamicButtons = _buildDynamicActionButtons(
        context,
        accent,
        message,
        onFollowUpPrompt,
      );
    }

    final dynamicButtons = _cachedDynamicButtons ?? const <Widget>[];

    return RepaintBoundary(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, right: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do Modelo
              Row(
                children: [
                  SvgIcon(assetName: 'ai', color: accent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    message.modelName != null && message.modelName!.isNotEmpty ? message.modelName! : 'Assistente IA',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (message.isStreaming) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Conteúdo formatado integrado ao Tema Ativo + Moscaro (Memoizado em O(1))
              _cachedFormattedContent!,

              // Mensagem de Erro, se houver
              if (message.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Botões Dinâmicos Contextuais (Dedução, LaTeX, Gráficos, Exemplos - SEM EMOJIS)
              if (dynamicButtons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: dynamicButtons,
                ),
              ],

              const SizedBox(height: 10),
              Divider(height: 1, color: accent.withValues(alpha: 0.18)),
              const SizedBox(height: 8),

              // Ações da Mensagem: Inserir no Canvas (com Draggable) + Copiar Silencioso
              Row(
                children: [
                  // Inserir no Canvas com suporte a Drag and Drop nativo
                  Draggable<AiMessage>(
                    data: message,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: glassFilm,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: accent, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgIcon(assetName: 'grid', color: accent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Solte para criar Card (${_getCardTypeName(message.inferredCardType)})',
                              style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: _buildActionPill(
                      label: 'Inserir no Canvas',
                      iconName: 'grid',
                      color: accent,
                      onTap: () => onInsertIntoCanvas?.call(message),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Copiar Texto Silencioso (Sem SnackBar)
                  _buildActionPill(
                    label: 'Copiar',
                    iconName: 'keyboard',
                    color: textSecondary,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                    },
                  ),
                ],
              ),
            ],
          ).moscaroV2(
            backgroundColor: glassFilm,
            borderColor: accent.withValues(alpha: 0.38),
            borderWidth: MoscaroTokens.borderWidthSubtle,
            enableBlur: false,
            padding: const EdgeInsets.all(14),
            borderRadius: 16,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicActionButtons(
    BuildContext context,
    Color accent,
    AiMessage message,
    ValueChanged<String>? onFollowUpPrompt,
  ) {
    if (message.isStreaming || message.content.trim().isEmpty) return [];

    final content = message.content;
    final lower = content.toLowerCase();

    // Se for mensagem de erro, NÃO mostra botões genéricos de dedução/equação
    if (message.errorMessage != null ||
        content.startsWith('Erro na API') ||
        content.startsWith('Não foi possível') ||
        content.startsWith('O modelo')) {
      return [];
    }

    final buttons = <Widget>[];

    // 1. Extração de sugestões geradas dinamicamente pela própria IA
    final match = _suggestionsRegex.firstMatch(content);
    if (match != null) {
      final rawItems = match.group(1)!;
      final itemMatches = _quoteItemsRegex.allMatches(rawItems);
      for (final m in itemMatches) {
        final rawText = m.group(1)!.trim();
        final cleanLabel = _cleanEmoji(rawText);
        if (cleanLabel.isNotEmpty) {
          final iconKey = _inferIconForLabel(cleanLabel);
          buttons.add(
            _buildDynamicChip(
              icon: iconKey,
              label: cleanLabel,
              accent: accent,
              onTap: () => onFollowUpPrompt?.call(cleanLabel),
            ),
          );
        }
      }
    }

    // 2. Se a IA não incluiu a tag explícita, infere sugestões inteligentes com base no tema (100% SVG, Zero Emojis)
    if (buttons.isEmpty) {
      final hasMath = content.contains(r'$') ||
          content.contains(r'$$') ||
          lower.contains('equação') ||
          lower.contains('log') ||
          lower.contains('integral') ||
          lower.contains('derivada') ||
          lower.contains('fórmula');
      final hasCode = content.contains('```') || lower.contains('código') || lower.contains('algoritmo');
      final hasTheory = content.contains('> [!') || lower.contains('teorema') || lower.contains('propriedade') || lower.contains('definição');

      if (hasMath) {
        buttons.add(
          _buildDynamicChip(
            icon: 'brush',
            label: 'Deduzir Passo a Passo',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Mostre a dedução e resolução matemática detalhada passo a passo deste problema/fórmula.'),
          ),
        );
        buttons.add(
          _buildDynamicChip(
            icon: 'grid',
            label: 'Transformar em KaTeX',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Estruture a resolução e o resultado acima em blocos limpos de KaTeX/LaTeX para anotação formal.'),
          ),
        );
        buttons.add(
          _buildDynamicChip(
            icon: 'shapes',
            label: 'Esboçar Gráfico e Propriedades',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Analise e descreva detalhadamente o comportamento gráfico e as propriedades desta função (raízes, assíntotas, concavidade).'),
          ),
        );
      } else if (hasTheory) {
        buttons.add(
          _buildDynamicChip(
            icon: 'ai',
            label: 'Exemplo Prático Aplicado',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Dê um exemplo prático aplicado no mundo real ou na engenharia sobre este conceito.'),
          ),
        );
        buttons.add(
          _buildDynamicChip(
            icon: 'edit',
            label: 'Testar Meu Conhecimento',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Gere um exercício desafiador com gabarito e resolução comentada sobre este tópico para testar meu entendimento.'),
          ),
        );
      } else if (hasCode) {
        buttons.add(
          _buildDynamicChip(
            icon: 'settings',
            label: 'Análise de Complexidade Big-O',
            accent: accent,
            onTap: () => onFollowUpPrompt?.call('Qual é a análise de complexidade assintótica de tempo e espaço (Big-O) desta solução?'),
          ),
        );
      }
    }

    return buttons;
  }

  String _cleanEmoji(String text) {
    return text
        .replaceAll(_emojiRegex, '')
        .replaceAll(_leadingNonWordRegex, '')
        .trim();
  }

  String _inferIconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('deduzir') || lower.contains('resolver') || lower.contains('passo') || lower.contains('exemplo')) {
      return 'brush';
    } else if (lower.contains('latex') || lower.contains('katex') || lower.contains('fórmula') || lower.contains('esféricas') || lower.contains('coordenadas')) {
      return 'grid';
    } else if (lower.contains('gráfico') || lower.contains('geometria') || lower.contains('jacobiano') || lower.contains('forma')) {
      return 'shapes';
    } else if (lower.contains('código') || lower.contains('algoritmo') || lower.contains('complexidade')) {
      return 'settings';
    } else if (lower.contains('testar') || lower.contains('exercício') || lower.contains('questão')) {
      return 'edit';
    }
    return 'ai';
  }

  Widget _buildDynamicChip({
    required String icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return _MoscaroDynamicActionChip(
      icon: icon,
      label: label,
      accent: accent,
      onTap: onTap,
    );
  }

  String _getCardTypeName(InferredCardType type) {
    switch (type) {
      case InferredCardType.mermaidDiagram:
        return 'Diagrama Mermaid';
      case InferredCardType.plotGraph:
        return 'Gráfico 2D';
      case InferredCardType.codeBlock:
        return 'Código';
      case InferredCardType.stemText:
        return 'Card STEM';
    }
  }

  Widget _buildActionPill({
    required String label,
    required String iconName,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SelectionContainer.disabled(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(assetName: iconName, color: color, size: 11),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent(String text, Color accent, {double fontSize = 14.5, bool isStreaming = false}) {
    if (text.trim().isEmpty) {
      return const Text('...', style: TextStyle(color: Colors.white38));
    }

    final rawLines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    if (isStreaming) {
      if (_memoizedPrefix.isNotEmpty &&
          text.startsWith(_memoizedPrefix) &&
          _memoizedLineIndex > 0 &&
          _memoizedLineIndex < rawLines.length) {
        widgets.addAll(_memoizedCompletedBlocks);
        i = _memoizedLineIndex;
      } else {
        _memoizedCompletedBlocks.clear();
        _memoizedLineIndex = 0;
        _memoizedPrefix = '';
      }
    } else {
      _memoizedCompletedBlocks.clear();
      _memoizedLineIndex = 0;
      _memoizedPrefix = '';
    }

    void commitBlock(Widget w, int nextI, {required bool isComplete}) {
      widgets.add(w);
      if (isStreaming && isComplete) {
        _memoizedCompletedBlocks.add(w);
        _memoizedLineIndex = nextI;
        _memoizedPrefix = rawLines.sublist(0, nextI).join('\n') + (nextI < rawLines.length ? '\n' : '');
      }
    }

    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // Oculta a linha de sugestões dinâmicas do texto puro
      if (trimmed.toUpperCase().startsWith('[SUGESTOES:') ||
          trimmed.toUpperCase().startsWith('[SUGESTÕES:')) {
        i++;
        continue;
      }

      // 1. Bloco de Código Multi-linha (``` ... ```) com suporte nativo a Mermaid
      if (trimmed.startsWith('```')) {
        final lang = trimmed.length > 3 ? trimmed.substring(3).trim() : '';
        final codeLines = <String>[];
        i++;
        while (i < rawLines.length && !rawLines[i].trim().startsWith('```')) {
          codeLines.add(rawLines[i]);
          i++;
        }
        final bool isCodeClosed = i < rawLines.length;
        if (isCodeClosed) i++; // Pula o fechamento ```

        final code = codeLines.join('\n');

        // Se o bloco estiver vazio e não estiver em streaming (ou já foi fechado vazio), ignora para evitar retângulos pretos vazios
        if (code.trim().isEmpty && (!isStreaming || isCodeClosed)) {
          continue;
        }

        // Renderizador especializado para Diagramas Mermaid
        if (lang.toLowerCase() == 'mermaid') {
          if (code.trim().isEmpty) {
            if (isStreaming) {
              commitBlock(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: MoscaroTokens.glassTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gerando diagrama Mermaid...',
                        style: TextStyle(color: MoscaroTokens.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                i,
                isComplete: isCodeClosed,
              );
            }
          } else {
            commitBlock(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: MermaidDiagramPainterView(
                  mermaidCode: code,
                  isLight: MoscaroTokens.isLight,
                  themeAccent: accent,
                  textPrimary: MoscaroTokens.textPrimary,
                  fontSize: fontSize,
                ),
              ),
              i,
              isComplete: isCodeClosed,
            );
          }
          continue;
        }

        // Renderizador especializado para Ilustrações Gráficas Vetoriais SVG
        final trimmedCode = code.trim();
        if (lang.toLowerCase() == 'svg' || (trimmedCode.startsWith('<svg') && trimmedCode.endsWith('</svg>'))) {
          if (trimmedCode.isNotEmpty) {
            commitBlock(
              _buildSvgVisualCard(code, accent, fontSize: fontSize),
              i,
              isComplete: isCodeClosed,
            );
          }
          continue;
        }

        // Bloco de código geral com destaque Moscaro v2 + Tema Ativo
        if (code.trim().isEmpty) {
          continue;
        }

        commitBlock(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MoscaroTokens.glassTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lang.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      lang.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: MoscaroTokens.textPrimary,
                    fontSize: (fontSize * 0.85).clamp(10.0, 16.0),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          i,
          isComplete: isCodeClosed,
        );
        continue;
      }

      // 2. Fórmulas matemáticas em bloco $$...$$ ou \[...\]
      if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
        final isBracket = trimmed.startsWith(r'\[');
        final closeToken = isBracket ? r'\]' : r'$$';
        if (trimmed.endsWith(closeToken) && trimmed.length > 4) {
          final mathContent = trimmed.substring(2, trimmed.length - 2).trim();
          i++;
          commitBlock(_buildMathBlock(mathContent, accent, fontSize: fontSize, isStreaming: isStreaming), i, isComplete: true);
          continue;
        } else {
          // Bloco multi-linha com resiliência a streaming
          final mathLines = <String>[];
          if (trimmed.length > 2) mathLines.add(trimmed.substring(2));
          i++;
          while (i < rawLines.length && !rawLines[i].trim().endsWith(closeToken)) {
            mathLines.add(rawLines[i]);
            i++;
          }
          final bool isMathClosed = i < rawLines.length;
          if (isMathClosed) {
            final last = rawLines[i].trim();
            if (last != closeToken) {
              mathLines.add(last.substring(0, last.length - 2));
            }
            i++;
          }
          commitBlock(_buildMathBlock(mathLines.join('\n'), accent, fontSize: fontSize, isStreaming: isStreaming), i, isComplete: isMathClosed);
          continue;
        }
      }

      // 3. Callouts Moscaro v2 (> [!TIP], > [!NOTE], [!TIP], > [!WARNING], > [!THEOREM], etc.)
      if (trimmed.startsWith('> [!') || trimmed.startsWith('>[!') || trimmed.startsWith('[!')) {
        final startIndex = trimmed.indexOf('[!') + 2;
        final closeBracket = trimmed.indexOf(']', startIndex);
        final tag = closeBracket != -1 ? trimmed.substring(startIndex, closeBracket).trim() : 'NOTE';
        final calloutLines = <String>[];
        if (closeBracket != -1 && closeBracket < trimmed.length - 1) {
          final extra = trimmed.substring(closeBracket + 1).trim();
          if (extra.isNotEmpty) calloutLines.add(extra);
        }
        i++;
        while (i < rawLines.length) {
          final nextTrim = rawLines[i].trim();
          if (nextTrim.startsWith('>')) {
            var lineContent = nextTrim.substring(1);
            if (lineContent.startsWith(' ')) lineContent = lineContent.substring(1);
            calloutLines.add(lineContent);
            i++;
          } else if (trimmed.startsWith('[!') && !nextTrim.startsWith('#') && !nextTrim.startsWith('*') && !nextTrim.startsWith('-') && !nextTrim.startsWith(r'$$') && !nextTrim.startsWith('```') && nextTrim.isNotEmpty) {
            calloutLines.add(nextTrim);
            i++;
          } else {
            break;
          }
        }

        final upperTag = tag.toUpperCase();
        Color calloutColor = accent;
        String calloutIcon = 'ai';
        String displayTitle = upperTag;

        if (upperTag.contains('TIP') || upperTag.contains('DICA') || upperTag.contains('INSIGHT')) {
          calloutColor = MoscaroTokens.calloutTipColor;
          calloutIcon = 'brush';
          displayTitle = upperTag.contains('DICA') ? 'DICA' : 'TIP';
        } else if (upperTag.contains('NOTE') || upperTag.contains('NOTA') || upperTag.contains('INFO')) {
          calloutColor = MoscaroTokens.auroraBlue;
          calloutIcon = 'ai';
          displayTitle = upperTag.contains('NOTA') ? 'NOTA' : 'NOTE';
        } else if (upperTag.contains('THEOREM') || upperTag.contains('TEOREMA') || upperTag.contains('LEMA') || upperTag.contains('COROLÁRIO') || upperTag.contains('COROLARIO')) {
          calloutColor = MoscaroTokens.calloutTheoremColor;
          calloutIcon = 'shapes';
          displayTitle = upperTag.contains('TEOREMA') ? 'TEOREMA' : 'THEOREM';
        } else if (upperTag.contains('WARNING') || upperTag.contains('AVISO') || upperTag.contains('ALERTA')) {
          calloutColor = MoscaroTokens.calloutWarningColor;
          calloutIcon = 'settings';
          displayTitle = upperTag.contains('AVISO') ? 'AVISO' : 'WARNING';
        } else if (upperTag.contains('CAUTION') || upperTag.contains('CUIDADO') || upperTag.contains('PERIGO')) {
          calloutColor = MoscaroTokens.auroraPink;
          calloutIcon = 'settings';
          displayTitle = upperTag.contains('CUIDADO') ? 'CUIDADO' : 'CAUTION';
        } else if (upperTag.contains('IMPORTANT') || upperTag.contains('IMPORTANTE')) {
          calloutColor = MoscaroTokens.auroraAmber;
          calloutIcon = 'ai';
          displayTitle = upperTag.contains('IMPORTANTE') ? 'IMPORTANTE' : 'IMPORTANT';
        } else if (upperTag.contains('CONCEPT') || upperTag.contains('CONCEITO') || upperTag.contains('DEFINITION') || upperTag.contains('DEFINIÇÃO') || upperTag.contains('DEFINICAO')) {
          calloutColor = MoscaroTokens.calloutConceptColor;
          calloutIcon = 'grid';
          displayTitle = upperTag.contains('DEFINI') ? 'DEFINIÇÃO' : (upperTag.contains('CONCEITO') ? 'CONCEITO' : 'CONCEPT');
        }

        commitBlock(
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: calloutColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: calloutColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: calloutColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4.0,
                      decoration: BoxDecoration(
                        color: calloutColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgIcon(assetName: calloutIcon, color: calloutColor, size: 13),
                    const SizedBox(width: 7),
                    Text(
                      displayTitle,
                      style: TextStyle(
                        color: calloutColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                if (calloutLines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...calloutLines.map((cl) {
                    final trimmedCl = cl.trim();
                    if ((trimmedCl.startsWith(r'$$') && trimmedCl.endsWith(r'$$') && trimmedCl.length > 4) ||
                        (trimmedCl.startsWith(r'\[') && trimmedCl.endsWith(r'\]') && trimmedCl.length > 4)) {
                      final mathStr = trimmedCl.substring(2, trimmedCl.length - 2).trim();
                      return _buildMathBlock(
                        mathStr,
                        calloutColor,
                        fontSize: fontSize * 0.95,
                        isStreaming: isStreaming,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2.5),
                      child: Text.rich(
                        TextSpan(
                          children: _parseInlineSpans(
                            cl,
                            calloutColor,
                            MoscaroTokens.textPrimary.withValues(alpha: 0.95),
                            baseFontSize: fontSize * 0.92,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
),
i,
isComplete: i < rawLines.length,
);
        continue;
      }

      // 4. Cabeçalhos (#, ##, ###, ####)
      if (trimmed.startsWith('# ') || trimmed.startsWith('## ') || trimmed.startsWith('### ') || trimmed.startsWith('#### ')) {
        int level = 1;
        String hText = trimmed;
        if (trimmed.startsWith('#### ')) {
          level = 4;
          hText = trimmed.substring(5);
        } else if (trimmed.startsWith('### ')) {
          level = 3;
          hText = trimmed.substring(4);
        } else if (trimmed.startsWith('## ')) {
          level = 2;
          hText = trimmed.substring(3);
        } else if (trimmed.startsWith('# ')) {
          level = 1;
          hText = trimmed.substring(2);
        }

        final double hFontSize = level == 1 ? fontSize * 1.25 : (level == 2 ? fontSize * 1.15 : (level == 3 ? fontSize * 1.05 : fontSize));
        i++;
        commitBlock(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  hText,
                  accent,
                  MoscaroTokens.textPrimary,
                  baseFontSize: hFontSize,
                  fontWeight: FontWeight.bold,
                ),
                style: TextStyle(
                  color: MoscaroTokens.textPrimary,
                  fontSize: hFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          i,
          isComplete: i < rawLines.length,
        );
        continue;
      }

      // 5. Linhas de Listas (* ou - ou 1. )
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || _orderedListRegex.hasMatch(trimmed)) {
        String bulletPrefix = '• ';
        String itemText = trimmed;

        final numMatch = _orderedListItemRegex.firstMatch(trimmed);
        if (numMatch != null) {
          bulletPrefix = '${numMatch.group(1)} ';
          itemText = numMatch.group(2)!;
        } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
          itemText = trimmed.substring(2);
        }

        final trimmedItem = itemText.trim();
        if ((trimmedItem.startsWith(r'$$') && trimmedItem.endsWith(r'$$') && trimmedItem.length > 4) ||
            (trimmedItem.startsWith(r'\[') && trimmedItem.endsWith(r'\]') && trimmedItem.length > 4)) {
          final mathContent = trimmedItem.substring(2, trimmedItem.length - 2).trim();
          i++;
          commitBlock(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    bulletPrefix,
                    style: TextStyle(
                      color: accent,
                      fontSize: fontSize * 0.95,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildMathBlock(mathContent, accent, fontSize: fontSize, isStreaming: isStreaming),
                  ),
                ],
              ),
            ),
            i,
            isComplete: i < rawLines.length,
          );
          continue;
        }

        i++;
        commitBlock(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bulletPrefix,
                  style: TextStyle(
                    color: accent,
                    fontSize: fontSize * 0.95,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        itemText,
                        accent,
                        MoscaroTokens.textPrimary.withValues(alpha: 0.95),
                        baseFontSize: fontSize,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          i,
          isComplete: i < rawLines.length,
        );
        continue;
      }

      // 6. Linha horizontal separadora (--- ou ***)
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        i++;
        commitBlock(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: MoscaroTokens.borderSubtle),
          ),
          i,
          isComplete: i < rawLines.length,
        );
        continue;
      }

      // 7. Parágrafo / Linha comum com formatação inline rica (KaTeX, negrito, itálico, código)
      i++;
      if (trimmed.isNotEmpty) {
        commitBlock(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  line,
                  accent,
                  MoscaroTokens.textPrimary.withValues(alpha: 0.92),
                  baseFontSize: fontSize,
                ),
              ),
            ),
          ),
          i,
          isComplete: i < rawLines.length,
        );
      } else {
        commitBlock(const SizedBox(height: 4), i, isComplete: i < rawLines.length);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMathBlock(String rawMath, Color accent, {double fontSize = 14.5, bool isStreaming = false}) {
    final cleaned = rawMath.trim();
    if (cleaned.isEmpty) {
      if (isStreaming) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.2, valueColor: AlwaysStoppedAnimation(accent)),
              ),
              const SizedBox(width: 6),
              Text(r'$$ ...', style: TextStyle(color: accent.withValues(alpha: 0.6), fontSize: 11.5)),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final sanitized = _sanitizeLatex(cleaned);
    if (sanitized.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final textPrimary = MoscaroTokens.textPrimary;
    final textSecondary = MoscaroTokens.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 0.9),
      ),
      child: Center(
        child: _ScrollableMathBlock(
          accent: accent,
          child: _SafeMathTex(
            latex: sanitized,
            rawLatex: cleaned,
            isDisplay: true,
            textStyle: TextStyle(color: textPrimary, fontSize: fontSize * 1.05),
            fallbackStyle: TextStyle(color: textSecondary, fontSize: fontSize * 0.85, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }

  Widget _buildSvgVisualCard(String svgCode, Color accent, {double fontSize = 14.5}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: MoscaroTokens.glassTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.24), width: 1.0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgIcon(assetName: 'shapes', color: accent, size: 14),
                    const SizedBox(width: 7),
                    Text(
                      'Ilustração Gráfica STEM (SVG)',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140, maxHeight: 380),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SvgPicture.string(
                    svgCode,
                    placeholderBuilder: (_) => const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

  static String _sanitizeLatex(String latex) {
    var s = latex.trim();
    if (s.isEmpty) return s;

    // Remove barra invertida pendente no final (streaming)
    if (s.endsWith(r'\')) {
      s = s.substring(0, s.length - 1).trim();
    }

    // Se terminar com sobrescrito/subscrito incompleto, fecha com {}
    if (s.endsWith('^') || s.endsWith('_')) {
      s = '$s{}';
    }

    // Balanceia chaves unclosed '{' durante streaming
    int openBraces = 0;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '{' && (i == 0 || s[i - 1] != r'\')) {
        openBraces++;
      } else if (s[i] == '}' && (i == 0 || s[i - 1] != r'\')) {
        if (openBraces > 0) openBraces--;
      }
    }
    if (openBraces > 0) {
      s = s + ('}' * openBraces);
    }

    return s;
  }

  List<InlineSpan> _parseInlineSpans(
    String text,
    Color accent,
    Color textColor, {
    double baseFontSize = 13.5,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    final spans = <InlineSpan>[];
    int lastIndex = 0;
    final textPrimary = MoscaroTokens.textPrimary;

    for (final match in _inlineMarkdownMathRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            color: textColor,
            fontSize: baseFontSize,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            height: 1.4,
          ),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith(r'$$') && matchedText.endsWith(r'$$') && matchedText.length > 4) {
        final mathStr = matchedText.substring(2, matchedText.length - 2).trim();
        final sanitized = _sanitizeLatex(mathStr);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: _ScrollableMathBlock(
                  accent: accent,
                  child: _SafeMathTex(
                    latex: sanitized,
                    rawLatex: mathStr,
                    isDisplay: false,
                    textStyle: TextStyle(color: textPrimary, fontSize: baseFontSize * 1.05, fontWeight: fontWeight),
                    fallbackStyle: TextStyle(color: textColor, fontSize: baseFontSize * 0.85, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith(r'\[') && matchedText.endsWith(r'\]') && matchedText.length > 4) {
        final mathStr = matchedText.substring(2, matchedText.length - 2).trim();
        final sanitized = _sanitizeLatex(mathStr);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: _ScrollableMathBlock(
                  accent: accent,
                  child: _SafeMathTex(
                    latex: sanitized,
                    rawLatex: mathStr,
                    isDisplay: false,
                    textStyle: TextStyle(color: textPrimary, fontSize: baseFontSize * 1.05, fontWeight: fontWeight),
                    fallbackStyle: TextStyle(color: textColor, fontSize: baseFontSize * 0.85, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith(r'$') && matchedText.endsWith(r'$') && matchedText.length > 2) {
        final mathStr = matchedText.substring(1, matchedText.length - 1).trim();
        final sanitized = _sanitizeLatex(mathStr);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: _ScrollableMathBlock(
                  accent: accent,
                  child: _SafeMathTex(
                    latex: sanitized,
                    rawLatex: mathStr,
                    isDisplay: false,
                    textStyle: TextStyle(color: textPrimary, fontSize: baseFontSize, fontWeight: fontWeight),
                    fallbackStyle: TextStyle(color: textColor, fontSize: baseFontSize * 0.85, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith(r'\(') && matchedText.endsWith(r'\)') && matchedText.length > 4) {
        final mathStr = matchedText.substring(2, matchedText.length - 2).trim();
        final sanitized = _sanitizeLatex(mathStr);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: _ScrollableMathBlock(
                  accent: accent,
                  child: _SafeMathTex(
                    latex: sanitized,
                    rawLatex: mathStr,
                    isDisplay: false,
                    textStyle: TextStyle(color: textPrimary, fontSize: baseFontSize, fontWeight: fontWeight),
                    fallbackStyle: TextStyle(color: textColor, fontSize: baseFontSize * 0.85, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith('**') && matchedText.endsWith('**') && matchedText.length > 4) {
        final boldContent = matchedText.substring(2, matchedText.length - 2);
        // Recursivamente faz parsing de KaTeX/código dentro de trechos em negrito (**Elemento $dm$**)
        spans.addAll(
          _parseInlineSpans(
            boldContent,
            accent,
            textPrimary,
            baseFontSize: baseFontSize,
            fontWeight: FontWeight.bold,
            fontStyle: fontStyle,
          ),
        );
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`') && matchedText.length > 2) {
        final codeContent = matchedText.substring(1, matchedText.length - 1);
        final isMathLike = codeContent.contains(r'\') ||
            codeContent.contains('^') ||
            codeContent.contains('_') ||
            codeContent.contains('∫') ||
            codeContent.contains('∂') ||
            codeContent.contains('∇') ||
            codeContent.contains('±');

        if (isMathLike) {
          final sanitized = _sanitizeLatex(codeContent);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _SafeMathTex(
                  latex: sanitized,
                  rawLatex: codeContent,
                  isDisplay: false,
                  textStyle: TextStyle(
                    color: textPrimary,
                    fontSize: baseFontSize,
                    fontWeight: fontWeight,
                  ),
                  fallbackStyle: TextStyle(
                    color: accent,
                    fontSize: (baseFontSize * 0.85).clamp(10.0, 16.0),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          );
        } else {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Text(
                  codeContent,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: (baseFontSize * 0.85).clamp(10.0, 16.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*') && matchedText.length > 2) {
        final italicContent = matchedText.substring(1, matchedText.length - 1);
        spans.addAll(
          _parseInlineSpans(
            italicContent,
            accent,
            textPrimary.withValues(alpha: 0.92),
            baseFontSize: baseFontSize,
            fontWeight: fontWeight,
            fontStyle: FontStyle.italic,
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: textColor,
          fontSize: baseFontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: 1.4,
        ),
      ));
    }

    return spans;
  }
}

/// Widget seguro de renderização KaTeX/LaTeX com fallback resiliente para streaming e erros de sintaxe
class _SafeMathTex extends StatelessWidget {
  final String latex;
  final String rawLatex;
  final TextStyle textStyle;
  final TextStyle fallbackStyle;
  final bool isDisplay;

  const _SafeMathTex({
    required this.latex,
    required this.rawLatex,
    required this.textStyle,
    required this.fallbackStyle,
    this.isDisplay = false,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    try {
      return Math.tex(
        latex,
        mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
        textStyle: textStyle,
        onErrorFallback: (FlutterMathException err) {
          return Text(
            isDisplay ? r'$$ ' + rawLatex + r' $$' : r'$' + rawLatex + r'$',
            style: fallbackStyle,
          );
        },
      );
    } catch (_) {
      return Text(
        isDisplay ? r'$$ ' + rawLatex + r' $$' : r'$' + rawLatex + r'$',
        style: fallbackStyle,
      );
    }
  }
}

/// Bloco matemÃ¡tico com rolagem horizontal suportada por MoscaroSleekScrollbar elegante
class _ScrollableMathBlock extends StatefulWidget {
  final Widget child;
  final Color accent;

  const _ScrollableMathBlock({
    required this.child,
    required this.accent,
  });

  @override
  State<_ScrollableMathBlock> createState() => _ScrollableMathBlockState();
}

class _ScrollableMathBlockState extends State<_ScrollableMathBlock> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MoscaroSleekScrollbar(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      thumbColor: widget.accent.withValues(alpha: 0.65),
      thickness: 3.5,
      padding: const EdgeInsets.only(top: 2),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 6),
        child: widget.child,
      ),
    );
  }
}

/// Chip de Ação Dinâmica com Efeitos Moscaro de Hover, Brilho e Feedback Tátil ao Clicar
class _MoscaroDynamicActionChip extends StatefulWidget {
  final String icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _MoscaroDynamicActionChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_MoscaroDynamicActionChip> createState() => _MoscaroDynamicActionChipState();
}

class _MoscaroDynamicActionChipState extends State<_MoscaroDynamicActionChip> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return SelectionContainer.disabled(
      child: MouseRegion(
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
            scale: _isPressed ? 0.94 : (_isHovered ? 1.04 : 1.0),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
              decoration: BoxDecoration(
                color: _isPressed
                    ? accent.withValues(alpha: 0.38)
                    : (_isHovered ? accent.withValues(alpha: 0.24) : accent.withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered ? accent : accent.withValues(alpha: 0.40),
                  width: _isHovered ? 1.3 : 1.0,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgIcon(
                    assetName: widget.icon,
                    color: _isHovered ? Colors.white : accent,
                    size: 11.5,
                  ),
                  const SizedBox(width: 5.5),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.95),
                      fontSize: 10.5,
                      fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
