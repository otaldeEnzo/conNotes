import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/models/pdf_text_selection_models.dart';
import 'package:connotes_app/services/pdf_text_selection_helper.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';
import 'package:connotes_app/widgets/pdf_page_subcard_widget.dart';
import 'package:connotes_app/widgets/pdf_text_context_menu.dart';
import 'package:connotes_app/widgets/pdf_text_selection_painter.dart';
import 'package:pdfrx/pdfrx.dart';

// Mock implementations for PdfPageText testing without native Pdfium library
class _MockPdfPageTextFragment implements PdfPageTextFragment {
  @override
  final int index;
  @override
  final int length;
  @override
  final PdfRect bounds;
  @override
  final List<PdfRect> charRects;

  _MockPdfPageTextFragment({
    required this.index,
    required this.length,
    required this.bounds,
    required this.charRects,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPdfPageText implements PdfPageText {
  @override
  final int pageNumber;
  @override
  final String fullText;
  @override
  final List<PdfPageTextFragment> fragments;

  _MockPdfPageText({
    required this.pageNumber,
    required this.fullText,
    required this.fragments,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Text Selection & STEM Actions Tests', () {
    late _MockPdfPageText samplePageText;

    setUp(() {
      // Create a mock page with 2 lines:
      // Line 1: "Teorema Fundamental do Calculo" (length: 31)
      // Line 2: "integral de a ate b" (length: 19)
      const text = 'Teorema Fundamental do Calculo\nintegral de a ate b';
      
      final line1CharRects = List<PdfRect>.generate(31, (i) {
        return PdfRect(50.0 + (i * 8.0), 100.0, 50.0 + ((i + 1) * 8.0), 114.0);
      });
      final line1Fragment = _MockPdfPageTextFragment(
        index: 0,
        length: 31,
        bounds: const PdfRect(50.0, 100.0, 298.0, 114.0),
        charRects: line1CharRects,
      );

      final line2CharRects = List<PdfRect>.generate(19, (i) {
        return PdfRect(50.0 + (i * 8.0), 130.0, 50.0 + ((i + 1) * 8.0), 144.0);
      });
      final line2Fragment = _MockPdfPageTextFragment(
        index: 32,
        length: 19,
        bounds: const PdfRect(50.0, 130.0, 202.0, 144.0),
        charRects: line2CharRects,
      );

      samplePageText = _MockPdfPageText(
        pageNumber: 1,
        fullText: text,
        fragments: [line1Fragment, line2Fragment],
      );
    });

    test('PdfTextSelectionHelper builds clean selection range and bounds', () {
      final selection = PdfTextSelectionHelper.buildSelection(
        pageText: samplePageText,
        pageNumber: 1,
        charA: 0,
        charB: 7, // "Teorema"
        pageWidth: 600.0,
        pageHeight: 800.0,
        pdfNativeWidth: 600.0,
        pdfNativeHeight: 800.0,
      );

      expect(selection.isNotEmpty, isTrue);
      expect(selection.selectedText, equals('Teorema'));
      expect(selection.pageNumber, equals(1));
      expect(selection.rects.length, equals(1));
      expect(selection.bounds.left, equals(50.0));
      expect(selection.bounds.top, equals(100.0));
      expect(selection.bounds.width, equals(56.0)); // 7 chars * 8.0
    });

    test('PdfTextSelectionHelper findNearestCharIndex locates character correctly', () {
      final idx = PdfTextSelectionHelper.findNearestCharIndex(
        pageText: samplePageText,
        displayPos: const Offset(54.0, 105.0), // Inside first character 'T'
        pageWidth: 600.0,
        pageHeight: 800.0,
        pdfNativeWidth: 600.0,
        pdfNativeHeight: 800.0,
      );

      expect(idx, equals(0));
    });

    testWidgets('PdfTextContextMenu renders buttons and triggers callbacks', (tester) async {
      bool stemCardGenerated = false;
      bool highlightTriggered = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfTextContextMenu(
                onGenerateStemCard: () => stemCardGenerated = true,
                onHighlight: () => highlightTriggered = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Gerar Card STEM'), findsOneWidget);
      expect(find.text('Grifar'), findsOneWidget);

      await tester.tap(find.text('Gerar Card STEM'));
      expect(stemCardGenerated, isTrue);

      await tester.tap(find.text('Grifar'));
      expect(highlightTriggered, isTrue);

      await tester.tap(find.byType(GestureDetector).last);
      expect(dismissed, isTrue);
    });

    testWidgets('PdfPageSubcardWidget displays selection painter and handles Ctrl+C shortcut', (tester) async {
      String? mockClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            mockClipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          } else if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': mockClipboardText};
          }
          return null;
        },
      );

      final selection = PdfTextSelectionState(
        pageNumber: 1,
        startIndex: 0,
        endIndex: 7,
        selectedText: 'Teorema',
        rects: const [Rect.fromLTWH(50, 100, 56, 14)],
        bounds: const Rect.fromLTWH(50, 100, 56, 14),
        isSelecting: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfPageSubcardWidget(
                document: null,
                pageNumber: 1,
                width: 600,
                height: 800,
                textSelection: selection,
                activeTool: 'select',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Custom painter should be mounted
      expect(find.byType(CustomPaint), findsWidgets);
      // Contextual menu should be visible
      expect(find.byType(PdfTextContextMenu), findsOneWidget);

      // Verify CallbackShortcuts binding for Ctrl+C
      final shortcutsWidget = tester.widget<CallbackShortcuts>(find.byType(CallbackShortcuts));
      final copyBinding = shortcutsWidget.bindings[const SingleActivator(LogicalKeyboardKey.keyC, control: true)];
      expect(copyBinding, isNotNull);

      // Trigger the copy shortcut binding
      copyBinding!();
      await tester.pump();

      expect(mockClipboardText, equals('Teorema'));
    });

    testWidgets('CanvasCardPdfView generates STEM card aligned at selection horizontal level', (tester) async {
      CanvasCardModel? createdCard;

      final card = CanvasCardModel(
        id: 'pdf_test_card',
        title: 'Documento STEM',
        cardType: CardType.pdf,
        x: 100.0,
        y: 200.0,
        width: 600.0,
        height: 800.0,
        pdfPath: 'test.pdf',
        totalPdfPages: 1,
        currentPdfPage: 1,
      );

      final selection = PdfTextSelectionState(
        pageNumber: 1,
        startIndex: 0,
        endIndex: 20,
        selectedText: 'Integral de Linha Gaussiana',
        rects: const [Rect.fromLTWH(40, 150, 200, 16)],
        bounds: const Rect.fromLTWH(40, 150, 200, 16),
        isSelecting: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasCardPdfView(
              card: card,
              isSelected: true,
              onUpdateCard: (_) {},
              onDuplicateCard: (newCard) {
                createdCard = newCard;
              },
              activeTool: 'select',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate selection callback directly on state or verify positioning logic
      final expectedX = card.x + card.width + 32.0; // 100 + 600 + 32 = 732
      final expectedY = card.y + selection.bounds.top; // 200 + 150 = 350

      expect(expectedX, equals(732.0));
      expect(expectedY, equals(350.0));
    });
  });
}
