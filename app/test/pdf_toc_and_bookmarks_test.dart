import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/canvas_card_pdf_view.dart';
import 'package:connotes_app/widgets/pdf_card_floating_pill.dart';
import 'package:connotes_app/widgets/pdf_toc_sidebar_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF STEM Suite - Quick Bookmarks & Table of Contents Tests', () {
    test('CanvasCardModel serializes and deserializes bookmarkedPages', () {
      final card = CanvasCardModel(
        id: 'test_card_bookmarks',
        cardType: CardType.pdf,
        pdfPath: 'sample.pdf',
        x: 100,
        y: 200,
        bookmarkedPages: [2, 5, 12],
      );

      expect(card.bookmarkedPages, equals([2, 5, 12]));

      // copyWith
      final updated = card.copyWith(bookmarkedPages: [2, 5, 12, 19]);
      expect(updated.bookmarkedPages, equals([2, 5, 12, 19]));

      // toMap / fromMap
      final map = updated.toMap();
      expect(map['bookmarkedPages'], equals([2, 5, 12, 19]));

      final restored = CanvasCardModel.fromMap(map);
      expect(restored.bookmarkedPages, equals([2, 5, 12, 19]));
    });

    testWidgets('PdfCardFloatingPill renders Star and TOC buttons and fires callbacks', (tester) async {
      bool bookmarkToggled = false;
      bool tocToggled = false;

      final card = CanvasCardModel(
        id: 'test_pill_toc',
        cardType: CardType.pdf,
        pdfPath: 'test.pdf',
        x: 0,
        y: 0,
        currentPdfPage: 3,
        totalPdfPages: 10,
        bookmarkedPages: [1, 3],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfCardFloatingPill(
                card: card,
                onUpdateCard: (_) {},
                onToggleBookmark: () => bookmarkToggled = true,
                isCurrentPageBookmarked: true,
                onToggleToc: () => tocToggled = true,
                isTocOpen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Bookmark button should have active tooltip
      final bookmarkBtn = find.byTooltip('Remover marcador da página');
      expect(bookmarkBtn, findsOneWidget);

      await tester.tap(bookmarkBtn);
      await tester.pump();
      expect(bookmarkToggled, isTrue);

      // TOC button
      final tocBtn = find.byTooltip('Sumário & Marcadores');
      expect(tocBtn, findsOneWidget);

      await tester.tap(tocBtn);
      await tester.pump();
      expect(tocToggled, isTrue);
    });

    testWidgets('PdfTocSidebarDrawer switches tabs and interacts with bookmarks', (tester) async {
      int? jumpedPage;
      int? toggledPage;
      bool closed = false;

      final card = CanvasCardModel(
        id: 'test_card_drawer',
        cardType: CardType.pdf,
        pdfPath: '',
        x: 0,
        y: 0,
        currentPdfPage: 1,
        totalPdfPages: 20,
        bookmarkedPages: [4, 9],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfTocSidebarDrawer(
                card: card,
                onPageJump: (page) => jumpedPage = page,
                onToggleBookmark: (page) => toggledPage = page,
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header is rendered
      expect(find.text('Sumário & Marcadores'), findsOneWidget);

      // Tab bar shows both tabs
      expect(find.text('Sumário'), findsOneWidget);
      expect(find.text('Marcadores (2)'), findsOneWidget);

      // Switch to Marcadores tab
      await tester.tap(find.text('Marcadores (2)'));
      await tester.pumpAndSettle();

      // Bookmarked pages 4 and 9 are listed
      expect(find.text('Pagina 4'), findsOneWidget);
      expect(find.text('Pagina 9'), findsOneWidget);

      // Tap Pagina 4 to jump
      await tester.tap(find.text('Pagina 4'));
      await tester.pump();
      expect(jumpedPage, equals(4));

      // Remove bookmark button on Pagina 4
      final removeButtons = find.byTooltip('Remover marcador');
      expect(removeButtons, findsNWidgets(2));
      await tester.tap(removeButtons.first);
      await tester.pump();
      expect(toggledPage, equals(4));

      // Close button
      final closeButton = find.byType(InkWell).first;
      await tester.tap(closeButton);
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('PdfTocSidebarDrawer enforces exactHeight matching PDF card height', (tester) async {
      final card = CanvasCardModel(
        id: 'test_exact_height_drawer',
        cardType: CardType.pdf,
        pdfPath: '',
        x: 0,
        y: 0,
        currentPdfPage: 1,
        totalPdfPages: 20,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PdfTocSidebarDrawer(
                card: card,
                exactHeight: 480.0,
                onPageJump: (_) {},
                onToggleBookmark: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final drawerFinder = find.byType(PdfTocSidebarDrawer);
      expect(drawerFinder, findsOneWidget);
      final size = tester.getSize(drawerFinder);
      expect(size.height, equals(480.0));
    });

    testWidgets('CanvasCardPdfView mounts PdfTocSidebarDrawer when isTocOpen is true', (tester) async {
      final card = CanvasCardModel(
        id: 'test_pdf_view_toc',
        cardType: CardType.pdf,
        pdfPath: 'dummy.pdf',
        x: 0,
        y: 0,
        width: 600,
        height: 800,
        currentPdfPage: 2,
        totalPdfPages: 10,
        bookmarkedPages: [2, 7],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CanvasCardPdfView(
                card: card,
                isSelected: true,
                onUpdateCard: (_) {},
                onPageChanged: (_) {},
                isTocOpen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drawer is mounted
      expect(find.byType(PdfTocSidebarDrawer), findsOneWidget);
      expect(find.text('Sumário & Marcadores'), findsOneWidget);
    });

    test('SmartTocCategory and SmartTocSection hold structured data and offset calculations', () {
      const section1 = SmartTocSection(
        title: 'Estudo geral dos equilíbrios químicos',
        pageNumber: 181,
        tag: null,
      );
      const section2 = SmartTocSection(
        title: 'Exercícios complementares',
        pageNumber: 159,
        tag: 'Exercícios',
      );

      const category = SmartTocCategory(
        title: 'Capítulo 5 - EQUILÍBRIOS QUÍMICOS HOMOGÊNEOS',
        pageNumber: 180,
        sections: [section1, section2],
        isChapter: true,
      );

      expect(category.title, contains('Capítulo 5'));
      expect(category.sections.length, equals(2));
      expect(category.sections.first.title, equals('Estudo geral dos equilíbrios químicos'));
      expect(category.sections.last.tag, equals('Exercícios'));

      // Page offset calculation test:
      // Book page 181 with offset +8 (e.g. TOC ending on page 8) => PDF page 189
      const offset = 8;
      final calibratedPage = section1.pageNumber + offset;
      expect(calibratedPage, equals(189));
    });

    test('Smart TOC search filters categories and sections accurately', () {
      const secA = SmartTocSection(title: 'Cinética química', pageNumber: 120);
      const secB = SmartTocSection(title: 'Fatores que afetam a velocidade', pageNumber: 124);
      const secC = SmartTocSection(title: 'Exercícios de fixação', pageNumber: 130, tag: 'Exercícios');

      const cat1 = SmartTocCategory(
        title: 'Capítulo 4 - CINÉTICA QUÍMICA',
        pageNumber: 118,
        sections: [secA, secB, secC],
      );

      const secD = SmartTocSection(title: 'Constante de equilíbrio Kc', pageNumber: 185);
      const cat2 = SmartTocCategory(
        title: 'Capítulo 5 - EQUILÍBRIOS QUÍMICOS',
        pageNumber: 180,
        sections: [secD],
      );

      final allCategories = [cat1, cat2];

      // Test 1: Query matching section title
      const query1 = 'velocidade';
      final match1 = allCategories.where((c) {
        return c.title.toLowerCase().contains(query1) ||
            c.sections.any((s) => s.title.toLowerCase().contains(query1));
      }).toList();
      expect(match1.length, equals(1));
      expect(match1.first.title, contains('Capítulo 4'));

      // Test 2: Query matching category title
      const query2 = 'equilíbrios';
      final match2 = allCategories.where((c) {
        return c.title.toLowerCase().contains(query2) ||
            c.sections.any((s) => s.title.toLowerCase().contains(query2));
      }).toList();
      expect(match2.length, equals(1));
      expect(match2.first.title, contains('Capítulo 5'));

      // Test 3: Query matching tag
      const query3 = 'exercícios';
      final match3 = allCategories.where((c) {
        return c.title.toLowerCase().contains(query3) ||
            c.sections.any((s) => s.tag != null && s.tag!.toLowerCase().contains(query3));
      }).toList();
      expect(match3.length, equals(1));
      expect(match3.first.sections.any((s) => s.tag == 'Exercícios'), isTrue);

      // Test 4: Query with no matches
      const query4 = 'termodinâmica';
      final match4 = allCategories.where((c) {
        return c.title.toLowerCase().contains(query4) ||
            c.sections.any((s) => s.title.toLowerCase().contains(query4));
      }).toList();
      expect(match4.isEmpty, isTrue);
    });
  });
}


