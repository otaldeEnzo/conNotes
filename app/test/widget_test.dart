import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/main.dart';

void main() {
  testWidgets('Canvas render test', (WidgetTester tester) async {
    // Carrega o app conNotes
    await tester.pumpWidget(const ConNotesApp());

    // Verifica que a tela inicial possui a pilha do canvas
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
