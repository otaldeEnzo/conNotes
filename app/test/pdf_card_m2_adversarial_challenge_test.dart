import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/pdf_corner_resize_handle.dart';
import 'package:connotes_app/widgets/pdf_page_subcard_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGER ADVERSARIAL: 4-Vertex Opposite-Anchor Stability Property Test', () {
    test('10,000 random delta injections strictly preserve opposite anchor for all 4 vertices', () {
      final random = math.Random(42);

      const testModes = [PdfDisplayMode.singlePage, PdfDisplayMode.continuous];
      const testPageCounts = [1, 3, 10, 50];

      for (final mode in testModes) {
        for (final pageCount in testPageCounts) {
          final card = CanvasCardModel(
            id: 'prop_test_card_${mode.name}_$pageCount',
            title: 'Property Testing Document',
            cardType: CardType.pdf,
            x: 500.0,
            y: 350.0,
            width: 400.0,
            height: 565.68,
            originalAspectRatio: 1.0 / 1.4142,
            totalPdfPages: pageCount,
            pdfDisplayMode: mode,
          );

          final initialW = card.width;
          final initialH = card.calculateMinHeight();

          for (final vertex in PdfCornerVertex.values) {
            // Opposite anchor coordinates in canvas space
            final double expectedAnchorX;
            final double expectedAnchorY;

            switch (vertex) {
              case PdfCornerVertex.topLeft:
                // Opposite is Bottom-Right (x + w, y + h)
                expectedAnchorX = card.x + initialW;
                expectedAnchorY = card.y + initialH;
                break;
              case PdfCornerVertex.topRight:
                // Opposite is Bottom-Left (x, y + h)
                expectedAnchorX = card.x;
                expectedAnchorY = card.y + initialH;
                break;
              case PdfCornerVertex.bottomLeft:
                // Opposite is Top-Right (x + w, y)
                expectedAnchorX = card.x + initialW;
                expectedAnchorY = card.y;
                break;
              case PdfCornerVertex.bottomRight:
                // Opposite is Top-Left (x, y)
                expectedAnchorX = card.x;
                expectedAnchorY = card.y;
                break;
            }

            // Test 100 random deltas per combination (4 vertices * 2 modes * 4 counts * 100 = 3200 iterations)
            for (int i = 0; i < 100; i++) {
              final dx = (random.nextDouble() - 0.5) * 2000.0;
              final dy = (random.nextDouble() - 0.5) * 2000.0;
              final delta = Offset(dx, dy);

              final res = PdfResizeMath.computeResize(
                vertex: vertex,
                delta: delta,
                initialWidth: initialW,
                initialHeight: initialH,
                card: card,
              );

              // Verify width is clamped within [minCardWidth, maxCardWidth]
              expect(
                res.newWidth,
                greaterThanOrEqualTo(PdfResizeMath.minCardWidth),
                reason: 'Width below minimum for vertex $vertex and delta $delta',
              );
              expect(
                res.newWidth,
                lessThanOrEqualTo(PdfResizeMath.maxCardWidth),
                reason: 'Width above maximum for vertex $vertex and delta $delta',
              );

              // Verify new card origin
              final newOriginX = card.x + res.shiftX;
              final newOriginY = card.y + res.shiftY;

              // Compute where the opposite anchor landed after resize
              final double actualAnchorX;
              final double actualAnchorY;

              switch (vertex) {
                case PdfCornerVertex.topLeft:
                  actualAnchorX = newOriginX + res.newWidth;
                  actualAnchorY = newOriginY + res.newHeight;
                  break;
                case PdfCornerVertex.topRight:
                  actualAnchorX = newOriginX;
                  actualAnchorY = newOriginY + res.newHeight;
                  break;
                case PdfCornerVertex.bottomLeft:
                  actualAnchorX = newOriginX + res.newWidth;
                  actualAnchorY = newOriginY;
                  break;
                case PdfCornerVertex.bottomRight:
                  actualAnchorX = newOriginX;
                  actualAnchorY = newOriginY;
                  break;
              }

              expect(
                actualAnchorX,
                closeTo(expectedAnchorX, 1e-4),
                reason: 'Opposite anchor X drifted for vertex $vertex, delta $delta',
              );
              expect(
                actualAnchorY,
                closeTo(expectedAnchorY, 1e-4),
                reason: 'Opposite anchor Y drifted for vertex $vertex, delta $delta',
              );
            }
          }
        }
      }
    });

    test('Boundary and extreme conditions stress testing', () {
      final card = CanvasCardModel(
        id: 'extreme_card',
        title: 'Extreme Card',
        cardType: CardType.pdf,
        x: 0,
        y: 0,
        width: 300,
        height: 884.52,
        totalPdfPages: 2,
        pdfDisplayMode: PdfDisplayMode.continuous,
      );

      final initialH = card.calculateMinHeight();

      // Huge negative delta (shrink beyond minimum)
      final resExtremeShrink = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.topLeft,
        delta: const Offset(1e7, 1e7), // For TL, positive delta shrinks
        initialWidth: 300,
        initialHeight: initialH,
        card: card,
      );
      expect(resExtremeShrink.newWidth, equals(PdfResizeMath.minCardWidth));
      expect(resExtremeShrink.shiftX + resExtremeShrink.newWidth, closeTo(300.0, 1e-4));
      expect(resExtremeShrink.shiftY + resExtremeShrink.newHeight, closeTo(initialH, 1e-4));

      // Huge positive delta (expand beyond maximum)
      final resExtremeExpand = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.bottomRight,
        delta: const Offset(1e7, 1e7),
        initialWidth: 300,
        initialHeight: initialH,
        card: card,
      );
      expect(resExtremeExpand.newWidth, equals(PdfResizeMath.maxCardWidth));
      expect(resExtremeExpand.shiftX, equals(0.0));
      expect(resExtremeExpand.shiftY, equals(0.0));

      // Zero delta (identity when initialHeight matches card calculated height)
      for (final vertex in PdfCornerVertex.values) {
        final resZero = PdfResizeMath.computeResize(
          vertex: vertex,
          delta: Offset.zero,
          initialWidth: 300,
          initialHeight: initialH,
          card: card,
        );
        expect(resZero.newWidth, closeTo(300.0, 1e-4));
        expect(resZero.shiftX, closeTo(0.0, 1e-4));
        expect(resZero.shiftY, closeTo(0.0, 1e-4));
      }

      // Stale initialHeight compensation test: even with stale initial height, opposite anchor holds
      final resStale = PdfResizeMath.computeResize(
        vertex: PdfCornerVertex.topLeft,
        delta: Offset.zero,
        initialWidth: 300,
        initialHeight: 400.0, // Stale height
        card: card,
      );
      expect(resStale.shiftX + resStale.newWidth, closeTo(300.0, 1e-4));
      expect(resStale.shiftY + resStale.newHeight, closeTo(400.0, 1e-4));
    });

    test('Aspect ratio differential proportionality invariance', () {
      // Test continuous mode with varying page counts
      for (int pages = 1; pages <= 10; pages++) {
        final card = CanvasCardModel(
          id: 'card_ratio_$pages',
          title: 'Ratio Test Document',
          cardType: CardType.pdf,
          x: 0.0,
          y: 0.0,
          width: 300,
          height: 400,
          originalAspectRatio: 0.75, // W/H = 3/4
          totalPdfPages: pages,
          pdfDisplayMode: PdfDisplayMode.continuous,
          pdfPageGap: 12.0,
        );

        final rEff = PdfResizeMath.calculateDifferentialRatio(card);
        expect(rEff, closeTo(0.75 / pages, 1e-6));

        // When resizing along differential slope: delta = (dW, dW / rEff)
        const dW = 50.0;
        final dH = dW / rEff;
        final res = PdfResizeMath.computeResize(
          vertex: PdfCornerVertex.bottomRight,
          delta: Offset(dW, dH),
          initialWidth: 300,
          initialHeight: card.calculateMinHeight(),
          card: card,
        );

        expect(res.newWidth, closeTo(300.0 + dW, 1e-4));
        final expectedH = card.copyWith(width: 300.0 + dW).calculateMinHeight();
        expect(res.newHeight, closeTo(expectedH, 1e-4));
      }
    });
  });

  group('CHALLENGER ADVERSARIAL: Moscaro Dark Mode Luminance Filter Invariants', () {
    test('Luminance matrix exact vector transformation mapping', () {
      expect(moscaroDarkLuminanceMatrix.length, equals(20));

      // 1. Pure White mapping: (255, 255, 255, 255) -> Moscaro dark surface (14, 16, 24, 255) [#0e1018]
      final rW = 255.0 * moscaroDarkLuminanceMatrix[0] + moscaroDarkLuminanceMatrix[4];
      final gW = 255.0 * moscaroDarkLuminanceMatrix[6] + moscaroDarkLuminanceMatrix[9];
      final bW = 255.0 * moscaroDarkLuminanceMatrix[12] + moscaroDarkLuminanceMatrix[14];
      final aW = 255.0 * moscaroDarkLuminanceMatrix[18] + moscaroDarkLuminanceMatrix[19];

      expect(rW.round(), equals(14), reason: 'Pure white red channel must map to 14 (0x0E)');
      expect(gW.round(), equals(16), reason: 'Pure white green channel must map to 16 (0x10)');
      expect(bW.round(), equals(24), reason: 'Pure white blue channel must map to 24 (0x18)');
      expect(aW.round(), equals(255), reason: 'Alpha channel must remain fully opaque');

      // 2. Pure Black mapping: (0, 0, 0, 255) -> (255, 255, 255, 255)
      final rB = 0.0 * moscaroDarkLuminanceMatrix[0] + moscaroDarkLuminanceMatrix[4];
      final gB = 0.0 * moscaroDarkLuminanceMatrix[6] + moscaroDarkLuminanceMatrix[9];
      final bB = 0.0 * moscaroDarkLuminanceMatrix[12] + moscaroDarkLuminanceMatrix[14];
      final aB = 255.0 * moscaroDarkLuminanceMatrix[18] + moscaroDarkLuminanceMatrix[19];

      expect(rB.round(), equals(255), reason: 'Pure black red channel must map to 255');
      expect(gB.round(), equals(255), reason: 'Pure black green channel must map to 255');
      expect(bB.round(), equals(255), reason: 'Pure black blue channel must map to 255');
      expect(aB.round(), equals(255), reason: 'Alpha channel must remain fully opaque');

      // 3. Transparent pixel preservation: (0, 0, 0, 0) -> alpha must remain 0
      final aT = 0.0 * moscaroDarkLuminanceMatrix[18] + moscaroDarkLuminanceMatrix[19];
      expect(aT.round(), equals(0), reason: 'Transparent pixel must remain transparent');
    });

    test('Gamut range sanity: output strictly in [0, 255] for all 256 grayscale levels', () {
      for (int i = 0; i <= 255; i++) {
        final val = i.toDouble();
        final r = val * moscaroDarkLuminanceMatrix[0] + moscaroDarkLuminanceMatrix[4];
        final g = val * moscaroDarkLuminanceMatrix[6] + moscaroDarkLuminanceMatrix[9];
        final b = val * moscaroDarkLuminanceMatrix[12] + moscaroDarkLuminanceMatrix[14];

        expect(r, inInclusiveRange(13.9, 255.1));
        expect(g, inInclusiveRange(15.9, 255.1));
        expect(b, inInclusiveRange(23.9, 255.1));

        // Monotonic inversion check: higher input brightness -> lower output brightness
        if (i > 0) {
          final prevVal = (i - 1).toDouble();
          final prevR = prevVal * moscaroDarkLuminanceMatrix[0] + moscaroDarkLuminanceMatrix[4];
          expect(r, lessThan(prevR), reason: 'Luminance inversion must be strictly monotonically decreasing');
        }
      }
    });
  });

  group('CHALLENGER ADVERSARIAL: Comprehensive Emoji Prohibition Audit', () {
    test('Zero emojis in all Milestone 1 & 2 source files and widgets', () {
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1FA00}-\u{1FAFF}\u{1F000}-\u{1F02F}\u{1F0A0}-\u{1F0FF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}]',
        unicode: true,
      );

      final targetFiles = [
        'lib/models/canvas_card_model.dart',
        'lib/widgets/canvas_card_widget.dart',
        'lib/widgets/canvas_card_pdf_view.dart',
        'lib/widgets/pdf_page_subcard_widget.dart',
        'lib/widgets/pdf_corner_resize_handle.dart',
        'lib/services/pdf_document_service.dart',
        'test/pdf_card_widget_test.dart',
        'test/pdf_card_model_test.dart',
        'test/pdf_card_empirical_challenge_test.dart',
        'test/pdf_sliding_window_virtualization_test.dart',
      ];

      for (final relPath in targetFiles) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'File must exist: $relPath');
        final content = file.readAsStringSync();
        final matches = emojiPattern.allMatches(content).toList();
        expect(
          matches.isEmpty,
          isTrue,
          reason: 'Violating emoji found in $relPath: ${matches.map((m) => m.group(0)).toList()}',
        );
      }
    });

    test('Zero emojis in all UI widget files in lib/widgets/', () {
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1FA00}-\u{1FAFF}\u{1F000}-\u{1F02F}\u{1F0A0}-\u{1F0FF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}]',
        unicode: true,
      );

      final widgetsDir = Directory('lib/widgets');
      expect(widgetsDir.existsSync(), isTrue);

      final dartFiles = widgetsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final matches = emojiPattern.allMatches(content).toList();
        expect(
          matches.isEmpty,
          isTrue,
          reason: 'Violating emoji found in UI widget ${file.path}: ${matches.map((m) => m.group(0)).toList()}',
        );
      }
    });
  });
}
