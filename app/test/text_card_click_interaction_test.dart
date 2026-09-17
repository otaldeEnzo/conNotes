import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/widgets/markdown_latex_block_view.dart';
import 'package:connotes_app/widgets/canvas_card_widget.dart';
import 'package:connotes_app/widgets/canvas_cards_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Text Card Click Interaction Tests', () {
    testWidgets('1. Clique unico em bloco de texto seleciona o card sem abrir edicao', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_text_1',
        title: 'Note Card',
        content: 'Primeiro bloco de texto\n---\nSegundo bloco de texto',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final firstBlock = find.textContaining('Primeiro bloco');
      expect(firstBlock, findsOneWidget);
      await tester.tap(firstBlock);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Clique unico deve selecionar o card');
      expect(editingMode, isFalse, reason: 'Clique unico nao deve abrir o modo de edicao');
      expect(find.byType(TextField), findsNothing, reason: 'Nao deve haver campo de texto em edicao');
    });

    testWidgets('2. Clique unico em bloco LaTeX seleciona o card sem abrir modal', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_latex_1',
        title: 'Formula Card',
        content: 'Texto introdutorio\n---\n' r'$$\int_0^\infty e^{-x} dx = 1$$',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final latexGesture = find.byWidgetPredicate((widget) =>
        widget is GestureDetector && widget.behavior == HitTestBehavior.translucent
      );
      expect(latexGesture, findsOneWidget);

      await tester.tap(latexGesture);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Clique unico no bloco LaTeX deve selecionar o card');
      expect(editingMode, isFalse, reason: 'Clique unico no LaTeX nao deve abrir edicao nem modal');
      expect(find.text('Inserir Formula'), findsNothing, reason: 'Modal LaTeX nao deve abrir no clique unico');
    });

    testWidgets('3. Clique unico em area vazia seleciona o card', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_empty_area_1',
        title: 'Sparse Card',
        content: 'Apenas uma linha de texto',
        x: 0,
        y: 0,
        width: 350,
        height: 350,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 350,
              height: 350,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(150, 250));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Clique unico na area vazia deve selecionar o card');
      expect(editingMode, isFalse, reason: 'Clique unico na area vazia nao deve entrar em edicao');
    });

    testWidgets('4. Duplo clique em bloco seleciona o card e abre edicao do bloco', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_edit_block_1',
        title: 'Editable Card',
        content: 'Bloco para editar',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final blockText = find.textContaining('Bloco para editar');
      expect(blockText, findsOneWidget);

      await tester.tap(blockText);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(blockText);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Duplo clique no bloco deve selecionar o card');
      expect(editingMode, isTrue, reason: 'Duplo clique no bloco deve ativar modo de edicao');
      expect(find.byType(TextField), findsOneWidget, reason: 'TextField do bloco deve ser exibido');
    });

    testWidgets('5. Duplo clique em area vazia seleciona o card e cria novo bloco focado', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;
      String currentContent = 'Bloco 1 inicial';

      final card = CanvasCardModel(
        id: 'card_create_block_1',
        title: 'Card Expansivel',
        content: currentContent,
        x: 0,
        y: 0,
        width: 350,
        height: 350,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 350,
              height: 350,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (newContent) {
                  currentContent = newContent;
                },
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      const emptyAreaPoint = Offset(150, 250);
      await tester.tapAt(emptyAreaPoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(emptyAreaPoint);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Duplo clique na area vazia deve selecionar o card');
      expect(editingMode, isTrue, reason: 'Duplo clique na area vazia deve abrir novo bloco em edicao');
      expect(find.byType(TextField), findsOneWidget, reason: 'Campo de texto do novo bloco deve estar ativo');
      expect(currentContent.contains('\n---\n'), isTrue, reason: 'Novo bloco deve ter sido criado no conteudo');
    });

    testWidgets('6. Integracao completa com CanvasCardWidget: clique no corpo seleciona card', (tester) async {
      String? selectedId;

      final card = CanvasCardModel(
        id: 'canvas_card_full_1',
        title: 'Card de Integracao',
        content: 'Conteudo do card',
        x: 50,
        y: 50,
        width: 300,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 360,
              child: CanvasCardWidget(
                card: card,
                isSelected: false,
                onSelectCard: (id) => selectedId = id,
                onUpdateCard: (_) {},
                onDeleteCard: (_) {},
                onDuplicateCard: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('Conteudo do card');
      expect(textFinder, findsOneWidget);

      await tester.tap(textFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedId, equals('canvas_card_full_1'), reason: 'Clicar no corpo do card atraves do CanvasCardWidget deve disparar onSelectCard com o id correto');
    });

    testWidgets('7. Clique unico em placeholder de card vazio seleciona o card', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_placeholder_1',
        title: 'Empty Card',
        content: '',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final placeholder = find.text('Card STEM');
      expect(placeholder, findsOneWidget);

      await tester.tap(placeholder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Clique unico no placeholder deve selecionar o card');
      expect(editingMode, isFalse, reason: 'Clique unico no placeholder nao deve abrir edicao');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('8. Duplo clique em placeholder de card vazio seleciona o card e abre edicao', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_placeholder_2',
        title: 'Empty Card',
        content: '',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final placeholder = find.text('Card STEM');
      expect(placeholder, findsOneWidget);

      await tester.tap(placeholder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(placeholder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Duplo clique no placeholder deve selecionar o card');
      expect(editingMode, isTrue, reason: 'Duplo clique no placeholder deve abrir edicao');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('9. Clique unico em texto com LaTeX inline seleciona o card sem abrir modal', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_inline_latex_1',
        title: 'Inline Formula Card',
        content: r'Texto com $E = mc^2$ no meio do bloco',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('Texto com');
      expect(textFinder, findsOneWidget);

      await tester.tap(textFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Clique unico em formula inline deve selecionar o card');
      expect(editingMode, isFalse, reason: 'Clique unico em formula inline nao deve entrar em edicao');
      expect(find.text('Inserir Formula'), findsNothing, reason: 'Nao deve abrir modal de edicao LaTeX');
    });

    testWidgets('10. Duplo clique no cabecalho com card nao selecionado seleciona o card', (tester) async {
      String? selectedId;

      final card = CanvasCardModel(
        id: 'canvas_card_header_1',
        title: 'Card com Titulo',
        content: 'Conteudo do card',
        x: 50,
        y: 50,
        width: 300,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 360,
              child: CanvasCardWidget(
                card: card,
                isSelected: false,
                onSelectCard: (id) => selectedId = id,
                onUpdateCard: (_) {},
                onDeleteCard: (_) {},
                onDuplicateCard: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final titleFinder = find.text('Card com Titulo');
      expect(titleFinder, findsOneWidget);

      await tester.tap(titleFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(titleFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedId, equals('canvas_card_header_1'), reason: 'Duplo clique no cabecalho com card nao selecionado deve selecionar o card');
    });

    testWidgets('11. Duplo clique em texto com LaTeX inline seleciona o card e abre edicao do bloco', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_inline_double_tap',
        title: 'Inline Double Tap Card',
        content: r'Texto com $x^2 + y^2 = r^2$ no meio',
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('Texto com');
      expect(textFinder, findsOneWidget);

      await tester.tap(textFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(textFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Duplo clique em texto com formula inline deve selecionar o card');
      expect(editingMode, isTrue, reason: 'Duplo clique em texto com formula inline deve abrir edicao do bloco');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('12. Clique unico em display math no markdown seleciona o card sem modal', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_display_math_1',
        title: 'Display Math Card',
        content: "Prefacio\n" r"$$\sum_{i=1}^n i = \frac{n(n+1)}{2}$$" "\nPosfacio",
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('Prefacio');
      expect(textFinder, findsOneWidget);

      await tester.tap(textFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue);
      expect(editingMode, isFalse);
      expect(find.text('Inserir Formula'), findsNothing);
    });

    testWidgets('13. Duplo clique em bloco de codigo seleciona o card e abre edicao', (tester) async {
      bool cardSelected = false;
      bool editingMode = false;

      final card = CanvasCardModel(
        id: 'card_code_block_1',
        title: 'Code Card',
        content: "```rust\nfn main() {\n    println!(\"Hello\");\n}\n```",
        x: 0,
        y: 0,
        width: 350,
        height: 300,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 300,
              child: MarkdownLatexBlockView(
                card: card,
                isSelected: false,
                onSelectCard: () => cardSelected = true,
                onEditingModeChanged: (editing) => editingMode = editing,
                onContentChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final codeFinder = find.textContaining('println!');
      expect(codeFinder, findsOneWidget);

      await tester.tap(codeFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(codeFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(cardSelected, isTrue, reason: 'Duplo clique no bloco de codigo deve selecionar o card');
      expect(editingMode, isTrue, reason: 'Duplo clique no bloco de codigo deve abrir edicao do bloco');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('14. CanvasCardsLayer: Duplo clique em area vazia de card NAO selecionado seleciona o card e cria novo bloco focado', (tester) async {
      String? selectedCardId;
      final selectionUpdateNotifier = ValueNotifier<int>(0);
      final panNotifier = ValueNotifier<Offset>(Offset.zero);
      final zoomNotifier = ValueNotifier<double>(1.0);

      CanvasCardModel card = CanvasCardModel(
        id: 'card_unselected_layer_1',
        title: 'Card na Camada',
        content: 'Primeira linha de texto',
        x: 0,
        y: 60,
        width: 350,
        height: 350,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 800,
                height: 800,
                child: CanvasCardsLayer(
                  cards: [card],
                  selectedCardId: selectedCardId,
                  selectionUpdateNotifier: selectionUpdateNotifier,
                  panNotifier: panNotifier,
                  zoomNotifier: zoomNotifier,
                  onSelectCard: (id) {
                    setState(() {
                      selectedCardId = id;
                    });
                  },
                  onUpdateCard: (updated) {
                    setState(() {
                      card = updated;
                    });
                  },
                  onDeleteCard: (_) {},
                  onDuplicateCard: (_) {},
                ),
              );
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedCardId, isNull, reason: 'Inicialmente nenhum card deve estar selecionado');

      // Duplo clique na área vazia inferior do card
      const emptyAreaPoint = Offset(150, 260);
      await tester.tapAt(emptyAreaPoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(emptyAreaPoint);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedCardId, equals('card_unselected_layer_1'), reason: 'Duplo clique deve selecionar o card');
      expect(find.byType(TextField), findsOneWidget, reason: 'Deve criar e abrir novo TextField de edicao no card');
      expect(card.content.contains('\n---\n'), isTrue, reason: 'Novo bloco deve ter sido criado no conteudo');
    });

    testWidgets('15. CanvasCardsLayer: Duplo clique em bloco existente de card NAO selecionado seleciona o card e abre edicao do bloco', (tester) async {
      String? selectedCardId;
      final selectionUpdateNotifier = ValueNotifier<int>(0);
      final panNotifier = ValueNotifier<Offset>(Offset.zero);
      final zoomNotifier = ValueNotifier<double>(1.0);

      CanvasCardModel card = CanvasCardModel(
        id: 'card_unselected_layer_2',
        title: 'Card com Bloco',
        content: 'Bloco existente para editar',
        x: 0,
        y: 60,
        width: 350,
        height: 350,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 800,
                height: 800,
                child: CanvasCardsLayer(
                  cards: [card],
                  selectedCardId: selectedCardId,
                  selectionUpdateNotifier: selectionUpdateNotifier,
                  panNotifier: panNotifier,
                  zoomNotifier: zoomNotifier,
                  onSelectCard: (id) {
                    setState(() {
                      selectedCardId = id;
                    });
                  },
                  onUpdateCard: (updated) {
                    setState(() {
                      card = updated;
                    });
                  },
                  onDeleteCard: (_) {},
                  onDuplicateCard: (_) {},
                ),
              );
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedCardId, isNull, reason: 'Inicialmente nenhum card deve estar selecionado');

      final blockFinder = find.textContaining('Bloco existente para editar');
      expect(blockFinder, findsOneWidget);

      await tester.tap(blockFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(blockFinder);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(selectedCardId, equals('card_unselected_layer_2'), reason: 'Duplo clique no bloco deve selecionar o card');
      expect(find.byType(TextField), findsOneWidget, reason: 'TextField do bloco existente deve estar em edicao');
    });
  });
}
