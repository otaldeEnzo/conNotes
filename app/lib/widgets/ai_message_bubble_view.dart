import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/ai_message_model.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../theme/moscaro_v2_extension.dart';
import '../theme/moscaro_theme_controller.dart';
import 'svg_icon.dart';

/// Bolha de Mensagem individual no Chat da IA com Suporte a KaTeX, Ações Dinâmicas e Drag and Drop para o Canvas
class AiMessageBubbleView extends StatelessWidget {
  final AiMessage message;
  final ValueChanged<AiMessage>? onInsertIntoCanvas;
  final ValueChanged<String>? onFollowUpPrompt;

  const AiMessageBubbleView({
    super.key,
    required this.message,
    this.onInsertIntoCanvas,
    this.onFollowUpPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final theme = MoscaroThemeController.instance.currentTheme;
    final accent = theme.accentPrimary;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    // Mensagem da IA com ações de enriquecimento STEM e Drag-and-Drop para o Canvas
    final dynamicButtons = _buildDynamicActionButtons(context, accent);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14, right: 18),
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

            // Conteúdo formatado
            _buildFormattedContent(message.content, accent),

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
            Divider(height: 1, color: accent.withValues(alpha: 0.15)),
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
                        color: const Color(0xFF0F1420).withValues(alpha: 0.95),
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
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                  color: Colors.white70,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                  },
                ),
              ],
            ),
          ],
        ).moscaroV2(
          backgroundColor: theme.backgroundSurface.withValues(alpha: 0.25),
          borderColor: accent.withValues(alpha: 0.45),
          borderWidth: 1.0,
          enableBlur: MoscaroTokens.enableCardsBlur,
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
        ),
      ),
    );
  }

  List<Widget> _buildDynamicActionButtons(BuildContext context, Color accent) {
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
    final match = RegExp(r'\[(?:SUGESTOES|SUGESTÕES):\s*(.*?)\]', caseSensitive: false).firstMatch(content);
    if (match != null) {
      final rawItems = match.group(1)!;
      final itemMatches = RegExp(r'["“](.*?)["”]').allMatches(rawItems);
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
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]', unicode: true), '')
        .replaceAll(RegExp(r'^[^\w\s\$\\]+', unicode: true), '')
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
    return InkWell(
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
    );
  }

  Widget _buildFormattedContent(String text, Color accent) {
    if (text.trim().isEmpty) {
      return const Text('...', style: TextStyle(color: Colors.white38));
    }

    final rawLines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // Oculta a linha de sugestões dinâmicas do texto puro
      if (trimmed.toUpperCase().startsWith('[SUGESTOES:') ||
          trimmed.toUpperCase().startsWith('[SUGESTÕES:')) {
        i++;
        continue;
      }

      // 1. Bloco de Código Multi-linha (``` ... ```)
      if (trimmed.startsWith('```')) {
        final lang = trimmed.length > 3 ? trimmed.substring(3).trim() : '';
        final codeLines = <String>[];
        i++;
        while (i < rawLines.length && !rawLines[i].trim().startsWith('```')) {
          codeLines.add(rawLines[i]);
          i++;
        }
        if (i < rawLines.length) i++; // Pula o fechamento ```

        final code = codeLines.join('\n');
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF070B14).withValues(alpha: 0.85),
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
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Fórmulas matemáticas em bloco $$...$$ ou $$ sozinho
      if (trimmed.startsWith(r'$$')) {
        if (trimmed.endsWith(r'$$') && trimmed.length > 4) {
          final mathContent = trimmed.substring(2, trimmed.length - 2).trim();
          widgets.add(_buildMathBlock(mathContent, accent));
          i++;
          continue;
        } else {
          // Bloco multi-linha $$
          final mathLines = <String>[];
          if (trimmed.length > 2) mathLines.add(trimmed.substring(2));
          i++;
          while (i < rawLines.length && !rawLines[i].trim().endsWith(r'$$')) {
            mathLines.add(rawLines[i]);
            i++;
          }
          if (i < rawLines.length) {
            final last = rawLines[i].trim();
            if (last != r'$$') {
              mathLines.add(last.substring(0, last.length - 2));
            }
            i++;
          }
          widgets.add(_buildMathBlock(mathLines.join(' '), accent));
          continue;
        }
      }

      // 3. Callouts (> [!TIP], > [!THEOREM], > [!DEFINITION], > [!WARNING], etc.)
      if (trimmed.startsWith('> [!')) {
        final closeBracket = trimmed.indexOf(']');
        final tag = closeBracket != -1 ? trimmed.substring(4, closeBracket).trim() : 'INFO';
        final calloutLines = <String>[];
        if (closeBracket != -1 && closeBracket < trimmed.length - 1) {
          final extra = trimmed.substring(closeBracket + 1).trim();
          if (extra.isNotEmpty) calloutLines.add(extra);
        }
        i++;
        while (i < rawLines.length && rawLines[i].trim().startsWith('>')) {
          calloutLines.add(rawLines[i].trim().substring(1).trim());
          i++;
        }

        final upperTag = tag.toUpperCase();
        Color calloutColor = accent;
        String calloutIcon = 'ai';
        if (upperTag.contains('TIP') || upperTag.contains('DICA') || upperTag.contains('INSIGHT')) {
          calloutColor = MoscaroTokens.calloutTipColor;
          calloutIcon = 'brush';
        } else if (upperTag.contains('THEOREM') || upperTag.contains('TEOREMA') || upperTag.contains('FÓRMULA')) {
          calloutColor = MoscaroTokens.calloutTheoremColor;
          calloutIcon = 'shapes';
        } else if (upperTag.contains('WARNING') || upperTag.contains('AVISO') || upperTag.contains('ALERTA') || upperTag.contains('CAUTION')) {
          calloutColor = MoscaroTokens.calloutWarningColor;
          calloutIcon = 'settings';
        } else if (upperTag.contains('CONCEPT') || upperTag.contains('CONCEITO') || upperTag.contains('DEFINIÇÃO')) {
          calloutColor = MoscaroTokens.calloutConceptColor;
          calloutIcon = 'grid';
        }

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: calloutColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: calloutColor.withValues(alpha: 0.35), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: calloutColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgIcon(assetName: calloutIcon, color: calloutColor, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      upperTag,
                      style: TextStyle(
                        color: calloutColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                if (calloutLines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...calloutLines.map((cl) => Padding(
                        padding: const EdgeInsets.only(bottom: 2.5),
                        child: Text.rich(
                          TextSpan(
                            children: _parseInlineSpans(cl, calloutColor, Colors.white.withValues(alpha: 0.95)),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
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

        final double fontSize = level == 1 ? 16 : (level == 2 ? 14.5 : (level == 3 ? 13.5 : 12.5));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(hText, accent, Colors.white),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Linhas de Listas (* ou - ou 1. )
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        String bulletPrefix = '• ';
        String itemText = trimmed;

        final numMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(trimmed);
        if (numMatch != null) {
          bulletPrefix = '${numMatch.group(1)} ';
          itemText = numMatch.group(2)!;
        } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
          itemText = trimmed.substring(2);
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bulletPrefix,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(itemText, accent, Colors.white.withValues(alpha: 0.95)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 6. Linha horizontal separadora (--- ou ***)
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Colors.white12),
          ),
        );
        i++;
        continue;
      }

      // 7. Parágrafo / Linha comum com formatação inline rica (KaTeX, negrito, itálico, código)
      if (trimmed.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(line, accent, Colors.white.withValues(alpha: 0.92)),
              ),
            ),
          ),
        );
      } else {
        widgets.add(const SizedBox(height: 4));
      }

      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildMathBlock(String mathContent, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            mathContent,
            textStyle: const TextStyle(color: Colors.white, fontSize: 14),
            onErrorFallback: (_) => Text(
              r'$$' + mathContent + r'$$',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String text, Color accent, Color textColor) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\$\$(?:\\\$|[^\$])+\$\$|\$(?:\\\$|[^\$])+\$|\*\*[^\*]+\*\*|`[^`]+`|\*[^\*]+\*)');
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: textColor, fontSize: 12.5, height: 1.4),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith(r'$$') && matchedText.endsWith(r'$$') && matchedText.length > 4) {
        final mathStr = matchedText.substring(2, matchedText.length - 2).trim();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                mathStr,
                textStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
                onErrorFallback: (_) => Text(matchedText, style: TextStyle(color: textColor, fontSize: 12)),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith(r'$') && matchedText.endsWith(r'$') && matchedText.length > 2) {
        final mathStr = matchedText.substring(1, matchedText.length - 1).trim();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                mathStr,
                textStyle: const TextStyle(color: Colors.white, fontSize: 13),
                onErrorFallback: (_) => Text(matchedText, style: TextStyle(color: textColor, fontSize: 12)),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith('**') && matchedText.endsWith('**') && matchedText.length > 4) {
        final boldContent = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(
          text: boldContent,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`') && matchedText.length > 2) {
        final codeContent = matchedText.substring(1, matchedText.length - 1);
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*') && matchedText.length > 2) {
        final italicContent = matchedText.substring(1, matchedText.length - 1);
        spans.add(TextSpan(
          text: italicContent,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontStyle: FontStyle.italic,
            fontSize: 12.5,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: textColor, fontSize: 12.5, height: 1.4),
      ));
    }

    return spans;
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
    );
  }
}
