import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'package:connotes_app/widgets/ink_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasCardModel PDF Serialization & Deserialization', () {
    test('serializacao e desserializacao completa de CardType.pdf em modo continuous', () {
      final card = CanvasCardModel(
        id: 'pdf_card_master',
        cardType: CardType.pdf,
        title: 'Mecanica Quantica e Orbitais',
        x: 120.0,
        y: 240.0,
        width: 600.0,
        height: 850.0,
        pdfPath: 'assets/sample_document.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        currentPdfPage: 2,
        totalPdfPages: 24,
        pdfPageGap: 36.0,
        isPdfLocked: true,
        invertLuminance: true,
        pageAttachedStrokeIds: {
          1: ['stroke_101', 'stroke_102'],
          2: ['stroke_201'],
        },
        excludedPageIndices: [5, 12],
      );

      final map = card.toMap();

      expect(map['cardType'], equals('pdf'));
      expect(map['pdfPath'], equals('assets/sample_document.pdf'));
      expect(map['pdfDisplayMode'], equals('continuous'));
      expect(map['currentPdfPage'], equals(2));
      expect(map['totalPdfPages'], equals(24));
      expect(map['pdfPageGap'], equals(36.0));
      expect(map['isPdfLocked'], isTrue);
      expect(map['invertLuminance'], isTrue);
      expect(map['pageAttachedStrokeIds'], equals({
        '1': ['stroke_101', 'stroke_102'],
        '2': ['stroke_201'],
      }));
      expect(map['excludedPageIndices'], equals([5, 12]));

      final restored = CanvasCardModel.fromMap(map);

      expect(restored.id, equals('pdf_card_master'));
      expect(restored.cardType, equals(CardType.pdf));
      expect(restored.title, equals('Mecanica Quantica e Orbitais'));
      expect(restored.pdfPath, equals('assets/sample_document.pdf'));
      expect(restored.pdfDisplayMode, equals(PdfDisplayMode.continuous));
      expect(restored.currentPdfPage, equals(2));
      expect(restored.totalPdfPages, equals(24));
      expect(restored.pdfPageGap, equals(36.0));
      expect(restored.isPdfLocked, isTrue);
      expect(restored.invertLuminance, isTrue);
      expect(restored.pageAttachedStrokeIds, equals({
        1: ['stroke_101', 'stroke_102'],
        2: ['stroke_201'],
      }));
      expect(restored.excludedPageIndices, equals([5, 12]));
    });

    test('serializacao e desserializacao de CardType.pdf em modo singlePage', () {
      final card = CanvasCardModel(
        id: 'pdf_card_single',
        cardType: CardType.pdf,
        title: 'Pagina Isolada 4',
        x: 750.0,
        y: 240.0,
        width: 600.0,
        height: 780.0,
        pdfPath: 'assets/sample_document.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 4,
        totalPdfPages: 24,
      );

      final map = card.toMap();
      expect(map['pdfDisplayMode'], equals('singlePage'));

      final restored = CanvasCardModel.fromMap(map);
      expect(restored.cardType, equals(CardType.pdf));
      expect(restored.pdfDisplayMode, equals(PdfDisplayMode.singlePage));
      expect(restored.currentPdfPage, equals(4));
    });

    test('serializacao e desserializacao via toJson e fromJson preservam estrutura', () {
      final card = CanvasCardModel(
        id: 'pdf_card_json_test',
        cardType: CardType.pdf,
        x: 10.0,
        y: 20.0,
        pdfPath: 'c:/docs/test.pdf',
        pageAttachedStrokeIds: {
          3: ['stroke_alpha', 'stroke_beta'],
        },
        excludedPageIndices: [1],
      );

      final jsonString = card.toJson();
      final restored = CanvasCardModel.fromJson(jsonString);

      expect(restored.id, equals(card.id));
      expect(restored.cardType, equals(CardType.pdf));
      expect(restored.pdfPath, equals('c:/docs/test.pdf'));
      expect(restored.pageAttachedStrokeIds[3], equals(['stroke_alpha', 'stroke_beta']));
      expect(restored.excludedPageIndices, equals([1]));
    });
  });

  group('Backwards Compatibility & Legacy Note Migration', () {
    test('desserializacao de card legado textLatex sem campos PDF aplica defaults seguros', () {
      final legacyMap = <String, dynamic>{
        'id': 'legacy_card_01',
        'cardType': 'textLatex',
        'title': 'Calculo Vetorial',
        'x': 50.0,
        'y': 60.0,
        'width': 340.0,
        'height': 200.0,
        'content': r'$$\nabla \cdot \mathbf{B} = 0$$',
      };

      final card = CanvasCardModel.fromMap(legacyMap);

      expect(card.id, equals('legacy_card_01'));
      expect(card.cardType, equals(CardType.textLatex));
      expect(card.pdfPath, isNull);
      expect(card.pdfDisplayMode, equals(PdfDisplayMode.continuous));
      expect(card.currentPdfPage, equals(1));
      expect(card.totalPdfPages, equals(1));
      expect(card.pdfPageGap, equals(36.0));
      expect(card.isPdfLocked, isFalse);
      expect(card.pageAttachedStrokeIds, isEmpty);
      expect(card.excludedPageIndices, isEmpty);
    });

    test('desserializacao de card legado media sem campos PDF mantem tipo e defaults', () {
      final legacyMediaMap = <String, dynamic>{
        'id': 'legacy_media_02',
        'cardType': 'media',
        'title': 'Diagrama de Bode',
        'x': 100.0,
        'y': 150.0,
        'width': 400.0,
        'height': 300.0,
        'mediaData': 'data:image/png;base64,iVBORw0KGgo=',
      };

      final card = CanvasCardModel.fromMap(legacyMediaMap);

      expect(card.cardType, equals(CardType.media));
      expect(card.pdfPath, isNull);
      expect(card.isPdfLocked, isFalse);
      expect(card.pageAttachedStrokeIds, isEmpty);
    });

    test('desserializacao de cardType nulo ou desconhecido faz fallback seguro', () {
      final unknownTypeMap = <String, dynamic>{
        'id': 'unknown_card_03',
        'cardType': 'unsupported_future_type',
        'x': 0.0,
        'y': 0.0,
      };

      final card = CanvasCardModel.fromMap(unknownTypeMap);
      expect(card.cardType, equals(CardType.textLatex));
    });
  });

  group('Stroke Mapping & Per-Page Attachment', () {
    test('converte chaves de string para int em pageAttachedStrokeIds', () {
      final mapWithStrKeys = <String, dynamic>{
        'id': 'pdf_stroke_map_test',
        'cardType': 'pdf',
        'x': 0.0,
        'y': 0.0,
        'pageAttachedStrokeIds': <String, dynamic>{
          '1': ['stroke_a', 'stroke_b'],
          '7': ['stroke_c'],
        },
      };

      final card = CanvasCardModel.fromMap(mapWithStrKeys);

      expect(card.pageAttachedStrokeIds.containsKey(1), isTrue);
      expect(card.pageAttachedStrokeIds[1], equals(['stroke_a', 'stroke_b']));
      expect(card.pageAttachedStrokeIds.containsKey(7), isTrue);
      expect(card.pageAttachedStrokeIds[7], equals(['stroke_c']));
      expect(card.pageAttachedStrokeIds.containsKey(2), isFalse);
    });

    test('preserva multiplos strokes por pagina e listas vazias', () {
      final card = CanvasCardModel(
        id: 'pdf_card_multi_strokes',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        pageAttachedStrokeIds: {
          1: ['s1', 's2', 's3'],
          2: [],
          3: ['s4'],
        },
      );

      final map = card.toMap();
      final restored = CanvasCardModel.fromMap(map);

      expect(restored.pageAttachedStrokeIds[1]?.length, equals(3));
      expect(restored.pageAttachedStrokeIds[2], isEmpty);
      expect(restored.pageAttachedStrokeIds[3], equals(['s4']));
    });

    test('lida com pageAttachedStrokeIds malformado sem falhar', () {
      final malformedMap = <String, dynamic>{
        'id': 'pdf_malformed_test',
        'cardType': 'pdf',
        'x': 0.0,
        'y': 0.0,
        'pageAttachedStrokeIds': 'not_a_map_structure',
      };

      final card = CanvasCardModel.fromMap(malformedMap);
      expect(card.pageAttachedStrokeIds, isEmpty);
    });
  });

  group('Excluded Page Tracking & Detachment Simulation', () {
    test('serializa e desserializa excludedPageIndices corretamente', () {
      final card = CanvasCardModel(
        id: 'pdf_card_exclusions',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        totalPdfPages: 10,
        excludedPageIndices: [2, 5, 8],
      );

      final map = card.toMap();
      final restored = CanvasCardModel.fromMap(map);

      expect(restored.excludedPageIndices, equals([2, 5, 8]));
    });

    test('simula destacamento de pagina gerando novo card filho e atualizando card mestre', () {
      final masterCard = CanvasCardModel(
        id: 'master_doc',
        cardType: CardType.pdf,
        title: 'Apostila de Eletromagnetismo',
        x: 100.0,
        y: 100.0,
        width: 600.0,
        height: 800.0,
        pdfPath: 'assets/eletromag.pdf',
        totalPdfPages: 50,
        currentPdfPage: 1,
        pageAttachedStrokeIds: {
          4: ['stroke_eq1', 'stroke_eq2'],
        },
        excludedPageIndices: [],
      );

      // Simula acao do usuario ao destacar a pagina 4
      const detachedPageNum = 4;

      final updatedMaster = masterCard.copyWith(
        excludedPageIndices: [...masterCard.excludedPageIndices, detachedPageNum],
      );

      final detachedChild = CanvasCardModel(
        id: 'detached_doc_page_4',
        cardType: CardType.pdf,
        title: '${masterCard.title} - Pagina 4',
        x: masterCard.x + masterCard.width + 40.0,
        y: masterCard.y,
        width: masterCard.width,
        height: masterCard.height,
        pdfPath: masterCard.pdfPath,
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: detachedPageNum,
        totalPdfPages: 1,
        pageAttachedStrokeIds: {
          1: masterCard.pageAttachedStrokeIds[detachedPageNum] ?? [],
        },
      );

      expect(updatedMaster.excludedPageIndices, contains(4));
      expect(detachedChild.currentPdfPage, equals(4));
      expect(detachedChild.pdfDisplayMode, equals(PdfDisplayMode.singlePage));
      expect(detachedChild.pageAttachedStrokeIds[1], equals(['stroke_eq1', 'stroke_eq2']));
      expect(detachedChild.x, equals(740.0));
    });
  });

  group('calculateMinHeight for PDF Cards', () {
    test('retorna 36.0 quando card PDF esta colapsado', () {
      final card = CanvasCardModel(
        id: 'pdf_collapsed',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        isCollapsed: true,
      );

      expect(card.calculateMinHeight(), equals(36.0));
    });

    test('calcula altura minima para singlePage respeitando aspect ratio ou fallback', () {
      final cardWithRatio = CanvasCardModel(
        id: 'pdf_single_ratio',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        originalAspectRatio: 1.5,
        lockAspectRatio: true,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      // width (300) / aspectRatio (1.5) = 200.0
      expect(cardWithRatio.calculateMinHeight(), equals(200.0));

      final cardWithoutRatio = CanvasCardModel(
        id: 'pdf_single_no_ratio',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 300.0,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      expect(cardWithoutRatio.calculateMinHeight(), greaterThanOrEqualTo(100.0));
    });

    test('calcula altura minima para continuous considerando paginas e espacos de 36px', () {
      final card = CanvasCardModel(
        id: 'pdf_continuous',
        cardType: CardType.pdf,
        x: 0.0,
        y: 0.0,
        width: 400.0,
        originalAspectRatio: 1.0,
        lockAspectRatio: true,
        pdfDisplayMode: PdfDisplayMode.continuous,
        totalPdfPages: 3,
        excludedPageIndices: [1], // 2 paginas ativas
        pdfPageGap: 36.0,
      );

      // 2 paginas ativas * (400 / 1.0 = 400) + (1 gap * 36) = 836.0
      expect(card.calculateMinHeight(), equals(836.0));
    });
  });

  group('CanvasCardModel copyWith PDF Properties', () {
    test('copyWith atualiza propriedades PDF preservando campos inalterados', () {
      final original = CanvasCardModel(
        id: 'copy_test_card',
        cardType: CardType.pdf,
        title: 'Original Title',
        x: 100.0,
        y: 200.0,
        pdfPath: 'docs/a.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        currentPdfPage: 1,
        totalPdfPages: 10,
        isPdfLocked: false,
      );

      final modified = original.copyWith(
        title: 'Updated Title',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 5,
        isPdfLocked: true,
      );

      expect(modified.id, equals('copy_test_card'));
      expect(modified.cardType, equals(CardType.pdf));
      expect(modified.title, equals('Updated Title'));
      expect(modified.x, equals(100.0));
      expect(modified.pdfPath, equals('docs/a.pdf'));
      expect(modified.pdfDisplayMode, equals(PdfDisplayMode.singlePage));
      expect(modified.currentPdfPage, equals(5));
      expect(modified.totalPdfPages, equals(10));
      expect(modified.isPdfLocked, isTrue);
    });

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

  group('PdfDocumentService Architecture & Contracts', () {
    test('instancia singleton e estavel e identica', () {
      final instance1 = PdfDocumentService.instance;
      final instance2 = PdfDocumentService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('initialize e idempotente e relata estado de inicializacao', () async {
      final service = PdfDocumentService.instance;
      await service.initialize();
      expect(service.isInitialized, isTrue);

      // Segunda chamada deve ser idempotente
      await service.initialize();
      expect(service.isInitialized, isTrue);
    });

    test('metodos de descarte limpam cache com seguranca', () {
      final service = PdfDocumentService.instance;
      expect(() => service.disposeDocument('non_existent.pdf'), returnsNormally);
      expect(() => service.disposeAll(), returnsNormally);
      expect(service.cachedDocumentCount, equals(0));
    });
  });

  group('PdfDocumentService Export Filtering & Stroke Isolation (M1 Remediation)', () {
    test('shouldExcludePage exclui apenas paginas especificadas sem descartar pagina seguinte adjacente', () {
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
      final s1 = InkStroke(
        id: 'stroke_page_1',
        toolType: InkToolType.pen,
        color: const Color(0xFF00E1FF),
        strokeWidth: 2.0,
        points: [StrokePoint(point: const Offset(50, 50), pressure: 1.0)],
      );

      final strokesMap = <int, List<InkStroke>>{
        1: [s1],
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
