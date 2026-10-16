import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/pdf_page_organizer_modal.dart';
import 'package:connotes_app/widgets/svg_icon.dart';

void main() {
  group('PdfPageOrganizerModal Tests', () {
    testWidgets('Renders page items and rotates page by 90-degree step', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = CanvasCardModel(
        id: 'pdf_test_card',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        totalPdfPages: 4,
        currentPdfPage: 1,
      );

      CanvasCardModel? updatedCard;

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
      await tester.pumpAndSettle();

      // All 4 pages should be rendered
      expect(find.text('Pág. 1'), findsOneWidget);
      expect(find.text('Pág. 2'), findsOneWidget);
      expect(find.text('Pág. 3'), findsOneWidget);
      expect(find.text('Pág. 4'), findsOneWidget);

      // Rotate Pág. 1
      final rotateButtons = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'rotate-cw',
      );
      expect(rotateButtons, findsNWidgets(4));

      await tester.tap(rotateButtons.first);
      await tester.pumpAndSettle();

      // Should now display '90°' badge on Pág. 1
      expect(find.text('90°'), findsOneWidget);

      // Tap 'Aplicar Alterações'
      await tester.tap(find.text('Aplicar Alterações'));
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.pageRotations[1], equals(1)); // 1 quarter turn = 90 deg
    });

    testWidgets('Toggles page exclusion and reorders pages', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = CanvasCardModel(
        id: 'pdf_test_card',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        totalPdfPages: 3,
        currentPdfPage: 1,
      );

      CanvasCardModel? updatedCard;

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
      await tester.pumpAndSettle();

      // Hide page 2
      final eyeButtons = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'eye-off',
      );
      expect(eyeButtons, findsNWidgets(3));

      // Tap eye-off for page 2 (index 1)
      await tester.tap(eyeButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Oculta'), findsOneWidget);

      // Move page 1 right (index 0 -> 1)
      final moveRightButtons = find.byWidgetPredicate(
        (w) => w is SvgIcon && w.name == 'chevron-right',
      );
      await tester.tap(moveRightButtons.first);
      await tester.pumpAndSettle();

      // Tap 'Aplicar Alterações'
      await tester.tap(find.text('Aplicar Alterações'));
      await tester.pumpAndSettle();

      expect(updatedCard, isNotNull);
      expect(updatedCard!.excludedPageIndices, contains(2));
      expect(updatedCard!.pageOrder.first, equals(2)); // page 2 moved to front, page 1 to second
    });
  });

  group('Zero Emojis Verification', () {
    test('Zero emojis in pdf_page_organizer_modal.dart', () {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      final file = File('lib/widgets/pdf_page_organizer_modal.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(emojiRegex.hasMatch(content), isFalse);
    });
  });
}
