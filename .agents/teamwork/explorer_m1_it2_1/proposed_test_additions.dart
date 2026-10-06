import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/services/pdf_document_service.dart';
import 'package:connotes_app/widgets/ink_models.dart';

void main() {
  group('PdfDocumentService Export Filtering & Stroke Isolation (M1 Remediation)', () {
    test('shouldExcludePage correctly filters 1-based excluded pages without adjacent dropping', () {
      final exclusions = [2, 5];
      expect(PdfDocumentService.shouldExcludePage(1, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(2, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(3, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(4, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(5, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(6, exclusions), isFalse);
    });

    test('shouldExcludePage correctly excludes only page 1 when [1] is excluded', () {
      final exclusions = [1];
      expect(PdfDocumentService.shouldExcludePage(1, exclusions), isTrue);
      expect(PdfDocumentService.shouldExcludePage(2, exclusions), isFalse);
      expect(PdfDocumentService.shouldExcludePage(3, exclusions), isFalse);
    });

    test('getStrokesForPage returns strokes strictly for matching 1-based page without bleed', () {
      final s1 = InkStroke(
        id: 'stroke_p1',
        toolType: InkToolType.pen,
        color: const Color(0xFF00E1FF),
        strokeWidth: 2.0,
        points: [StrokePoint(point: const Offset(10, 10), pressure: 1.0)],
      );
      final strokesMap = <int, List<InkStroke>>{
        1: [s1],
        // Page 2 has no entry
      };

      final page1Strokes = PdfDocumentService.getStrokesForPage(1, strokesMap);
      final page2Strokes = PdfDocumentService.getStrokesForPage(2, strokesMap);
      final page3Strokes = PdfDocumentService.getStrokesForPage(3, strokesMap);

      expect(page1Strokes, equals([s1]));
      expect(page2Strokes, isEmpty);
      expect(page3Strokes, isEmpty);
    });

    test('getStrokesForPage handles empty and missing stroke maps cleanly', () {
      expect(PdfDocumentService.getStrokesForPage(1, {}), isEmpty);
      expect(PdfDocumentService.getStrokesForPage(10, {}), isEmpty);
    });
  });
}
