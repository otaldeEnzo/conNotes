import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/services/workspace_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceStorageService emptyTrash tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('connotes_trash_test_');
      await WorkspaceStorageService.instance.initialize(customPath: tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('emptyTrash deletes all files and directories in .trash', () async {
      final trashDir = Directory('${tempDir.path}/.trash');
      expect(trashDir.existsSync(), isTrue);

      // Create 100 test files and 10 directories in .trash
      for (int i = 0; i < 100; i++) {
        final file = File('${trashDir.path}/file_$i.cncanvas');
        await file.writeAsString('test content $i');
      }
      for (int i = 0; i < 10; i++) {
        final dir = Directory('${trashDir.path}/sub_dir_$i');
        await dir.create();
        final file = File('${dir.path}/sub_file.txt');
        await file.writeAsString('nested content');
      }

      final entitiesBefore = trashDir.listSync();
      expect(entitiesBefore.length, 110);

      final stopwatch = Stopwatch()..start();
      await WorkspaceStorageService.instance.emptyTrash();
      stopwatch.stop();

      final entitiesAfter = trashDir.listSync();
      expect(entitiesAfter.isEmpty, isTrue);

      print('Deletion of 110 items took ${stopwatch.elapsedMilliseconds} ms');
    });
  });
}
