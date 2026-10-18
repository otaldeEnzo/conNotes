import 'dart:math' as math;
import 'pdf_page_spatial_index.dart';

/// Resultado com conteúdo estruturado, título contextual e dimensões auto-ajustadas.
class StemCardFormatResult {
  final String title;
  final String content;
  final double width;
  final double height;

  const StemCardFormatResult({
    required this.title,
    required this.content,
    required this.width,
    required this.height,
  });
}

/// Serviço modular para formatação estética, conversão KaTeX e proveniência
/// de cards gerados a partir de seleções de texto em documentos PDF.
class StemCardFormatterService {
  static const StemCardFormatterService instance = StemCardFormatterService._();
  const StemCardFormatterService._();

  /// Processa e formata a seleção de texto do PDF gerando título inteligente,
  /// bloco callout Moscaro v2, conversão KaTeX e rodapé de proveniência.
  StemCardFormatResult formatSelectedText({
    required String rawText,
    required int pageNumber,
    String? documentTitle,
  }) {
    final cleaned = PdfPageSpatialIndex.cleanStemText(rawText).trim();
    if (cleaned.isEmpty) {
      return StemCardFormatResult(
        title: 'Anotação (Pág. $pageNumber)',
        content: '',
        width: 360.0,
        height: 180.0,
      );
    }

    final isPureFormula = _isPredominantlyFormula(cleaned);
    final title = _generateSmartTitle(cleaned, pageNumber, isPureFormula);
    final content = _buildCalloutContent(
      text: cleaned,
      pageNumber: pageNumber,
      documentTitle: documentTitle,
      isPureFormula: isPureFormula,
    );

    final dimensions = _calculateDynamicDimensions(cleaned, isPureFormula);

    return StemCardFormatResult(
      title: title,
      content: content,
      width: dimensions.width,
      height: dimensions.height,
    );
  }

  /// Gera um título inteligente baseado no conteúdo semântico do texto extraído.
  String _generateSmartTitle(String text, int pageNumber, bool isPureFormula) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. Detecta padrões de enunciados de exercícios / questões / exemplos
    final questionMatch = RegExp(
      r'^(?:Quest[aã]o|Exerc[ií]cio|Exemplo|Problema|Item)\s*(\d+[A-Za-z0-9\.\-]*)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    if (questionMatch != null) {
      final prefix = questionMatch.group(0)!.replaceAll(RegExp(r'[\.\s]+$'), '').trim();
      return '$prefix (Pág. $pageNumber)';
    }

    // 2. Detecta numeração direta de questão (ex: "14. Um corpo de massa...")
    final directNumberMatch = RegExp(r'^(\d+)[\.\)]\s+([A-Za-zÀ-ÿ]{3,})').firstMatch(singleLine);
    if (directNumberMatch != null) {
      final num = directNumberMatch.group(1);
      final word = directNumberMatch.group(2);
      return 'Questão $num • $word (Pág. $pageNumber)';
    }

    // 3. Se for uma fórmula matemática pura
    if (isPureFormula) {
      if (singleLine.contains('=')) {
        final parts = singleLine.split('=');
        final lhs = parts.first.trim();
        if (lhs.length <= 16 && lhs.isNotEmpty) {
          return 'Fórmula: $lhs (Pág. $pageNumber)';
        }
      }
      return 'Fórmula STEM (Pág. $pageNumber)';
    }

    // 4. Texto corrido: extrai as primeiras 4 a 6 palavras significativas
    final words = singleLine.split(' ').where((w) => w.trim().isNotEmpty).toList();
    if (words.isNotEmpty) {
      final takeCount = math.min(words.length, 5);
      final snippet = words.take(takeCount).join(' ');
      final cleanSnippet = snippet.replaceAll(RegExp(r'[\.,:;!?-]+$'), '').trim();
      final display = cleanSnippet.length > 28 ? '${cleanSnippet.substring(0, 28)}...' : cleanSnippet;
      return '$display (Pág. $pageNumber)';
    }

