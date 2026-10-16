import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/services/stem_card_formatter_service.dart';
import 'package:connotes_app/models/canvas_card_model.dart';

void main() {
  group('StemCardFormatterService Tests', () {
    const service = StemCardFormatterService.instance;

    test('Detects question prefixes and formats smart title', () {
      final res = service.formatSelectedText(
        rawText: 'Questão 14. Um bloco de massa 2 kg desliza sobre uma superfície...',
        pageNumber: 5,
        documentTitle: 'Física Geral I.pdf',
      );

      expect(res.title, equals('Questão 14 (Pág. 5)'));
      expect(res.content, contains('> [!NOTE]'));
      // Origem é delegada exclusivamente ao CardSourceProvenanceBadge para evitar blocos não-clicáveis
      expect(res.content.contains('*Origem:'), isFalse);
      expect(res.width, inInclusiveRange(340.0, 520.0));
      expect(res.height, inInclusiveRange(150.0, 360.0));
    });

    test('Detects numbered list items and generates clean title', () {
      final res = service.formatSelectedText(
        rawText: '12) Calcule a integral definida de zero a infinito.',
        pageNumber: 3,
      );

      expect(res.title, equals('Questão 12 • Calcule (Pág. 3)'));
      expect(res.content, contains('> [!NOTE]'));
      expect(res.content.contains('*Origem:'), isFalse);
    });

    test('Detects pure mathematical formulas and wraps in KaTeX block', () {
      final res = service.formatSelectedText(
        rawText: r'f(x) = \int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}',
        pageNumber: 12,
        documentTitle: 'Cálculo II',
      );

      expect(res.title, contains('Fórmula'));
      expect(res.content, contains(r'> $$\begin{aligned}'));
      expect(res.content, contains(r'> \end{aligned}$$'));
      expect(res.content.contains('*Origem:'), isFalse);
    });

    test('Calculates compact dynamic dimensions for short selections', () {
      final resShort = service.formatSelectedText(
        rawText: 'Lei de Coulomb: F = k * (q1 * q2) / r²',
        pageNumber: 8,
      );

      expect(resShort.width, inInclusiveRange(340.0, 380.0));
      expect(resShort.height, inInclusiveRange(150.0, 200.0));
    });

    test('Calculates proportional dimensions for paragraphs without scroll', () {
      const longText =
          'A primeira lei da termodinâmica estabelece que a variação da energia interna de um sistema '
          'é igual à diferença entre o calor trocado com o meio e o trabalho realizado. Em transformações '
          'isobáricas, a pressão é mantida constante durante toda a expansão ou compressão gasosa.';

      final resLong = service.formatSelectedText(
        rawText: longText,
        pageNumber: 22,
      );

      expect(resLong.width, inInclusiveRange(420.0, 520.0));
      expect(resLong.height, inInclusiveRange(220.0, 420.0));
      expect(resLong.content, contains('> [!NOTE]'));
      expect(resLong.content.contains('*Origem:'), isFalse);
    });

    test('CanvasCardModel.calculateMinHeight reserves 44px when sourcePageNumber is set', () {
      final cardWithoutSource = CanvasCardModel(
        id: 'test_card_1',
        x: 0,
        y: 0,
        content: '> [!NOTE]\n> Texto de teste',
      );
      final hWithout = cardWithoutSource.calculateMinHeight();

      final cardWithSource = cardWithoutSource.copyWith(
        sourcePageNumber: 20,
        sourceMasterCardId: 'master_pdf_1',
      );
      final hWith = cardWithSource.calculateMinHeight();

      expect(hWith - hWithout, equals(44.0));
    });

    test('CanvasCardModel.calculateEditingMinHeight expands accurately for multi-block card', () {
      final multiBlockCard = CanvasCardModel(
        id: 'multi_block_1',
        x: 0,
        y: 0,
        width: 460.0,
        content: '> [!NOTE]\n> Bloco 1: Callout importante\n---\n'
            r'$$\Delta U = Q - W$$'
            '\n---\nBloco 3: Texto explicativo',
      );
      final normalHeight = multiBlockCard.calculateMinHeight();

      // Editando Bloco 1 (Fórmula) com texto bruto extenso de 6 linhas
      const rawLongLatex = r'$$\begin{aligned}' '\n'
          r'f(x) &= a x^2 + b x + c \\' '\n'
          r'g(x) &= \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \\' '\n'
          r'h(x) &= \int_0^1 f(x) dx' '\n'
          r'\end{aligned}$$';

      final editingHeight = multiBlockCard.calculateEditingMinHeight(
        editingBlockIndex: 1,
        activeEditingText: rawLongLatex,
      );

      // Deve expandir para acomodar o editor sem scrollbars
      expect(editingHeight, greaterThan(normalHeight));
      expect(editingHeight - normalHeight, inInclusiveRange(40.0, 180.0));
    });
  });
}
