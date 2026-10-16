import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/settings_service.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/settings_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF AI Granular Settings & Floating Pill Synchronization', () {
    test('AppSettingsState default values and copyWith for PDF AI toggles', () {
      final defaultSettings = AppSettingsState.defaults();

      expect(defaultSettings.enablePdfAiActions, isTrue);
      expect(defaultSettings.enablePdfAiSummarize, isTrue);
      expect(defaultSettings.enablePdfAiExtractLatex, isTrue);
      expect(defaultSettings.enablePdfAiExplainDiagram, isTrue);
      expect(defaultSettings.enablePdfAiFlashcards, isTrue);

      final updated = defaultSettings.copyWith(
        enablePdfAiExtractLatex: false,
        enablePdfAiFlashcards: false,
      );

      expect(updated.enablePdfAiSummarize, isTrue);
      expect(updated.enablePdfAiExtractLatex, isFalse);
      expect(updated.enablePdfAiExplainDiagram, isTrue);
      expect(updated.enablePdfAiFlashcards, isFalse);
    });

    test('AppSettingsState serialization and deserialization preserves all 4 toggles', () {
      const original = AppSettingsState(
        enablePdfAiActions: true,
        enablePdfAiSummarize: false,
        enablePdfAiExtractLatex: true,
        enablePdfAiExplainDiagram: false,
        enablePdfAiFlashcards: true,
      );

      final json = original.toJson();
      expect(json['enablePdfAiSummarize'], isFalse);
      expect(json['enablePdfAiExtractLatex'], isTrue);
      expect(json['enablePdfAiExplainDiagram'], isFalse);
      expect(json['enablePdfAiFlashcards'], isTrue);

      final reconstructed = AppSettingsState.fromJson(json);
      expect(reconstructed.enablePdfAiSummarize, isFalse);
      expect(reconstructed.enablePdfAiExtractLatex, isTrue);
      expect(reconstructed.enablePdfAiExplainDiagram, isFalse);
      expect(reconstructed.enablePdfAiFlashcards, isTrue);
    });

    testWidgets('PdfCardFloatingPill renders only enabled AI subpill action buttons', (tester) async {
      final card = CanvasCardModel(
        id: 'pdf_card_test_1',
        title: 'Documento Teste',
        cardType: CardType.pdf,
        x: 100,
        y: 100,
        width: 600,
        height: 800,
        pdfPath: 'test.pdf',
        totalPdfPages: 5,
        currentPdfPage: 2,
      );

      // 1. Initial configuration: Summarize and Flashcards enabled; Latex and Explain disabled
      SettingsService.instance.updateSettingsInMemory(
        AppSettingsState.defaults().copyWith(
          enableCloudAiFeatures: true,
          enablePdfAiActions: true,
          enablePdfAiSummarize: true,
          enablePdfAiExtractLatex: false,
          enablePdfAiExplainDiagram: false,
          enablePdfAiFlashcards: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                totalPages: 5,
                activePageNumber: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open AI sub-pill by clicking sparkle icon
      final sparkleButton = find.byTooltip('Ações de IA STEM (Resumo, LaTeX, Diagramas)');
      expect(sparkleButton, findsOneWidget);
      await tester.tap(sparkleButton);
      await tester.pumpAndSettle();

      // Sub-pill should show Summarize and Flashcards, but not Extrair LaTeX or Explicar Diagrama
      expect(find.text('Resumir Pág. 2'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Extrair LaTeX'), findsNothing);
      expect(find.text('Explicar Diagrama'), findsNothing);

      // 2. Now dynamically toggle Latex ON and Flashcards OFF
      SettingsService.instance.updateSettingsInMemory(
        SettingsService.instance.currentSettings.copyWith(
          enablePdfAiExtractLatex: true,
          enablePdfAiFlashcards: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resumir Pág. 2'), findsOneWidget);
      expect(find.text('Extrair LaTeX'), findsOneWidget);
      expect(find.text('Flashcards'), findsNothing);
      expect(find.text('Explicar Diagrama'), findsNothing);

      // 3. When all individual toggles are disabled, the sparkle AI action is hidden
      SettingsService.instance.updateSettingsInMemory(
        SettingsService.instance.currentSettings.copyWith(
          enablePdfAiSummarize: false,
          enablePdfAiExtractLatex: false,
          enablePdfAiExplainDiagram: false,
          enablePdfAiFlashcards: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Ações de IA STEM (Resumo, LaTeX, Diagramas)'), findsNothing);
    });
  });
}
