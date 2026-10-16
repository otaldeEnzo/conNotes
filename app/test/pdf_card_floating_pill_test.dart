import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/models/pdf_text_search_models.dart';
import 'package:connotes_app/services/pdf_search_engine.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_page_organizer_modal.dart';
import 'package:connotes_app/widgets/pdf_search_pill_input.dart';
import 'package:connotes_app/widgets/svg_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CanvasCardModel createTestCard({
    PdfDisplayMode displayMode = PdfDisplayMode.continuous,
    bool invertLuminance = false,
    bool isPdfLocked = false,
    int currentPdfPage = 1,
    int totalPdfPages = 18,
    String? pdfPath = 'test.pdf',
  }) {
    return CanvasCardModel(
      id: 'test_pdf_card',
      title: 'Documento STEM',
      cardType: CardType.pdf,
      x: 100.0,
      y: 100.0,
      width: 400.0,
      height: 600.0,
      pdfPath: pdfPath,
      pdfDisplayMode: displayMode,
      currentPdfPage: currentPdfPage,
      totalPdfPages: totalPdfPages,
      invertLuminance: invertLuminance,
      isPdfLocked: isPdfLocked,
    );
  }

  group('Group 1: Floating Pill Layout & Zoom Invariance Math', () {
    test('Constants match Moscaro standard (36px height, 30px radius)', () {
      expect(PdfCardFloatingPill.pillHeight, equals(36.0));
      expect(PdfCardFloatingPill.pillRadius, equals(30.0));
    });

    testWidgets('Renders at exact 36.0px container height with 30px radius', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byWidgetPredicate((widget) {
        return widget is Container && widget.constraints?.maxHeight == 36.0;
      });
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(30.0)));
    });

    testWidgets('Applies exact zoom invariance counter-scaling', (tester) async {
      double scaleAtZoom(double zoom) {
        final safeZoom = (zoom > 0) ? zoom : 1.0;
        return (1.0 / safeZoom).clamp(0.5, 3.0);
      }

      expect(scaleAtZoom(0.5), equals(2.0));
      expect(scaleAtZoom(1.0), equals(1.0));
      expect(scaleAtZoom(2.0), equals(0.5));
      expect(scaleAtZoom(0.1), equals(3.0)); // Clamped to 3.0
      expect(scaleAtZoom(5.0), equals(0.5)); // Clamped to 0.5

      final card = createTestCard();

      // Test with zoomScale = 0.5
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                zoomScale: 0.5,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);

      final transformWidget = tester.widget<Transform>(transformFinder.first);
      expect(transformWidget.alignment, equals(Alignment.bottomCenter));

      final matrix = transformWidget.transform;
      expect(matrix.storage[0], closeTo(2.0, 0.001));
    });

    testWidgets('ZoomNotifier dynamically updates pill scale', (tester) async {
      final card = createTestCard();
      final zoomNotifier = ValueNotifier<double>(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                zoomNotifier: zoomNotifier,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      var transformWidget = tester.widget<Transform>(find.byType(Transform).first);
      expect(transformWidget.transform.storage[0], closeTo(1.0, 0.001));

      zoomNotifier.value = 2.0;
      await tester.pumpAndSettle();

      transformWidget = tester.widget<Transform>(find.byType(Transform).first);
      expect(transformWidget.transform.storage[0], closeTo(0.5, 0.001));
    });
  });

  group('Group 2: Control Buttons Rendering & Callbacks', () {
    testWidgets('Toggling display mode switches between continuous and singlePage via SubPill', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CanvasCardModel? updatedCard;
      final continuousCard = createTestCard(displayMode: PdfDisplayMode.continuous);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: continuousCard,
                onUpdateCard: (c) => updatedCard = c,
              ),
            ),
          ),
        ),
      );

      // In continuous mode, layers icon should be visible
      final layersFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'layers');
      expect(layersFinder, findsOneWidget);

      // Tap layers button to expand sub-pill
      await tester.tap(layersFinder);
      await tester.pumpAndSettle();

      expect(find.text('Página Única'), findsOneWidget);
      await tester.tap(find.text('Página Única'));
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.pdfDisplayMode, equals(PdfDisplayMode.singlePage));
    });

    testWidgets('Tapping contrast button toggles invertLuminance', (tester) async {
      CanvasCardModel? updatedCard;
      final card = createTestCard(invertLuminance: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (c) => updatedCard = c,
              ),
            ),
          ),
        ),
      );

      final contrastFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'contrast');
      expect(contrastFinder, findsOneWidget);

      await tester.tap(contrastFinder);
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.invertLuminance, isTrue);
    });

    testWidgets('Tapping lock button toggles isPdfLocked', (tester) async {
      CanvasCardModel? updatedCard;
      final unlockedCard = createTestCard(isPdfLocked: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: unlockedCard,
                onUpdateCard: (c) => updatedCard = c,
              ),
            ),
          ),
        ),
      );

      final unlockFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'unlock');
      expect(unlockFinder, findsOneWidget);

      await tester.tap(unlockFinder);
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.isPdfLocked, isTrue);
    });

    testWidgets('Page navigation controls < 01 / 18 > display and invoke callbacks', (tester) async {
      int? changedPage;
      final card = createTestCard(
        displayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 2,
        totalPdfPages: 18,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onPageChanged: (p) => changedPage = p,
              ),
            ),
          ),
        ),
      );

      expect(find.text('02 / 18'), findsOneWidget);

      // Prev page button
      final prevFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'chevron_left');
      expect(prevFinder, findsOneWidget);
      await tester.tap(prevFinder);
      await tester.pumpAndSettle();

      expect(changedPage, equals(1));

      // Next page button
      final nextFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'chevron_right');
      expect(nextFinder, findsOneWidget);
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      expect(changedPage, equals(2));
    });

    testWidgets('Double tap on page navigator triggers onOpenPageOrganizer callback', (tester) async {
      bool organizerOpened = false;
      final card = createTestCard(
        displayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 18,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onOpenPageOrganizer: () => organizerOpened = true,
              ),
            ),
          ),
        ),
      );

      final pageTextFinder = find.text('01 / 18');
      expect(pageTextFinder, findsOneWidget);

      // Double tap to open organizer
      await tester.tap(pageTextFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(pageTextFinder);
      await tester.pumpAndSettle();

      expect(organizerOpened, isTrue);
    });

    testWidgets('Single tap on page navigator activates inline jump TextField with pre-selected text', (tester) async {
      int? jumpedPage;
      final card = createTestCard(
        displayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 18,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onPageJump: (p) => jumpedPage = p,
              ),
            ),
          ),
        ),
      );

      final pageTextFinder = find.text('01 / 18');
      expect(pageTextFinder, findsOneWidget);

      // Single tap enters inline editing (wait for double tap timeout to disambiguate)
      await tester.tap(pageTextFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // TextField should now be present
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, equals('1'));
      expect(textField.controller?.selection.baseOffset, equals(0));
      expect(textField.controller?.selection.extentOffset, equals(1));

      expect(PdfCardFloatingPill.isEditingAnyPageInline, isTrue);

      // Enter a new page and submit
      await tester.enterText(textFieldFinder, '5');
      tester.widget<TextField>(textFieldFinder).onSubmitted?.call('5');
      await tester.pumpAndSettle();

      expect(jumpedPage, equals(5));
      expect(PdfCardFloatingPill.isEditingAnyPageInline, isFalse);
    });

    testWidgets('Tapping outside inline page editor dismisses it', (tester) async {
      final card = createTestCard(
        displayMode: PdfDisplayMode.singlePage,
        currentPdfPage: 1,
        totalPdfPages: 18,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      final pageTextFinder = find.text('01 / 18');
      await tester.tap(pageTextFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(PdfCardFloatingPill.isEditingAnyPageInline, isTrue);

      // Tap outside the pill on the Scaffold
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(PdfCardFloatingPill.isEditingAnyPageInline, isFalse);
    });

    testWidgets('PdfPageOrganizerModal rotates clockwise on left click and counter-clockwise on right click', (tester) async {
      CanvasCardModel? updatedCard;
      final card = createTestCard(
        currentPdfPage: 1,
        totalPdfPages: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfPageOrganizerModal(
              card: card,
              onUpdateCard: (c) => updatedCard = c,
            ),
          ),
        ),
      );

      // Find rotation button for Page 1
      final rotateFinder = find.byTooltip('Botão esquerdo: Girar 90° horário | Botão direito: Girar 90° anti-horário').first;
      expect(rotateFinder, findsOneWidget);

      // 1. Left-click -> clockwise 90°
      await tester.tap(rotateFinder);
      await tester.pumpAndSettle();

      expect(find.text('90°'), findsOneWidget);

      // 2. Right-click (secondary tap) -> counter-clockwise 90° (back to 0°)
      await tester.tap(rotateFinder, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('90°'), findsNothing);

      // 3. Right-click again -> 270°
      await tester.tap(rotateFinder, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('270°'), findsOneWidget);

      // Click "Aplicar Alterações" to save
      final applyButton = find.text('Aplicar Alterações');
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.pageRotations[1], equals(3)); // 3 * 90° = 270°
    });

    testWidgets('Export button invokes export callback', (tester) async {
      bool exportTriggered = false;
      final card = createTestCard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onExportAnnotatedPdf: () => exportTriggered = true,
              ),
            ),
          ),
        ),
      );

      final downloadFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'download');
      expect(downloadFinder, findsOneWidget);

      await tester.tap(downloadFinder);
      await tester.pumpAndSettle();

      expect(exportTriggered, isTrue);
    });

    testWidgets('STEM AI popover opens on sparkle tap with actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool summarizeCalled = false;
      bool latexCalled = false;
      bool diagramCalled = false;

      final card = createTestCard(currentPdfPage: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onSolveWithAi: () => summarizeCalled = true,
                onExtractLatex: () => latexCalled = true,
                onExplainDiagram: () => diagramCalled = true,
              ),
            ),
          ),
        ),
      );

      final sparkleFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'sparkle');
      expect(sparkleFinder, findsOneWidget);

      // Initially popover is closed
      expect(find.text('Resumir Pág. 3'), findsNothing);

      // Tap sparkle to open popover
      await tester.tap(sparkleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Resumir Pág. 3'), findsOneWidget);
      expect(find.text('Extrair LaTeX'), findsOneWidget);
      expect(find.text('Explicar Diagrama'), findsOneWidget);

      // Tap summarize action
      await tester.tap(find.text('Resumir Pág. 3'));
      await tester.pumpAndSettle();

      expect(summarizeCalled, isTrue);

      // Re-open popover and tap LaTeX action
      await tester.tap(sparkleFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extrair LaTeX'));
      await tester.pumpAndSettle();

      expect(latexCalled, isTrue);

      // Re-open popover and tap Diagram action
      await tester.tap(sparkleFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explicar Diagrama'));
      await tester.pumpAndSettle();

      expect(diagramCalled, isTrue);
    });
  });

  group('Group 3: Search Input Expansion & Shortcuts', () {
    testWidgets('Search input expands on search icon click and collapses on Esc', (tester) async {
      final card = createTestCard();
      final engine = PdfSearchEngine();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                searchEngine: engine,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      // Search button is collapsed initially
      expect(find.byType(TextField), findsNothing);

      // Click search button in pill
      final searchIconFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search');
      expect(searchIconFinder, findsOneWidget);

      await tester.tap(searchIconFinder);
      await tester.pumpAndSettle();

      // TextField should now be expanded
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar no PDF...'), findsOneWidget);

      // Press Escape to collapse
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      engine.dispose();
    });

    testWidgets('Ctrl + F expands search input when card is selected', (tester) async {
      final card = createTestCard();
      final engine = PdfSearchEngine();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                searchEngine: engine,
                isCardSelected: true,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);

      // Send Ctrl+F
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      engine.dispose();
    });
  });

  group('Group 4: Search Match Indicator & Match Navigation', () {
    testWidgets('Displays [ 3 / 14 ] and cycles matches with next/prev buttons', (tester) async {
      final engine = PdfSearchEngine();

      final matches = List.generate(
        14,
        (i) => PdfTextMatch(
          pageNumber: (i % 3) + 1,
          charStartIndex: i * 20,
          charLength: 4,
          rects: const [Rect.fromLTWH(10, 10, 50, 15)],
          globalIndex: i,
        ),
      );

      // Set results on engine
      engine.resultsNotifier.value = PdfSearchResult(
        query: 'test',
        matches: matches,
        currentMatchIndex: 2, // 3rd match -> [ 3 / 14 ]
        isSearching: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfSearchPillInput(
                searchEngine: engine,
                pdfPath: 'test.pdf',
                isCardSelected: true,
              ),
            ),
          ),
        ),
      );

      // Expand input
      await tester.tap(find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search'));
      await tester.pumpAndSettle();

      expect(find.text('[ 3 / 14 ]'), findsOneWidget);

      // Test next match button (chevron_down)
      final nextFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'chevron_down');
      expect(nextFinder, findsOneWidget);
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      expect(engine.currentResult.currentMatchIndex, equals(3));
      expect(find.text('[ 4 / 14 ]'), findsOneWidget);

      // Test prev match button (chevron_up)
      final prevFinder = find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'chevron_up');
      expect(prevFinder, findsOneWidget);
      await tester.tap(prevFinder);
      await tester.pumpAndSettle();

      expect(engine.currentResult.currentMatchIndex, equals(2));
      expect(find.text('[ 3 / 14 ]'), findsOneWidget);

      engine.dispose();
    });

    testWidgets('Empty search shows [ 0 / 0 ]', (tester) async {
      final engine = PdfSearchEngine();
      engine.resultsNotifier.value = const PdfSearchResult(
        query: 'none',
        matches: [],
        currentMatchIndex: -1,
        isSearching: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfSearchPillInput(
                searchEngine: engine,
                pdfPath: 'test.pdf',
                isCardSelected: true,
              ),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.byWidgetPredicate((w) => w is SvgIcon && w.name == 'search'));
      await tester.pumpAndSettle();

      expect(find.text('[ 0 / 0 ]'), findsOneWidget);

      engine.dispose();
    });
  });

  group('Group 5: STRICT ZERO EMOJIS Verification', () {
    test('Zero emojis in all Milestone 3 files', () {
      final filesToCheck = [
        'lib/models/pdf_text_search_models.dart',
        'lib/services/pdf_search_engine.dart',
        'lib/widgets/pdf_search_highlight_painter.dart',
        'lib/widgets/pdf_search_pill_input.dart',
        'lib/widgets/pdf_card_floating_pill.dart',
        'lib/widgets/svg_icon.dart',
        'lib/widgets/pdf_page_subcard_widget.dart',
        'lib/widgets/canvas_card_pdf_view.dart',
        'test/pdf_card_floating_pill_test.dart',
      ];

      // Regex matching Unicode emoji ranges
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      for (final relPath in filesToCheck) {
        final file = File(relPath);
        if (!file.existsSync()) {
          // If running from root directory instead of app/
          final fallbackFile = File('app/$relPath');
          if (fallbackFile.existsSync()) {
            final content = fallbackFile.readAsStringSync();
            final matches = emojiRegex.allMatches(content).toList();
            expect(matches, isEmpty, reason: 'Found emojis in app/$relPath: ${matches.map((m) => m.group(0))}');
            continue;
          }
        }
        expect(file.existsSync(), isTrue, reason: 'File should exist: $relPath');
        final content = file.readAsStringSync();
        final matches = emojiRegex.allMatches(content).toList();
        expect(matches, isEmpty, reason: 'Found emojis in $relPath: ${matches.map((m) => m.group(0))}');
      }
    });
  });
}
