import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'package:connotes_app/widgets/ink_models.dart';

/// Test additions for Milestone 1 Iteration 2:
/// 1. Defensive cloning in CanvasCardModel.copyWith
/// 2. Single-page exclusion in exportAnnotatedPdf (via PdfDocumentService.shouldExcludePage)
/// 3. Zero stroke bleed in exportAnnotatedPdf (via PdfDocumentService.getStrokesForPage)

void registerM1It2TestAdditions() {
  group('CanvasCardModel copyWith Defensive Cloning & State Isolation', () {
    test('copyWith realiza deep clone defensivo de pageAttachedStrokeIds e excludedPageIndices', () {
      final original = CanvasCardModel(
        id: 'pdf_clone_isolation_test',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        pageAttachedStrokeIds: {
          1: ['stroke_alpha', 'stroke_beta'],
        },
        excludedPageIndices: [2],
      );

      // Scenario 1: copyWith herdando colecoes existentes
      final copy1 = original.copyWith(title: 'Copy 1');
      expect(identical(copy1.pageAttachedStrokeIds, original.pageAttachedStrokeIds), isFalse);
      expect(identical(copy1.pageAttachedStrokeIds[1], original.pageAttachedStrokeIds[1]), isFalse);
      expect(identical(copy1.excludedPageIndices, original.excludedPageIndices), isFalse);

      copy1.pageAttachedStrokeIds[1]!.add('stroke_gamma');
      copy1.pageAttachedStrokeIds[3] = ['stroke_delta'];
      copy1.excludedPageIndices.add(3);

      expect(original.pageAttachedStrokeIds[1], equals(['stroke_alpha', 'stroke_beta']),
          reason: 'Mutacao na lista interna do clone nao deve contaminar o original');
      expect(original.pageAttachedStrokeIds.containsKey(3), isFalse,
          reason: 'Nova pagina adicionada ao clone nao deve aparecer no original');
      expect(original.excludedPageIndices, equals([2]),
          reason: 'Adicao de exclusao no clone nao deve afetar o original');
      expect(copy1.pageAttachedStrokeIds[1], equals(['stroke_alpha', 'stroke_beta', 'stroke_gamma']));
      expect(copy1.pageAttachedStrokeIds[3], equals(['stroke_delta']));
      expect(copy1.excludedPageIndices, equals([2, 3]));

      // Scenario 2: copyWith recebendo colecoes externas explicitas
      final externalMap = <int, List<String>>{
        5: ['stroke_external'],
      };
      final externalExcluded = <int>[7];

      final copy2 = original.copyWith(
        pageAttachedStrokeIds: externalMap,
        excludedPageIndices: externalExcluded,
      );

      expect(identical(copy2.pageAttachedStrokeIds, externalMap), isFalse);
      expect(identical(copy2.pageAttachedStrokeIds[5], externalMap[5]), isFalse);
      expect(identical(copy2.excludedPageIndices, externalExcluded), isFalse);

      externalMap[5]!.add('stroke_external_mutation');
      externalMap[6] = ['stroke_6'];
      externalExcluded.add(8);

      expect(copy2.pageAttachedStrokeIds[5], equals(['stroke_external']));
      expect(copy2.pageAttachedStrokeIds.containsKey(6), isFalse);
      expect(copy2.excludedPageIndices, equals([7]));
    });
  });

  group('PdfDocumentService Export Filtering & Stroke Isolation (M1 Remediation)', () {
    test('shouldExcludePage exclui apenas paginas especificadas sem descartar pagina seguinte adjacente', () {
      // Prova de eliminacao do bug de dual-index (contains(pageNum) || contains(pageNum - 1))
      final exclusions = [2, 5];

      expect(PdfDocumentService.shouldExcludePage(1, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(2, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(3, exclusions), isFalse,
          reason: 'Pagina 3 nao deve ser excluida quando apenas a pagina 2 foi solicitada');
      expect(PdfDocumentService.shouldExcludePage(4, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(5, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(6, exclusions), isFalse,
          reason: 'Pagina 6 nao deve ser excluida quando a pagina 5 foi solicitada');
    });

    test('shouldExcludePage lida com exclusao da pagina 1 sem descartar pagina 2', () {
      final exclusions = [1];
      expect(PdfDocumentService.shouldExcludePage(1, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(2, exclusions), isFalse,
          reason: 'Pagina 2 deve permanecer intacta quando apenas a pagina 1 e excluida');
      expect(PdfDocumentService.shouldExcludePage(3, exclusions), isFalse);
    });

    test('getStrokesForPage retorna strokes estritamente para a pagina sem vazar para paginas seguintes', () {
      // Prova de eliminacao do bug de fallback (strokesPerPage[pageNum] ?? strokesPerPage[pageNum - 1])
      final s1 = InkStroke(
        id: 'stroke_page_1',
        toolType: InkToolType.pen,
        color: const Color(0xFF00E1FF),
        strokeWidth: 2.0,
        points: [StrokePoint(point: const Offset(50, 50), pressure: 1.0)],
      );

      final strokesMap = <int, List<InkStroke>>{
        1: [s1],
        // Pagina 2 nao possui anotacoes
      };

      final page1Strokes = PdfDocumentService.getStrokesForPage(1, strokesMap);
      final page2Strokes = PdfDocumentService.getStrokesForPage(2, strokesMap);
      final page3Strokes = PdfDocumentService.getStrokesForPage(3, strokesMap);

      expect(page1Strokes, equals([s1]));
      expect(page2Strokes, isEmpty,
          reason: 'Pagina 2 nao deve herdar strokes da Pagina 1 quando nao anotada');
      expect(page3Strokes, isEmpty);
    });

    test('getStrokesForPage lida com mapas vazios e paginas inexistentes sem excecoes', () {
      expect(PdfDocumentService.getStrokesForPage(1, {}), isEmpty);
      expect(PdfDocumentService.getStrokesForPage(999, {}), isEmpty);
    });
  });
}
