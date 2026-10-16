import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/pdf_region_crop_helper.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_region_crop_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STEM Crop Tool & Region Snip Tests', () {
    test('PdfRegionCropHelper calculates horizontal-level adjacent card position', () {
      final pos = PdfRegionCropHelper.calculateAdjacentCardPosition(
        cardX: 100.0,
        cardWidth: 500.0,
        cardY: 200.0,
        pageTopOffset: 120.0,
        cropTop: 80.0,
        gap: 32.0,
      );

      // Expected X: 100 + 500 + 32 = 632.0
      // Expected Y: 200 + 120 + 80 = 400.0 (exact horizontal alignment with crop)
      expect(pos.dx, equals(632.0));
      expect(pos.dy, equals(400.0));
    });

    test('PdfRegionCropHelper generates fallback data URL when native pdfium is absent', () async {
      final dataUri = await PdfRegionCropHelper.cropAndRenderRegion(
        page: null,
        cropRect: const Rect.fromLTWH(20, 30, 200, 150),
        displayedPageWidth: 600,
        displayedPageHeight: 800,
        nativePdfWidth: 600,
        nativePdfHeight: 800,
      );

      expect(dataUri, isNotNull);
      expect(dataUri!.startsWith('data:image/png;base64,'), isTrue);
    });

    testWidgets('PdfRegionCropOverlay renders handles and dispatches crop actions', (tester) async {
      Rect? imageCroppedRect;
      Rect? stemCroppedRect;
      Rect? aiCroppedRect;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfRegionCropOverlay(
                pageWidth: 600.0,
                pageHeight: 800.0,
                onCropAsImage: (rect) => imageCroppedRect = rect,
                onCropSendToAi: (rect) => aiCroppedRect = rect,
                onCropAsStemCard: (rect) => stemCroppedRect = rect,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Simulate user clicking and dragging on the PDF to create a crop selection region
      final center = tester.getCenter(find.byType(PdfRegionCropOverlay));
      final gesture = await tester.startGesture(center - const Offset(100, 100));
      await gesture.moveTo(center + const Offset(100, 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify buttons exist after user draws a selection region
      expect(find.text('Imagem'), findsOneWidget);
      expect(find.text('Enviar para IA'), findsOneWidget);
      expect(find.text('Card STEM'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Tap Imagem
      await tester.tap(find.text('Imagem'));
      await tester.pump();
      expect(imageCroppedRect, isNotNull);

      // Tap Enviar para IA
      await tester.tap(find.text('Enviar para IA'));
      await tester.pump();
      expect(aiCroppedRect, isNotNull);

      // Tap Card STEM
      await tester.tap(find.text('Card STEM'));
      await tester.pump();
      expect(stemCroppedRect, isNotNull);

      // Tap Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('PdfCardFloatingPill renders Recortar button and toggles state', (tester) async {
      bool cropToggled = false;

      final card = CanvasCardModel(
        id: 'test_pdf_pill',
        title: 'Documento',
        cardType: CardType.pdf,
        pdfPath: 'sample.pdf',
        x: 0,
        y: 0,
        width: 600,
        height: 800,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onToggleCrop: () => cropToggled = true,
                isCropActive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the crop button by tooltip
      final cropButton = find.byTooltip('Recortar região STEM');
      expect(cropButton, findsOneWidget);

      await tester.tap(cropButton);
      await tester.pump();
      expect(cropToggled, isTrue);
    });

    testWidgets('CanvasCardPdfView mounts PdfRegionCropOverlay when isCropActive is true', (tester) async {
      bool cropCancelled = false;

      final card = CanvasCardModel(
        id: 'test_pdf_view_crop',
        title: 'Documento STEM',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        x: 0,
        y: 0,
        width: 500,
        height: 500,
        originalAspectRatio: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CanvasCardPdfView(
                card: card,
                isSelected: true,
                onUpdateCard: (_) {},
                isCropActive: true,
                onCancelCrop: () => cropCancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // PdfRegionCropOverlay should be mounted in the tree
      expect(find.byType(PdfRegionCropOverlay), findsOneWidget);

      // Draw a selection region so the action buttons appear
      final center = tester.getCenter(find.byType(PdfRegionCropOverlay));
      final gesture = await tester.startGesture(center - const Offset(50, 50));
      await gesture.moveTo(center + const Offset(50, 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Tapping Cancel in the overlay should notify onCancelCrop
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(cropCancelled, isTrue);
    });
  });
}
