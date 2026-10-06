import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_delete_confirm_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Family Actions Synchronization Tests', () {
    testWidgets('Toggling invertLuminance synchronizes across all PDF family pages', (tester) async {
      final updatedCards = <String, CanvasCardModel>{};

      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 2,
        invertLuminance: false,
        x: 0.0,
        y: 0.0,
        sourceMasterCardId: null,
      );

      final page2 = CanvasCardModel(
        id: 'doc_p2',
        title: 'Doc (Pag. 2)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 2,
        invertLuminance: false,
        x: 0.0,
        y: 500.0,
        sourceMasterCardId: 'doc_p1',
      );

      final allCards = <CanvasCardModel>[page1, page2];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: page1,
              allCards: allCards,
              onUpdateCard: (c) => updatedCards[c.id] = c,
            ),
          ),
        ),
      );

      // Find contrast/luminance toggle button
      final contrastButton = find.byWidgetPredicate((widget) {
        return widget is Tooltip && (widget.message?.contains('Inverter cores') == true);
      });

      expect(contrastButton, findsOneWidget);
      await tester.tap(contrastButton);
      await tester.pump();

      // Both page 1 and page 2 must be updated to invertLuminance = true
      expect(updatedCards.containsKey('doc_p1'), isTrue);
      expect(updatedCards.containsKey('doc_p2'), isTrue);
      expect(updatedCards['doc_p1']!.invertLuminance, isTrue);
      expect(updatedCards['doc_p2']!.invertLuminance, isTrue);
    });

    testWidgets('Toggling lock synchronizes isPdfLocked across all PDF family pages', (tester) async {
      final updatedCards = <String, CanvasCardModel>{};

      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 2,
        isPdfLocked: false,
        x: 0.0,
        y: 0.0,
        sourceMasterCardId: null,
      );

      final page2 = CanvasCardModel(
        id: 'doc_p2',
        title: 'Doc (Pag. 2)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 2,
        isPdfLocked: false,
        x: 0.0,
        y: 500.0,
        sourceMasterCardId: 'doc_p1',
      );

      final allCards = <CanvasCardModel>[page1, page2];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: page2,
              allCards: allCards,
              onUpdateCard: (c) => updatedCards[c.id] = c,
            ),
          ),
        ),
      );

      // Find lock toggle button
      final lockButton = find.byWidgetPredicate((widget) {
        return widget is Tooltip && (widget.message?.contains('Desbloqueado') == true);
      });

      expect(lockButton, findsOneWidget);
      await tester.tap(lockButton);
      await tester.pump();

      // Both page 1 and page 2 must be updated to isPdfLocked = true
      expect(updatedCards.containsKey('doc_p1'), isTrue);
      expect(updatedCards.containsKey('doc_p2'), isTrue);
      expect(updatedCards['doc_p1']!.isPdfLocked, isTrue);
      expect(updatedCards['doc_p2']!.isPdfLocked, isTrue);
    });

    testWidgets('Multi-page duplication calls onDuplicateMultipleCards with selected subset', (tester) async {
      List<CanvasCardModel>? duplicated;

      final page1 = CanvasCardModel(
        id: 'doc_p1',
        title: 'Doc (Pag. 1)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 3,
        x: 0.0,
        y: 0.0,
        sourceMasterCardId: null,
      );

      final page2 = CanvasCardModel(
        id: 'doc_p2',
        title: 'Doc (Pag. 2)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 3,
        x: 0.0,
        y: 500.0,
        sourceMasterCardId: 'doc_p1',
      );

      final page3 = CanvasCardModel(
        id: 'doc_p3',
        title: 'Doc (Pag. 3)',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 3,
        totalPdfPages: 3,
        x: 0.0,
        y: 1000.0,
        sourceMasterCardId: 'doc_p1',
      );

      final allCards = <CanvasCardModel>[page1, page2, page3];
      final selectedIds = {'doc_p1', 'doc_p2'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCardFloatingPill(
              card: page1,
              allCards: allCards,
              selectedPageIds: selectedIds,
              onUpdateCard: (_) {},
              onDuplicateMultipleCards: (cards) => duplicated = cards,
            ),
          ),
        ),
      );

      // Tooltip should mention 2 selected pages
      final dupButton = find.byWidgetPredicate((widget) {
        return widget is Tooltip && (widget.message?.contains('Duplicar páginas selecionadas (2)') == true);
      });

      expect(dupButton, findsOneWidget);
      await tester.tap(dupButton);
      await tester.pump();

      expect(duplicated, isNotNull);
      expect(duplicated!.length, equals(2));
      expect(duplicated!.map((c) => c.id), containsAll(['doc_p1', 'doc_p2']));
    });

    testWidgets('PdfDeleteConfirmDialog renders options and returns user selection', (tester) async {
      PdfDeleteChoice? selectedChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedChoice = await PdfDeleteConfirmDialog.show(
                    ctx,
                    pageNumber: 1,
                    totalPages: 5,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog is visible
      expect(find.text('Excluir Página Master (Pág. 1)'), findsOneWidget);
      expect(find.text('Excluir Documento Inteiro (5 páginas)'), findsOneWidget);
      expect(find.text('Apenas esta Página'), findsOneWidget);

      // Select 'Apenas esta Página'
      await tester.tap(find.text('Apenas esta Página'));
      await tester.pumpAndSettle();

      expect(selectedChoice, equals(PdfDeleteChoice.deleteCurrentPageOnly));
    });
  });
}