    return 'Trecho Extraído (Pág. $pageNumber)';
  }

  /// Verifica se o texto é predominantemente uma fórmula matemática/química isolada (sem prosa).
  bool _isPredominantlyFormula(String text) {
    final clean = text.trim();
    if (clean.length < 4) return false;

    // Se começa com numeração de questão, exercício ou comandos de enunciado, NUNCA é fórmula pura!
    final isEnunciado = RegExp(
      r'^(?:\d+[\.\)]|Quest[aã]o|Exerc[ií]cio|Exemplo|Problema|Item|Calcule|Determine|Encontre|Mostre|Demonstre|Considere|Seja|Verifique|Avalie|Dada|Dado)',
      caseSensitive: false,
    ).hasMatch(clean);
    if (isEnunciado) return false;

    // Se contém vocabulário comum de problemas/exercícios em português, é um enunciado textual com fórmulas
    final hasPortugueseProse = RegExp(
      r'\b(?:onde|gr[aá]fico|segmento|extremidades|sentido|para|com|sendo|entre|sobre|dado|dados|curva|regi[aã]o|ponto|pontos|reta|plano|vetor|fun[cç][aã]o|campo|massa|for[cç]a|velocidade|tempo|percorrido)\b',
      caseSensitive: false,
    ).hasMatch(clean);
    if (hasPortugueseProse) return false;

    // Contagem de palavras normais em português com mais de 3 letras
    final words = clean.split(RegExp(r'\s+')).where((w) => RegExp(r'^[a-zA-ZÀ-ÿ]{3,}$').hasMatch(w)).toList();
    if (words.length >= 3) return false;

    // Sinais matemáticos fortes para equações puras (sem prosa)
    final hasEquals = clean.contains('=');
    final hasMathSymbols = RegExp(r'[+\-*/^√∫∑∏±≤≥≠≈→∞∂∆∇]').hasMatch(clean);
    final hasLaTeXCommands = RegExp(r'\\[a-zA-Z]+').hasMatch(clean);
    final hasSuperOrSub = RegExp(r'[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎]').hasMatch(clean);

    final letterCount = RegExp(r'[a-zA-ZÀ-ÿ]').allMatches(clean).length;
    final totalLen = clean.replaceAll(RegExp(r'\s+'), '').length;

    if (hasLaTeXCommands || (hasEquals && hasMathSymbols)) {
      if (totalLen > 0 && letterCount / totalLen < 0.45) return true;
    }

    if (hasSuperOrSub && hasEquals && letterCount / (totalLen > 0 ? totalLen : 1) < 0.45) return true;

    return false;
  }

  /// Converte trechos matemáticos de um enunciado para notação LaTeX inline ($...$) perfeitamente renderizável.
  static String _formatStatementWithInlineMath(String text) {
    if (text.isEmpty) return text;

    String formatted = text;

    // 1. Converte integrais soltas com diferenciais em bloco inline math $...$
    // Ex: \int_\gamma 6x^2ydx + xydy -> $\int_\gamma 6x^2y \, dx + xy \, dy$
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\\int(?:_[a-zA-Z0-9\\\{\}]+)?\s*[^,\.;\n]+?d[xytz](?!\$)'),
      (m) {
        var expr = m[0]!;
        expr = expr.replaceAllMapped(RegExp(r'([a-zA-Z0-9_\^])\s*d([xytz])'), (dm) => '${dm[1]} \\, d${dm[2]}');
        return '\$$expr\$';
      },
    );

    // 2. Converte equações com sinal de igual (ex: y = x^3 + 1, E(x,y) = ...)
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\b([a-zA-Z]\w*)\s*=\s*([a-zA-Z0-9\+\-\*\/\^\(\)\s\\_]+?)(?=[,\.;\)]|\s+de\b|\s+a\b|\s+para\b|$)'),
      (m) {
        final fullEq = '${m[1]} = ${m[2]?.trim()}';
        return '\$$fullEq\$';
      },
    );

    // 3. Converte coordenadas numéricas ou vetores pontuais (ex: (-1, 0), (1, 2, 1), (0, 0, 0))
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)(?:\s*,\s*(-?\d+(?:\.\d+)?))?\s*\)(?!\$)'),
      (m) {
        final third = m[3] != null ? ', ${m[3]}' : '';
        return '\$(${m[1]}, ${m[2]}$third)\$';
      },
    );

    // 4. Converte letras gregas isoladas como \gamma, \alpha, \beta, \theta, \lambda em $\gamma$
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\\(gamma|alpha|beta|theta|lambda|pi|sigma|omega|Delta|Omega)\b(?!\$)'),
      (m) => '\$\\${m[1]}\$',
    );

    // 5. Converte vetores como \vec{E}, \vec{i}, \vec{j}, \vec{k}
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\\vec\{[a-zA-Z0-9]+\}(?!\$)'),
      (m) => '\$${m[0]}\$',
    );

    // 6. Limpa eventuais duplicações acidentais de delimitadores de dólar
    formatted = formatted.replaceAllMapped(
      RegExp(r'\${2,}(.*?)\${2,}'),
      (m) => '\$${m[1]}\$',
    );

    return formatted;
  }

  /// Monta o corpo em formato Callout Moscaro v2 com KaTeX e rodapé de proveniência.
  String _buildCalloutContent({
    required String text,
    required int pageNumber,
    String? documentTitle,
    required bool isPureFormula,
  }) {
    final buffer = StringBuffer();

    if (isPureFormula) {
      // Bloco KaTeX puro destacado dentro do callout
      buffer.writeln('> [!THEOREM] FÓRMULA MATEMÁTICA');
      buffer.writeln(r'> $$\begin{aligned}');
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          buffer.writeln('> $trimmed');
        }
      }
      buffer.writeln(r'> \end{aligned}$$');
    } else {
      // Enunciado / Questão com notação inline matemática limpa
      final isQuestion = RegExp(
        r'^(?:\d+[\.\)]|Quest[aã]o|Exerc[ií]cio|Exemplo|Problema|Calcule|Determine|Encontre)',
        caseSensitive: false,
      ).hasMatch(text);

      if (isQuestion) {
        buffer.writeln('> [!NOTE] ENUNCIADO DA QUESTÃO');
      } else {
        buffer.writeln('> [!NOTE] TRECHO DESTACADO');
      }

      final formatted = _formatStatementWithInlineMath(text);
      for (final line in formatted.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          buffer.writeln('> $trimmed');
        }
      }
    }
    return buffer.toString().trimRight();
  }

  /// Calcula dimensões estéticas auto-ajustadas (sem gerar barras de rolagem ou caixas vazias).
  math.Rectangle<double> _calculateDynamicDimensions(String text, bool isPureFormula) {
    final charCount = text.length;
    final lines = text.split('\n');
    final lineCount = math.max(lines.length, (charCount / 55.0).ceil());

    double targetWidth;
    double targetHeight;

    const baseOverhead = 90.0; // Header do card (36) + padding (20) + badge proveniência (44)

    if (isPureFormula) {
      targetWidth = (charCount * 9.0).clamp(360.0, 520.0);
      targetHeight = math.max(160.0, baseOverhead + (lines.length * 30.0));
    } else if (charCount <= 90) {
      // Curto (1 a 2 linhas)
      targetWidth = 360.0;
      targetHeight = 160.0;
    } else if (charCount <= 250) {
      // Médio (3 a 5 linhas)
      targetWidth = 420.0;
      targetHeight = math.max(180.0, baseOverhead + (lineCount * 20.0));
    } else if (charCount <= 500) {
      // Parágrafo padrão
      targetWidth = 460.0;
      targetHeight = math.max(220.0, baseOverhead + (lineCount * 20.0));
    } else {
      // Trecho longo
      targetWidth = 500.0;
      targetHeight = math.max(260.0, baseOverhead + (lineCount * 20.0));
    }

    return math.Rectangle<double>(0, 0, targetWidth, targetHeight);
  }
}
