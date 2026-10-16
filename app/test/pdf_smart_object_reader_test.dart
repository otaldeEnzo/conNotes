import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/pdf_internal_object_models.dart';
import 'package:connotes_app/services/pdf_page_spatial_index.dart';
import 'package:connotes_app/widgets/pdf_smart_cursor_overlay.dart';
import 'package:connotes_app/widgets/pdf_object_action_menu.dart';
import 'package:connotes_app/widgets/svg_icon.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePdfPageTextFragment implements PdfPageTextFragment {
  @override
  final int index;
  @override
  final int length;
  @override
  final PdfRect bounds;
  @override
  final List<PdfRect> charRects;

  _FakePdfPageTextFragment({
    required this.index,
    required this.length,
    required this.bounds,
    required this.charRects,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePdfPageText implements PdfPageText {
  @override
  final int pageNumber;
  @override
  final String fullText;
  @override
  final List<PdfPageTextFragment> fragments;

  _FakePdfPageText({
    required this.pageNumber,
    required this.fullText,
    required this.fragments,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PdfSmartCursorOverlay & Object Selection Tests', () {
    testWidgets('Double-click selects detected image object and displays Moscaro action menu', (tester) async {
      final sampleImageObj = PdfInternalObject(
        id: 'img_test_1',
        pageNumber: 1,
        bounds: const Rect.fromLTWH(50, 50, 100, 100),
        type: PdfInternalObjectType.image,
      );

      PdfInternalObject? selected;
      bool spawnCalled = false;
      bool copyCalled = false;
      bool aiCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 700,
                  height: 600,
                  child: PdfSmartCursorOverlay(
                    pageNumber: 1,
                    pageWidth: 700,
                    pageHeight: 600,
                    nativeWidth: 700,
                    nativeHeight: 600,
                    detectedObjects: [sampleImageObj],
                    selectedObject: selected,
                    onObjectSelected: (obj) => setState(() => selected = obj),
                    onSpawnCardForObject: (_) => spawnCalled = true,
                    onCopyObject: (_) => copyCalled = true,
                    onAskAiObject: (_) => aiCalled = true,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single tap should NOT select the object (per deliberate 2-clicks rule)
      await tester.tapAt(const Offset(70, 70));
      await tester.pumpAndSettle();
      expect(find.byType(PdfObjectActionMenu), findsNothing);

      // Double tap (2 cliques) SHOULD select the object
      await tester.tapAt(const Offset(70, 70));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(70, 70));
      await tester.pumpAndSettle();

      // Action menu should now be visible
      expect(find.byType(PdfObjectActionMenu), findsOneWidget);
      expect(find.text('Criar Card de Imagem'), findsOneWidget);
      expect(find.text('Copiar Imagem HD'), findsOneWidget);
      expect(find.text('Enviar para IA'), findsOneWidget);

      // Tap 'Criar Card de Imagem'
      await tester.tap(find.text('Criar Card de Imagem'));
      await tester.pumpAndSettle();
      expect(spawnCalled, isTrue);

      // Tap 'Copiar Imagem HD'
      await tester.tap(find.text('Copiar Imagem HD'));
      await tester.pumpAndSettle();
      expect(copyCalled, isTrue);

      // Tap 'Enviar para IA'
      await tester.tap(find.text('Enviar para IA'));
      await tester.pumpAndSettle();
      expect(aiCalled, isTrue);
    });

    testWidgets('Double-click on text selects word via spatial index', (tester) async {
      const text = 'Formula Quimica';
      final fragments = [
        _FakePdfPageTextFragment(
          index: 0,
          length: 15,
          bounds: const PdfRect(20, 20, 150, 40),
          charRects: List.generate(
            15,
            (i) => PdfRect(20.0 + (i * 8.0), 20.0, 28.0 + (i * 8.0), 40.0),
          ),
        ),
      ];

      final fakePageText = _FakePdfPageText(
        pageNumber: 1,
        fullText: text,
        fragments: fragments,
      );

      final spatialIndex = PdfPageSpatialIndex.fromPageText(
        pageText: fakePageText,
        pageNumber: 1,
        nativeWidth: 200,
        nativeHeight: 200,
      );

      dynamic activeTextSelection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: PdfSmartCursorOverlay(
                    pageNumber: 1,
                    pageWidth: 200,
                    pageHeight: 200,
                    nativeWidth: 200,
                    nativeHeight: 200,
                    spatialIndex: spatialIndex,
                    activeTextSelection: activeTextSelection,
                    onTextSelectionChanged: (sel) => setState(() => activeTextSelection = sel),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double tap on "Formula" (around x=30, y=25)
      await tester.tapAt(const Offset(30, 25));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(30, 25));
      await tester.pumpAndSettle();

      expect(activeTextSelection, isNotNull);
      expect(activeTextSelection.selectedText, equals('Formula'));
    });
  });

  group('Zero Emojis Verification', () {
    test('Ensures zero emojis across all newly implemented components', () {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      final files = [
        'lib/models/pdf_internal_object_models.dart',
        'lib/services/pdf_page_spatial_index.dart',
        'lib/services/pdf_object_detection_service.dart',
        'lib/widgets/pdf_object_action_menu.dart',
        'lib/widgets/pdf_smart_cursor_overlay.dart',
      ];

      for (final relPath in files) {
        final file = File(relPath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          expect(emojiRegex.hasMatch(content), isFalse,
              reason: 'File $relPath must contain zero emojis.');
        }
      }
    });
  });
}
