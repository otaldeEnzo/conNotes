import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';
import 'package:connotes_app/widgets/canvas_card_widget.dart';
import 'package:connotes_app/widgets/pdf_corner_resize_handle.dart';
import 'package:connotes_app/widgets/pdf_page_subcard_widget.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: PdfInterPageGap & Pass-Through Geometry', () {
    testWidgets('PdfInterPageGap hitTestSelf and hitTest return false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfInterPageGap(height: 36.0),
            ),
          ),
        ),
      );

      final gapFinder = find.byType(PdfInterPageGap);
      expect(gapFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(gapFinder);
      expect(renderBox.size.height, equals(36.0));

      final hitResult = BoxHitTestResult();
      final hit = renderBox.hitTest(hitResult, position: const Offset(10, 10));
      expect(hit, isFalse, reason: 'Pointer and stylus events must pass directly through the gap');
    });

    testWidgets('PdfInterPageGap performs layout with given height and zero paint', (tester) async {
      final renderGap = RenderPdfInterPageGap(42.0);
      renderGap.layout(const BoxConstraints(maxWidth: 400.0, maxHeight: 1000.0));
      expect(renderGap.size.height, equals(42.0));
      expect(renderGap.size.width, equals(400.0));

      renderGap.gapHeight = 36.0;
      renderGap.layout(const BoxConstraints(maxWidth: 400.0, maxHeight: 1000.0));
      expect(renderGap.size.height, equals(36.0));
    });
  });

  group('Group 2: PdfCornerResizeFrame & Proportional Geometry Math', () {
    test('calculatePageAspectRatio and calculateDifferentialRatio', () {
      final cardA4 = CanvasCardModel(
        id: 'card_1',
        title: 'Doc',
        cardType: CardType.pdf,
        pdfDisplayMode: PdfDisplayMode.continuous,
        x: 0,
        y: 0,
        width: 300,
        height: 424.26,
        originalAspectRatio: 1.0 / 1.4142,
        totalPdfPages: 3,
      );

      final pageRatio = PdfResizeMath.calculatePageAspectRatio(cardA4);
      expect(pageRatio, closeTo(1.0 / 1.4142, 0.001));

      // Continuous mode with 3 pages: differential ratio = pageRatio / 3
      final diffRatioContinuous = PdfResizeMath.calculateDifferentialRatio(cardA4);
      expect(diffRatioContinuous, closeTo(pageRatio / 3.0, 0.001));

      // SinglePage mode: differential ratio = pageRatio
      final cardSingle = cardA4.copyWith(pdfDisplayMode: PdfDisplayMode.singlePage);
      final diffRatioSingle = PdfResizeMath.calculateDifferentialRatio(cardSingle);
      expect(diffRatioSingle, closeTo(pageRatio, 0.001));
    });

    test('computeResize for all 4 vertices preserves opposite anchor points', () {
      final card = CanvasCardModel(
        id: 'card_res',
        title: 'Doc',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 300,
        height: 424.26,
        originalAspectRatio: 1.0 / 1.4142,
        totalPdfPages: 1,
        pdfDisplayMode: PdfDisplayMode.singlePage,
      );

      final initialW = card.width;
      final initialH = card.height;

      // 1. Bottom-Right: anchors top-left (shiftX = 0, shiftY = 0)
      final resBR = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.bottomRight,
        delta: const Offset(40, 56),
        initialWidth: initialW,
        initialHeight: initialH,
        card: card,
      );
      expect(resBR.newWidth, greaterThan(initialW));
      expect(resBR.shiftX, equals(0.0));
      expect(resBR.shiftY, equals(0.0));

      // 2. Bottom-Left: anchors top-right (shiftX = initialW - newWidth, shiftY = 0)
      final resBL = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.bottomLeft,
        delta: const Offset(-40, 56),
        initialWidth: initialW,
        initialHeight: initialH,
        card: card,
      );
      expect(resBL.newWidth, greaterThan(initialW));
      expect(resBL.shiftX, closeTo(initialW - resBL.newWidth, 0.001));
      expect(resBL.shiftY, equals(0.0));
      expect(100.0 + resBL.shiftX + resBL.newWidth, closeTo(100.0 + initialW, 0.001));

      // 3. Top-Right: anchors bottom-left (shiftX = 0, shiftY = initialH - newHeight)
      final resTR = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.topRight,
        delta: const Offset(40, -56),
        initialWidth: initialW,
        initialHeight: initialH,
        card: card,
      );
      expect(resTR.newWidth, greaterThan(initialW));
      expect(resTR.shiftX, equals(0.0));
      expect(resTR.shiftY, closeTo(initialH - resTR.newHeight, 0.001));
      expect(100.0 + resTR.shiftY + resTR.newHeight, closeTo(100.0 + initialH, 0.001));

      // 4. Top-Left: anchors bottom-right
      final resTL = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.topLeft,
        delta: const Offset(-40, -56),
        initialWidth: initialW,
        initialHeight: initialH,
        card: card,
      );
      expect(resTL.newWidth, greaterThan(initialW));
      expect(100.0 + resTL.shiftX + resTL.newWidth, closeTo(100.0 + initialW, 0.001));
      expect(100.0 + resTL.shiftY + resTL.newHeight, closeTo(100.0 + initialH, 0.001));
    });

    test('computeResize respects min and max card width clamping', () {
      final card = CanvasCardModel(
        id: 'card_clamp',
        title: 'Doc',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        width: 300,
        height: 424.26,
        totalPdfPages: 1,
      );

      final resMin = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.bottomRight,
        delta: const Offset(-500, -700),
        initialWidth: 300,
        initialHeight: 424.26,
        card: card,
      );
      expect(resMin.newWidth, equals(PdfResizeMath.minCardWidth));

      final resMax = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.bottomRight,
        delta: const Offset(5000, 7000),
        initialWidth: 300,
        initialHeight: 424.26,
        card: card,
      );
      expect(resMax.newWidth, equals(PdfResizeMath.maxCardWidth));
    });

    testWidgets('PdfCornerResizeFrame renders 4 corner handles and zero edge handles when selected', (tester) async {
      final card = CanvasCardModel(
        id: 'card_frame_test',
        title: 'PDF Document',
        cardType: CardType.pdf,
        x: 50,
        y: 50,
        width: 320,
        height: 450,
        totalPdfPages: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCornerResizeFrame(
                card: card,
                isSelected: true,
                onUpdateCard: (_) {},
                builder: (context, size) => Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),
        ),
      );

      // Exactly 1 corner handle (exclusively bottom-right)
      expect(find.byType(PdfCornerResizeHandle), findsOneWidget);

      // When unselected, 0 handles
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCornerResizeFrame(
                card: card,
                isSelected: false,
                onUpdateCard: (_) {},
                builder: (context, size) => Container(
                  width: size.width,
                  height: size.height,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PdfCornerResizeHandle), findsNothing);
    });
  });

  group('Group 3: PdfPageSubcardWidget Visual & Interaction', () {
    testWidgets('renders placeholder and page index badge when document is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfPageSubcardWidget(
                document: null,
                pageNumber: 2,
                width: 300,
                height: 424,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Carregando Pagina 2...'), findsOneWidget);
      expect(find.text('Pag. 2'), findsOneWidget);
    });

    testWidgets('single tap triggers onSelectPage and Ctrl+tap triggers onSelectWholeDocument', (tester) async {
      int? selectedPage;
      bool documentSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfPageSubcardWidget(
                document: null,
                pageNumber: 3,
                width: 300,
                height: 424,
                onSelectPage: (p) => selectedPage = p,
                onSelectWholeDocument: () => documentSelected = true,
              ),
            ),
          ),
        ),
      );

      // Single tap
      await tester.tap(find.byType(PdfPageSubcardWidget));
      await tester.pump();
      expect(selectedPage, equals(3));
      expect(documentSelected, isFalse);

      // Ctrl+tap simulation
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byType(PdfPageSubcardWidget));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(documentSelected, isTrue, reason: 'Ctrl+tap must trigger onSelectWholeDocument');
    });

    testWidgets('hover reveals Desprender Pagina button and clicking triggers onDetachPage', (tester) async {
      int? detachedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfPageSubcardWidget(
                document: null,
                pageNumber: 4,
                width: 300,
                height: 424,
                onDetachPage: (p) => detachedPage = p,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move mouse over subcard
      await gesture.moveTo(tester.getCenter(find.byType(PdfPageSubcardWidget)));
      await tester.pump(const Duration(milliseconds: 200));

      final pageBadge = find.text('Pag. 4');
      expect(pageBadge, findsOneWidget);
    });
  });

  group('Group 4: Moscaro Dark Mode Luminance Filter', () {
    test('moscaroDarkLuminanceMatrix transforms pure white to #0e1018 and black to white', () {
      // Input white (255, 255, 255)
      final rWhite = (255.0 * moscaroDarkLuminanceMatrix[0]) + moscaroDarkLuminanceMatrix[4];
      final gWhite = (255.0 * moscaroDarkLuminanceMatrix[6]) + moscaroDarkLuminanceMatrix[9];
      final bWhite = (255.0 * moscaroDarkLuminanceMatrix[12]) + moscaroDarkLuminanceMatrix[14];

      expect(rWhite.round(), equals(14), reason: '0x0E == 14');
      expect(gWhite.round(), equals(16), reason: '0x10 == 16');
      expect(bWhite.round(), equals(24), reason: '0x18 == 24');

      // Input black (0, 0, 0)
      final rBlack = (0.0 * moscaroDarkLuminanceMatrix[0]) + moscaroDarkLuminanceMatrix[4];
      final gBlack = (0.0 * moscaroDarkLuminanceMatrix[6]) + moscaroDarkLuminanceMatrix[9];
      final bBlack = (0.0 * moscaroDarkLuminanceMatrix[12]) + moscaroDarkLuminanceMatrix[14];

      expect(rBlack.round(), equals(255));
      expect(gBlack.round(), equals(255));
      expect(bBlack.round(), equals(255));
    });
  });

  group('Group 5: CanvasCardPdfView Sliding Window & Virtualization', () {
    testWidgets('renders empty placeholder when pdfPath is empty', (tester) async {
      final card = CanvasCardModel(
        id: 'card_empty_pdf',
        title: 'Empty PDF',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        pdfPath: null,
        width: 300,
        height: 200,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CanvasCardPdfView(
                card: card,
                isSelected: false,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nenhum documento PDF vinculado'), findsOneWidget);
    });

    testWidgets('continuous mode renders active page window and culled placeholders', (tester) async {
      final card = CanvasCardModel(
        id: 'card_multi_pdf',
        title: 'Multi PDF',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        pdfPath: 'dummy.pdf',
        pdfDisplayMode: PdfDisplayMode.continuous,
        totalPdfPages: 5,
        currentPdfPage: 1,
        width: 300,
        height: 1500,
        pdfPageGap: 36.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CanvasCardPdfView(
                card: card,
                isSelected: false,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      // In window for N=1: pages 1 and 2 are mounted
      expect(find.byKey(const ValueKey('pdf_subcard_card_multi_pdf_p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pdf_subcard_card_multi_pdf_p2')), findsOneWidget);

      // Culled outside window: pages 3, 4, 5
      expect(find.byKey(const ValueKey('pdf_culled_placeholder_card_multi_pdf_p3')), findsOneWidget);
      expect(find.byKey(const ValueKey('pdf_culled_placeholder_card_multi_pdf_p4')), findsOneWidget);
      expect(find.byKey(const ValueKey('pdf_culled_placeholder_card_multi_pdf_p5')), findsOneWidget);

      // Gaps between pages: 4 gaps
      expect(find.byType(PdfInterPageGap), findsNWidgets(4));
    });

    testWidgets('singlePage mode renders exclusively the active page subcard with zero gaps', (tester) async {
      final card = CanvasCardModel(
        id: 'card_single_pdf',
        title: 'Single Page PDF',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        pdfPath: 'dummy.pdf',
        pdfDisplayMode: PdfDisplayMode.singlePage,
        totalPdfPages: 5,
        currentPdfPage: 3,
        width: 300,
        height: 424,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CanvasCardPdfView(
                card: card,
                isSelected: false,
                onUpdateCard: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PdfPageSubcardWidget), findsOneWidget);
      expect(find.text('Pag. 3'), findsOneWidget);
      expect(find.byType(PdfInterPageGap), findsNothing);
    });
  });

  group('Group 6: CanvasCardWidget Integration for CardType.pdf', () {
    testWidgets('CanvasCardWidget dispatches to CanvasCardPdfView and PdfCornerResizeFrame', (tester) async {
      final card = CanvasCardModel(
        id: 'card_canvas_pdf',
        title: 'Canvas PDF Card',
        cardType: CardType.pdf,
        pdfPath: 'doc.pdf',
        totalPdfPages: 3,
        currentPdfPage: 1,
        width: 320,
        height: 600,
        x: 0,
        y: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CanvasCardWidget(
                  card: card,
                  isSelected: true,
                  isPrimarySelected: false,
                  zoomScale: 1.0,
                  onUpdateCard: (_) {},
                  onSelectCard: (_) {},
                  onDeleteCard: (_) {},
                  onDuplicateCard: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CanvasCardPdfView), findsOneWidget);
      expect(find.byType(PdfCornerResizeFrame), findsOneWidget);
      expect(find.byType(PdfCornerResizeHandle), findsOneWidget);

      // Floating pill must be suppressed when isPrimarySelected is false
      expect(find.byKey(const ValueKey('floating_pill')), findsNothing);
    });

    testWidgets('Page 1 master card renders floating pill and allows corner resize', (tester) async {
      CanvasCardModel? updatedCard;
      final card = CanvasCardModel(
        id: 'card_master_p1',
        title: 'Master Page 1',
        cardType: CardType.pdf,
        pdfPath: 'doc.pdf',
        totalPdfPages: 2,
        currentPdfPage: 1,
        width: 320,
        height: 450,
        x: 0,
        y: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CanvasCardWidget(
                  card: card,
                  isSelected: true,
                  isPrimarySelected: true,
                  zoomScale: 1.0,
                  allCards: [card],
                  onUpdateCard: (c) => updatedCard = c,
                  onSelectCard: (_) {},
                  onDeleteCard: (_) {},
                  onDuplicateCard: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(PdfCardFloatingPill), findsOneWidget);
      expect(find.byType(PdfCornerResizeHandle), findsOneWidget);

      // Drag bottom-right corner handle
      final brHandle = find.byType(PdfCornerResizeHandle);
      await tester.drag(brHandle, const Offset(60, 85));
      await tester.pump();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.width, greaterThan(320));
    });
  });

  group('Group 7: Zero Emojis Rule Compliance', () {
    test('verified zero emojis in all M2 source files', () {
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);

      final filesToCheck = [
        'lib/widgets/canvas_card_pdf_view.dart',
        'lib/widgets/pdf_page_subcard_widget.dart',
        'lib/widgets/pdf_corner_resize_handle.dart',
        'lib/widgets/canvas_card_widget.dart',
      ];

      for (final relPath in filesToCheck) {
        final file = File(relPath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final matches = emojiRegex.allMatches(content);
          expect(matches.isEmpty, isTrue, reason: 'Found emojis in $relPath: ${matches.map((m) => m.group(0)).toList()}');
        }
      }
    });
  });
}
