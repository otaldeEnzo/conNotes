import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/canvas_card_model.dart';
import '../models/ai_provider_models.dart';
import '../widgets/note_models.dart';
import '../widgets/undo_commands.dart';
import 'ai_service_bridge.dart';
import 'ocr_image_preprocessor.dart';
import 'settings_service.dart';
import 'workspace_storage_service.dart';

/// Serviço responsável pelo pipeline de extração de LaTeX e OCR de cards de mídia.
/// Trata o modo Offline (Privado / Local) e o modo Nuvem (IA Multimodal),
/// além de calcular as dimensões estéticas ideais do card de destino.
class CanvasMediaOcrService {
  CanvasMediaOcrService._();
  static final CanvasMediaOcrService instance = CanvasMediaOcrService._();

  /// Limpa sugestões, delimitadores ou mensagens de erro da resposta bruta do OCR/IA
  String sanitizeLatexOcrOutput(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'\[(?:SUGESTOES|SUGESTÕES):\s*.*?\]', caseSensitive: false, dotAll: true), '');
    text = text.replaceAll(RegExp(r'(?:Sugestões|Sugestoes|Suggestions):\s*.*', caseSensitive: false, dotAll: true), '');
    
    if (text.startsWith('```latex')) {
      text = text.substring(8);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    text = text.trim();

    final lower = text.toLowerCase();
    final errorKeywords = [
      'servidor', 'sobrecarregado', 'temporariamente', 'erro', 'error',
      'rate limit', 'quota', 'unauthorized', 'api key', 'chave de api', 'desculpe', 'sorry',
      'não foi possível', 'nao foi possivel', 'failed', 'timeout', 'offline',
      'indisponível', 'indisponivel', 'tente novamente', 'try again',
      'limite de requisições', 'limite de requisicoes', 'aguarde alguns segundos',
    ];
    final isError = errorKeywords.any((kw) => lower.contains(kw));

    if (isError) {
      return '> [!WARNING] Aviso do Serviço de IA\n> $text';
    }

    if (text.isEmpty) {
      return '> [!WARNING] Nenhuma fórmula matemática foi detectada nesta imagem.';
    }

    // Se for uma fórmula crua isolada (sem nenhum delimitador $ ou $$ e sem texto de enunciado), encapsula em bloco $$
    final hasDelimiters = text.contains(r'$');
    if (!hasDelimiters) {
      final textWithoutLatex = text.replaceAll(RegExp(r'\\[a-zA-Z]+'), '').replaceAll(RegExp(r'\{[^\}]*\}'), '');
      final hasNaturalWords = RegExp(r'\b[a-zA-ZÀ-ÿ]{3,}\b').hasMatch(textWithoutLatex);
      if (!hasNaturalWords) {
        text = '\$\$\n$text\n\$\$';
      }
    }

    // Balanceia automaticamente delimitadores incompletos (\left sem \right, { sem }) para evitar erro de sintaxe
    text = _autoBalanceLatex(text);

    return text;
  }

  /// Garante que todos os blocos de abertura do LaTeX (\left, {, () sejam devidamente fechados
  static String _autoBalanceLatex(String tex) {
    var s = tex;
    // 1. Balanceamento de \left e \right
    final leftCount = RegExp(r'\\left\b').allMatches(s).length;
    final rightCount = RegExp(r'\\right\b').allMatches(s).length;
    if (leftCount > rightCount) {
      for (int i = 0; i < (leftCount - rightCount); i++) {
        s += r'\right.';
      }
    }

    // 2. Balanceamento de chaves { e }
    final openBraces = '{'.allMatches(s).length;
    final closeBraces = '}'.allMatches(s).length;
    if (openBraces > closeBraces) {
      s += '}' * (openBraces - closeBraces);
    }

    // 3. Balanceamento de parênteses ( e )
    final openParens = '('.allMatches(s).length;
    final closeParens = ')'.allMatches(s).length;
    if (openParens > closeParens) {
      s += ')' * (openParens - closeParens);
    }

    return s;
  }

  /// Calcula dinamicamente a largura e altura ótimas para o Card de LaTeX, sob medida exata ao conteúdo
  (double, double) calculateOptimalLatexCardSize(String content) {
    if (content.startsWith('> [!')) {
      return (400.0, 160.0);
    }

    final trimmed = content.trim();
    // Verifica se é estritamente um bloco LaTeX puro ($$...$$)
    final isPureDisplayMath = trimmed.startsWith(r'$$') &&
        trimmed.endsWith(r'$$') &&
        !trimmed.substring(2, trimmed.length - 2).contains(r'$$');

    if (isPureDisplayMath) {
      final inner = trimmed.substring(2, trimmed.length - 2).trim();
      return _calculatePureLatexCardSize(inner);
    }

    return _calculateMixedContentCardSize(trimmed);
  }

  static (String, int) _extractBalancedBraces(String text, int start) {
    if (start >= text.length || text[start] != '{') {
      if (start < text.length && !r'{}\^_$ '.contains(text[start])) {
        return (text[start], start + 1);
      }
      return ('', start);
    }
    int depth = 0;
    for (int i = start; i < text.length; i++) {
      if (text[i] == '{') {
        depth++;
      } else if (text[i] == '}') {
        depth--;
        if (depth == 0) {
          return (text.substring(start + 1, i), i + 1);
        }
      }
    }
    return (text.substring(start + 1), text.length);
  }

  /// Estima com fidelidade geométrica a largura visual (em pixels) de uma expressão KaTeX
  static double estimateLatexVisualWidth(String latex) {
    var s = latex.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$')) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$')) {
      s = s.substring(1, s.length - 1).trim();
    }

    s = s.replaceAll(RegExp(r'\\(?:left|right|quad|qquad|text|mathrm|mathbf|mathcal|displaystyle|textstyle)\b'), '');
    s = s.replaceAll(RegExp(r'\\(?:,|;|!|\s)'), '');

    int i = 0;
    double totalW = 0.0;

    while (i < s.length) {
      // 1. Operadores grandes (\int, \sum, \prod, etc.)
      final opMatch = RegExp(r'^\\(?:iint|iiint|oint|int|sum|prod|coprod|bigcap|bigcup|lim)').firstMatch(s.substring(i));
      if (opMatch != null) {
        final opText = opMatch.group(0)!;
        i += opText.length;
        final opW = (opText.contains('iint') || opText.contains('iiint')) ? 20.0 : 13.0;

        double subW = 0.0;
        double supW = 0.0;

        for (int k = 0; k < 2; k++) {
          if (i < s.length && s[i] == '_') {
            final (subStr, nextIdx) = _extractBalancedBraces(s, i + 1);
            i = nextIdx;
            subW = estimateLatexVisualWidth(subStr) * 0.65;
          } else if (i < s.length && s[i] == '^') {
            final (supStr, nextIdx) = _extractBalancedBraces(s, i + 1);
            i = nextIdx;
            supW = estimateLatexVisualWidth(supStr) * 0.65;
          }
        }

        final limitsW = math.max(subW, supW);
        totalW += opW + limitsW;
        continue;
      }

      // 2. Frações (\frac{num}{den} ou \cfrac)
      final fracMatch = RegExp(r'^\\(?:c)?frac').firstMatch(s.substring(i));
      if (fracMatch != null) {
        i += fracMatch.group(0)!.length;
        final (numStr, nextIdx1) = _extractBalancedBraces(s, i);
        i = nextIdx1;
        final (denStr, nextIdx2) = _extractBalancedBraces(s, i);
        i = nextIdx2;

        final numW = estimateLatexVisualWidth(numStr);
        final denW = estimateLatexVisualWidth(denStr);
        totalW += math.max(numW, denW) + 6.0;
        continue;
      }

      // 3. Raízes (\sqrt[n]{radicand})
      if (s.substring(i).startsWith(r'\sqrt')) {
        i += 5;
        if (i < s.length && s[i] == '[') {
          final closeBracket = s.indexOf(']', i);
          if (closeBracket != -1) i = closeBracket + 1;
        }
        final (radStr, nextIdx) = _extractBalancedBraces(s, i);
        i = nextIdx;
        final radW = estimateLatexVisualWidth(radStr);
        totalW += 11.0 + radW;
        continue;
      }

      // 4. Subscritos / Sobrescritos avulsos
      if (s[i] == '_' || s[i] == '^') {
        final sym = s[i];
        final (expStr, nextIdx) = _extractBalancedBraces(s, i + 1);
        i = nextIdx;
        double otherW = 0.0;
        if (i < s.length && (s[i] == '_' || s[i] == '^') && s[i] != sym) {
          final (otherStr, nextIdx2) = _extractBalancedBraces(s, i + 1);
          i = nextIdx2;
          otherW = estimateLatexVisualWidth(otherStr) * 0.65;
        }
        final expW = estimateLatexVisualWidth(expStr) * 0.65;
        totalW += math.max(expW, otherW);
        continue;
      }

      // 5. Comandos de símbolos e funções
      final cmdMatch = RegExp(r'^\\([a-zA-Z]+)').firstMatch(s.substring(i));
      if (cmdMatch != null) {
        final cmd = cmdMatch.group(1)!;
        i += cmdMatch.group(0)!.length;

        if (['sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'ln', 'log', 'exp', 'det', 'dim', 'lim', 'max', 'min'].contains(cmd)) {
          totalW += cmd.length * 6.5;
        } else if (['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'theta', 'lambda', 'mu', 'pi', 'sigma', 'tau', 'phi', 'omega'].contains(cmd)) {
          totalW += 8.0;
        } else if (['cdot', 'times', 'div', 'pm', 'mp', 'leq', 'geq', 'neq', 'approx', 'equiv', 'to', 'leftarrow', 'rightarrow'].contains(cmd)) {
          totalW += 9.0;
        } else {
          totalW += 7.0;
        }
        continue;
      }

      // 6. Caracteres individuais
      final ch = s[i];
      i++;
      if ('{} '.contains(ch)) {
        continue;
      } else if ('0123456789'.contains(ch)) {
        totalW += 6.5;
      } else if ('+-='.contains(ch)) {
        totalW += 8.5;
      } else if ('()[]'.contains(ch)) {
        totalW += 5.5;
      } else {
        totalW += 7.0; // Letras em itálico x, y, z, d, e...
      }
    }

    return totalW;
  }

  /// Cálculo com calibração visual dos glifos KaTeX para evitar sobra lateral excessiva
  (double, double) _calculatePureLatexCardSize(String latex) {
    var cleanTex = latex
        .replaceAll(RegExp(r'\\begin\{(?:aligned|gathered|matrix|bmatrix|pmatrix|cases)\}'), '')
        .replaceAll(RegExp(r'\\end\{(?:aligned|gathered|matrix|bmatrix|pmatrix|cases)\}'), '');

    final lines = cleanTex
        .split(RegExp(r'\\\\|\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return (240.0, 95.0);
    }

    double maxFormulaWidth = 0.0;
    double totalFormulaHeight = 0.0;

    for (final line in lines) {
      final w = estimateLatexVisualWidth(line);
      if (w > maxFormulaWidth) maxFormulaWidth = w;

      final fracCount = RegExp(r'\\(?:frac|cfrac)').allMatches(line).length;
      final sqrtCount = RegExp(r'\\sqrt').allMatches(line).length;
      final hasBigOp = RegExp(r'\\(?:iint|iiint|oint|int|sum|prod)').hasMatch(line);

      double lineH = 24.0;
      if (fracCount >= 2) {
        lineH = 56.0;
      } else if (fracCount == 1) {
        lineH = 40.0;
      } else if (hasBigOp) {
        lineH = 44.0;
      } else if (sqrtCount > 0) {
        lineH = 30.0;
      }
      totalFormulaHeight += lineH;
    }

    // Header (36px) + padding horizontal total (70px) para acomodar o container interno de vidro
    final cardWidth = (maxFormulaWidth + 70.0).clamp(240.0, 680.0);
    final cardHeight = (36.0 + 16.0 + totalFormulaHeight + 10.0).clamp(95.0, 650.0);

    return (cardWidth, cardHeight);
  }

  (double, double) _calculateMixedContentCardSize(String content) {
    final lines = content.split('\n');
    double maxLineWidth = 0.0;
    double totalEstimatedHeight = 16.0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        totalEstimatedHeight += 10.0;
        continue;
      }

      if (line.startsWith(r'$$') && line.endsWith(r'$$') && line.length > 4) {
        final inner = line.substring(2, line.length - 2).trim();
        final (w, h) = _calculatePureLatexCardSize(inner);
        if (w > maxLineWidth) maxLineWidth = w;
        totalEstimatedHeight += h - 40.0;
      } else {
        totalEstimatedHeight += 22.0;
        var stripped = line.replaceAll(RegExp(r'\\(?:left|right|quad|qquad|text|mathrm|mathbf|mathcal|,|;|!)\b'), '');
        stripped = stripped.replaceAll(RegExp(r'[{}\\_^$]'), '');
        final textW = stripped.length * 7.2 + 52.0;
        if (textW > maxLineWidth) {
          maxLineWidth = textW;
        }
      }
    }

    final calculatedWidth = maxLineWidth.clamp(280.0, 680.0);
    final calculatedHeight = (34.0 + 16.0 + totalEstimatedHeight + 12.0).clamp(100.0, 720.0);

    return (calculatedWidth, calculatedHeight);
  }

  void _finishCardWithLatex(
    NoteDocument note,
    String latexCardId,
    String finalSanitized,
    VoidCallback onCardUpdated,
  ) {
    final currentCard = note.cards.cast<CanvasCardModel?>().firstWhere(
      (c) => c?.id == latexCardId,
      orElse: () => null,
    );
    if (currentCard != null) {
      final (optWidth, optHeight) = calculateOptimalLatexCardSize(finalSanitized);
      final updated = currentCard.copyWith(
        content: finalSanitized.isNotEmpty ? finalSanitized : r'$$\text{Nenhuma fórmula detectada}$$',
        width: optWidth,
        height: optHeight,
        isProcessing: false,
      );
      final idx = note.cards.indexWhere((c) => c.id == latexCardId);
      if (idx != -1) {
        note.cards[idx] = updated;
        onCardUpdated();
      }
    }
    WorkspaceStorageService.instance.scheduleAutoSave(note);
  }

  void _updateCardStream(
    NoteDocument note,
    String latexCardId,
    String currentText,
    VoidCallback onCardUpdated,
  ) {
    final idx = note.cards.indexWhere((c) => c.id == latexCardId);
    if (idx != -1) {
      final currentCard = note.cards[idx];
      note.cards[idx] = currentCard.copyWith(
        content: currentText,
        isProcessing: true,
      );
      onCardUpdated();
    }
  }

  void _finishCardWithError(
    NoteDocument note,
    String latexCardId,
    String errorMessage,
    VoidCallback onCardUpdated,
  ) {
    final currentCard = note.cards.cast<CanvasCardModel?>().firstWhere(
      (c) => c?.id == latexCardId,
      orElse: () => null,
    );
    if (currentCard != null) {
      final updated = currentCard.copyWith(
        content: '> [!WARNING] Erro ao extrair LaTeX\n> $errorMessage',
        isProcessing: false,
      );
      final idx = note.cards.indexWhere((c) => c.id == latexCardId);
      if (idx != -1) {
        note.cards[idx] = updated;
        onCardUpdated();
      }
    }
  }

  /// Ponto de entrada para extrair LaTeX a partir de um Card de Mídia.
  void extractLatexFromCard({
    required CanvasCardModel card,
    required NoteDocument note,
    required AiModelDefinition activeAiModel,
    required AppUndoManager undoManager,
    required VoidCallback onCardCreated,
    required VoidCallback onCardUpdated,
  }) {
    final mediaData = card.mediaData;
    if (mediaData == null || mediaData.isEmpty) return;

    debugPrint('[CanvasMediaOcrService] Modo de extração: IA Multimodal (Nuvem)');

    final targetX = card.x + card.width + 28.0;
    final targetY = card.y;
    final latexCardId = 'card_latex_ocr_${DateTime.now().millisecondsSinceEpoch}';

    final initialCard = CanvasCardModel(
      id: latexCardId,
      cardType: CardType.textLatex,
      title: 'LaTeX Extraído',
      x: targetX,
      y: targetY,
      width: 380.0,
      height: 180.0,
      isProcessing: true,
      content: '',
    );

    undoManager.pushCommand(
      AddCardCommand(initialCard),
      execute: true,
      note: note,
    );
    onCardCreated();

    // Pipeline de OCR via IA Multimodal com pré-processamento anti-token eater
    () async {
      String processedImage = mediaData;
      try {
        Uint8List? rawBytes;
        if (mediaData.startsWith('data:') && mediaData.contains(',')) {
          final b64 = mediaData.split(',').last;
          rawBytes = base64Decode(b64);
        } else {
          final file = File(mediaData);
          if (file.existsSync()) {
            rawBytes = await file.readAsBytes();
          }
        }
        if (rawBytes != null && rawBytes.isNotEmpty) {
          // Pre-processamento especializado para OCR:
          // 1. Auto-crop de bordas brancas.
          // 2. Remocao de marcas d'agua e realce de contraste (tracos pretos em fundo branco puro).
          // 3. Redimensionamento para no maximo 800px (enquadramento em 1 tile de visao: ~258 tokens).
          final preprocessedBytes = await OcrImagePreprocessor.prepareImageForOcr(
            rawBytes,
            maxDimension: 640,
          );
          processedImage = 'data:image/jpeg;base64,${base64Encode(preprocessedBytes)}';
        }
      } catch (compErr) {
        debugPrint('[CanvasMediaOcrService] Aviso: pre-processamento de imagem ignorado: $compErr');
      }

      // Prompt de alta fidelidade para matemática e enunciados STEM
      const ocrSystemPrompt = 'Você é um transcrevedor OCR de alta precisão especializado em matemática e ciências STEM. '
          'Transcreva o conteúdo da imagem com fidelidade absoluta: '
          '1. Texto e enunciado de questões devem ser escritos em Markdown comum, garantindo quebra natural de linha no card. '
          '2. Equações e expressões matemáticas no meio de frases devem usar notação inline: \$...\$. '
          '3. Fórmulas principais, frações compostas e expressões destacadas devem usar blocos KaTeX: \$\$...\$\$. '
          '4. Se a imagem for estritamente uma única fórmula isolada sem texto, use apenas o bloco \$\$...\$\$. '
          '5. NUNCA coloque frases longas ou parágrafos inteiros dentro de \\text{...} em blocos \$\$. '
          '6. Preserve fielmente os sinais matemáticos (+, -, =, parênteses, índices e raízes). '
          '7. Não adicione explicações, comentários ou saudações.';

      const userOcrPrompt = 'Transcreva com máxima precisão matemática o conteúdo desta imagem em Markdown com KaTeX (\$...\$ e \$\$...\$\$).';
      final buffer = StringBuffer();

      // Politica Anti-Token Eater: Seleciona o modelo mais economico e veloz disponivel
      // respeitando o provedor ativo escolhido pelo usuario nas configuracoes.
      AiModelDefinition ocrModel = activeAiModel;
      final available = AiServiceBridge.instance.getAvailableModels(SettingsService.instance.settings);

      switch (activeAiModel.provider) {
        case AiProviderType.gemini:
          // Prioriza gemini-3.5-flash-lite (ultrarrápido, menor TTFT e sem sobrecarga 503)
          final fastGemini = available.cast<AiModelDefinition?>().firstWhere(
            (m) => m?.id == 'gemini-3.5-flash-lite',
            orElse: () => available.cast<AiModelDefinition?>().firstWhere(
              (m) => m?.id == 'gemini-2.5-flash' || m?.id == 'gemini-3.5-flash',
              orElse: () => null,
            ),
          );
          if (fastGemini != null) ocrModel = fastGemini;
          break;

        case AiProviderType.openAi:
          // Forca gpt-4o-mini (custo de fracao de centavo, ultra rapido e anti-token eater)
          final miniOpenAi = available.cast<AiModelDefinition?>().firstWhere(
            (m) => m?.id == 'gpt-4o-mini',
            orElse: () => null,
          );
          if (miniOpenAi != null) ocrModel = miniOpenAi;
          break;

        case AiProviderType.claude:
          // Forca claude-3-5-haiku / claude-3-haiku (o modelo mais enxuto e barato da Anthropic)
          final haikuClaude = available.cast<AiModelDefinition?>().firstWhere(
            (m) => m?.id == 'claude-3-5-haiku' || m?.id == 'claude-3-haiku',
            orElse: () => null,
          );
          if (haikuClaude != null) ocrModel = haikuClaude;
          break;

        case AiProviderType.ollama:
          // Mantem o modelo selecionado pelo usuario
          break;
      }

      debugPrint('[CanvasMediaOcrService] Iniciando OCR com modelo economico: ${ocrModel.id} (${ocrModel.provider})');

      AiServiceBridge.instance.streamPrompt(
        userPrompt: userOcrPrompt,
        model: ocrModel,
        imagesBase64: [processedImage],
        customSystemPrompt: ocrSystemPrompt,
        maxOutputTokens: 384, // Teto compacto: fórmulas matemáticas raramente passam de 150 tokens
      ).listen(
        (chunk) {
          buffer.write(chunk);
          _updateCardStream(note, latexCardId, buffer.toString(), onCardUpdated);
        },
        onDone: () {
          final finalSanitized = sanitizeLatexOcrOutput(buffer.toString());
          _finishCardWithLatex(note, latexCardId, finalSanitized, onCardUpdated);
        },
        onError: (err) {
          _finishCardWithError(note, latexCardId, err.toString(), onCardUpdated);
        },
      );
  }();
}
}

