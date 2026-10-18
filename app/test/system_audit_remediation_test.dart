import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/cncanvas_file_service.dart';
import 'package:connotes_app/services/workspace_storage_service.dart';
import 'package:connotes_app/widgets/note_models.dart';

void main() {
  group('Parte 1 & 2: CncanvasFileService Data Integrity & Hardening', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('connotes_audit_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Persists and reloads note containing literal </script> in cards and title without corruption', () async {
      final targetPath = '${tempDir.path}/script_breakout_test.cncanvas';
      final doc = NoteDocument(
        id: 'note_xss_1',
        title: 'Aula </script><script>evil()</script>',
        filePath: targetPath,
        cards: [
          CanvasCardModel(
            id: 'card_1',
            cardType: CardType.textLatex,
            x: 10,
            y: 20,
            width: 300,
            height: 200,
            title: 'Bloco HTML',
            content: 'const html = "<script id=\\"x\\">alert(1)</script>";',
          ),
        ],
      );

      await CncanvasFileService.saveToCnCanvasFile(doc, targetPath);

      // Verify atomic write left no .tmp file behind
      expect(File('$targetPath.tmp').existsSync(), isFalse);

      // Verify CSP meta tag is present
      final rawHtml = await File(targetPath).readAsString();
      expect(rawHtml.contains('http-equiv="Content-Security-Policy"'), isTrue);

      // Reload and verify 100% data integrity
      final loaded = await CncanvasFileService.loadFromCnCanvasFile(targetPath);
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('Aula </script><script>evil()</script>'));
      expect(loaded.cards.length, equals(1));
      expect(loaded.cards.first.content, contains('</script>'));
    });

    test('Resiliently recovers legacy .cncanvas file with unescaped </script> inside JSON payload', () async {
      final legacyPath = '${tempDir.path}/legacy_corrupted.cncanvas';
      const legacyHtml = '''<!DOCTYPE html>
<html>
<body>
  <script id="connotes-data" type="application/json">
{"id":"legacy_1","title":"Nota Antiga </script> Recuperada","panX":0.0,"panY":0.0,"zoomScale":1.0,"strokes":[],"cards":[]}
  </script>
  <!-- MOTOR OFFLINE DE PAN & ZOOM INTERATIVO (< 5 KB) -->
  <script></script>
</body>
</html>''';
      await File(legacyPath).writeAsString(legacyHtml);

      final recovered = await CncanvasFileService.loadFromCnCanvasFile(legacyPath);
      expect(recovered, isNotNull);
      expect(recovered!.id, equals('legacy_1'));
      expect(recovered.title, equals('Nota Antiga </script> Recuperada'));
    });
  });

  group('Parte 1 & 2: WorkspaceStorageService Sanitization & Accidental Data Loss Prevention', () {
    test('sanitizeFileSystemName blocks path traversal, shell metacharacters, and Windows reserved names', () {
      expect(WorkspaceStorageService.sanitizeFileSystemName('..'), equals('Sem_Titulo'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('...'), equals('Sem_Titulo'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('../segredo'), equals('_segredo'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('CON'), equals('_CON'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('aux.txt'), equals('_aux.txt'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('com1'), equals('_com1'));
      expect(WorkspaceStorageService.sanitizeFileSystemName('Nota & calc.exe; echo %PATH%'), isNot(contains('&')));
      expect(WorkspaceStorageService.sanitizeFileSystemName('Nota & calc.exe; echo %PATH%'), isNot(contains(';')));
      expect(WorkspaceStorageService.sanitizeFileSystemName('Nota & calc.exe; echo %PATH%'), isNot(contains('%')));
      expect(WorkspaceStorageService.sanitizeFileSystemName('Titulo com ponto final... '), equals('Titulo com ponto final'));
    });
  });
}
