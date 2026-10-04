import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/services/workspace_storage_service.dart';
import 'package:connotes_app/widgets/note_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cnnotes_test_ws_');
    await WorkspaceStorageService.instance.initialize(customPath: tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('flushPendingSaves flushes all queued documents correctly', () async {
    final docs = List.generate(
      20,
      (i) => NoteDocument(
        id: 'test_doc_$i',
        title: 'Test Note $i',
      ),
    );

    for (final doc in docs) {
      WorkspaceStorageService.instance.queueAutosave(doc);
    }

    await WorkspaceStorageService.instance.flushPendingSaves();

    for (final doc in docs) {
      expect(doc.filePath, isNotNull);
      final file = File(doc.filePath!);
      expect(file.existsSync(), isTrue);
    }
  });

  test('Benchmark flushPendingSaves execution time for 100 pending saves', () async {
    final count = 100;
    final docs = List.generate(
      count,
      (i) => NoteDocument(
        id: 'bench_doc_$i',
        title: 'Benchmark Note $i',
      ),
    );

    for (final doc in docs) {
      WorkspaceStorageService.instance.queueAutosave(doc);
    }

    final stopwatch = Stopwatch()..start();
    await WorkspaceStorageService.instance.flushPendingSaves();
    stopwatch.stop();

    print('BENCHMARK_RESULT: Saved $count notes in ${stopwatch.elapsedMilliseconds} ms');

    for (final doc in docs) {
      expect(File(doc.filePath!).existsSync(), isTrue);
    }
  });
}
