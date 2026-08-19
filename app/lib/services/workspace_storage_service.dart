import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/note_models.dart';
import 'cncanvas_file_service.dart';

/// Gerenciador Central de Armazenamento Local-First, Workspace e Autosave do conNotes
class WorkspaceStorageService extends ChangeNotifier {
  static final WorkspaceStorageService instance = WorkspaceStorageService._internal();

  WorkspaceStorageService._internal();

  String _workspacePath = '';
  String get workspacePath => _workspacePath;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  List<NotebookFolder> _notebooks = [];
  List<NotebookFolder> get notebooks => _notebooks;

  List<NoteDocument> _rootNotes = [];
  List<NoteDocument> get rootNotes => _rootNotes;

  List<NoteDocument> _trashNotes = [];
  List<NoteDocument> get trashNotes => _trashNotes;

  /// Retorna todas as notas ativas do workspace (da raiz e de todos os cadernos)
  List<NoteDocument> get allNotes {
    final list = <NoteDocument>[..._rootNotes];
    for (final nb in _notebooks) {
      list.addAll(_flattenFolderNotes(nb));
    }
    return list;
  }

  List<NoteDocument> _flattenFolderNotes(NotebookFolder folder) {
    final list = <NoteDocument>[...folder.notes];
    for (final sub in folder.subFolders) {
      list.addAll(_flattenFolderNotes(sub));
    }
    return list;
  }

  StreamSubscription<FileSystemEvent>? _watcherSubscription;
  Timer? _autosaveDebounceTimer;
  Timer? _watcherDebounceTimer;
  final Set<String> _pendingSaveDocIds = {};

  /// Retorna o caminho padrão de Documentos do usuário no Windows / SO
  static String getDefaultWorkspacePath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return '$userProfile\\Documents\\conNotes';
      }
    }
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/Documents/conNotes';
  }

  /// Inicializa o Workspace no diretório configurado ou no padrão
  Future<void> initialize({String? customPath}) async {
    _workspacePath = customPath ?? getDefaultWorkspacePath();
    await _ensureDirectoryStructure();
    await scanWorkspace();
    _startFileSystemWatcher();
    _isInitialized = true;
    notifyListeners();
  }

  /// Garante a existência das pastas essenciais: Cadernos/ e .trash/
  Future<void> _ensureDirectoryStructure() async {
    final root = Directory(_workspacePath);
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }

    final cadernosDir = Directory('$_workspacePath/Cadernos');
    if (!cadernosDir.existsSync()) {
      await cadernosDir.create(recursive: true);
    }

    final trashDir = Directory('$_workspacePath/.trash');
    if (!trashDir.existsSync()) {
      await trashDir.create(recursive: true);
    }
  }

  /// Inicia o monitor em tempo real do sistema de arquivos para sincronizar com o Windows Explorer
  void _startFileSystemWatcher() {
    _watcherSubscription?.cancel();
    try {
      final dir = Directory(_workspacePath);
      if (dir.existsSync()) {
        _watcherSubscription = dir.watch(recursive: true).listen((event) {
          // Debounce para evitar varreduras repetitivas em operações de escrita rápida
          _watcherDebounceTimer?.cancel();
          _watcherDebounceTimer = Timer(const Duration(milliseconds: 600), () {
            scanWorkspace();
          });
        });
      }
    } catch (e) {
      debugPrint('[WorkspaceStorageService] FileSystemWatcher warning: $e');
    }
  }

  /// Varre a pasta do Workspace e reconstrói a árvore de Cadernos, Pastas e Notas .cncanvas
  Future<void> scanWorkspace() async {
    if (_workspacePath.isEmpty) return;

    final cadernosDir = Directory('$_workspacePath/Cadernos');
    if (!cadernosDir.existsSync()) {
      await _ensureDirectoryStructure();
    }

    final scannedNotebooks = <NotebookFolder>[];
    final scannedRootNotes = <NoteDocument>[];

    // Ler lista de cadernos e notas raiz
    try {
      final entities = cadernosDir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          final folderName = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final folder = await _scanFolder(entity, folderName);
          scannedNotebooks.add(folder);
        } else if (entity is File && entity.path.endsWith('.cncanvas')) {
          final doc = await CncanvasFileService.loadFromCnCanvasFile(entity.path);
          if (doc != null) {
            scannedRootNotes.add(doc);
          }
        }
      }
    } catch (e) {
      debugPrint('[WorkspaceStorageService] Error scanning Cadernos: $e');
    }

    // Varre a Lixeira (.trash/)
    final scannedTrashNotes = <NoteDocument>[];
    final trashDir = Directory('$_workspacePath/.trash');
    if (trashDir.existsSync()) {
      try {
        final trashEntities = trashDir.listSync();
        for (final entity in trashEntities) {
          if (entity is File && entity.path.endsWith('.cncanvas')) {
            final doc = await CncanvasFileService.loadFromCnCanvasFile(entity.path);
            if (doc != null) {
              scannedTrashNotes.add(doc);
            }
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceStorageService] Error scanning .trash: $e');
      }
    }

    _notebooks = scannedNotebooks;
    _rootNotes = scannedRootNotes;
    _trashNotes = scannedTrashNotes;
    notifyListeners();
  }

  /// Varre uma pasta recursivamente
  Future<NotebookFolder> _scanFolder(Directory dir, String name) async {
    final notes = <NoteDocument>[];
    final subFolders = <NotebookFolder>[];
    Color folderColor = const Color(0xFF00E1FF);
    String folderIcon = 'book';

    // Ler metadados persistentes (.notebook_meta.json)
    final metaFile = File('${dir.path}/.notebook_meta.json');
    if (metaFile.existsSync()) {
      try {
        final metaJson = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
        if (metaJson['color'] != null) {
          folderColor = Color(metaJson['color'] as int);
        }
        if (metaJson['icon'] != null) {
          folderIcon = metaJson['icon'] as String;
        }
      } catch (_) {}
    }

    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          final subName = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final sub = await _scanFolder(entity, subName);
          subFolders.add(sub);
        } else if (entity is File && entity.path.endsWith('.cncanvas')) {
          final doc = await CncanvasFileService.loadFromCnCanvasFile(entity.path);
          if (doc != null) {
            notes.add(doc);
          }
        }
      }
    } catch (_) {}

    return NotebookFolder(
      id: 'folder_${dir.path.hashCode}',
      name: name,
      folderPath: dir.path,
      color: folderColor,
      iconKey: folderIcon,
      notes: notes,
      subFolders: subFolders,
    );
  }

  /// Agenda o salvamento contínuo (Autosave com debounce de ~400ms) de uma nota ativa
  void queueAutosave(NoteDocument doc, {String? targetFolderName}) {
    _pendingSaveDocIds.add(doc.id);
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await saveNoteNow(doc, targetFolderName: targetFolderName);
      _pendingSaveDocIds.remove(doc.id);
    });
  }

  /// Salva imediatamente a nota no disco em formato .cncanvas
  Future<void> saveNoteNow(NoteDocument doc, {String? targetFolderName}) async {
    if (_workspacePath.isEmpty) return;

    String filePath = doc.filePath ?? '';
    if (filePath.isEmpty || !File(filePath).existsSync()) {
      // Criar caminho se a nota ainda não tiver arquivo no disco
      final safeTitle = doc.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final folder = targetFolderName != null && targetFolderName.isNotEmpty
          ? '$_workspacePath/Cadernos/$targetFolderName'
          : '$_workspacePath/Cadernos';
      
      final dir = Directory(folder);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      filePath = '$folder/$safeTitle.cncanvas';
    }

    try {
      await CncanvasFileService.saveToCnCanvasFile(doc, filePath);
    } catch (e) {
      debugPrint('[WorkspaceStorageService] Erro ao salvar nota ${doc.id}: $e');
    }
  }

  /// Cria um novo caderno físico no disco
  Future<NotebookFolder> createNotebook(String name, {Color color = const Color(0xFF00E1FF), String iconKey = 'book'}) async {
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folderPath = '$_workspacePath/Cadernos/$safeName';
    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    // Salvar metadados visuais no disco (.notebook_meta.json)
    final metaFile = File('$folderPath/.notebook_meta.json');
    try {
      metaFile.writeAsStringSync(jsonEncode({
        'name': name,
        'color': color.toARGB32(),
        'icon': iconKey,
      }));
    } catch (_) {}

    final folder = NotebookFolder(
      id: 'folder_${folderPath.hashCode}',
      name: name,
      folderPath: folderPath,
      color: color,
      iconKey: iconKey,
    );

    _notebooks.add(folder);
    notifyListeners();
    return folder;
  }

  /// Cria uma nova nota .cncanvas em um caderno específico ou na raiz
  Future<NoteDocument> createNote({required String title, String? targetFolderName}) async {
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folderPath = targetFolderName != null && targetFolderName.isNotEmpty
        ? '$_workspacePath/Cadernos/$targetFolderName'
        : '$_workspacePath/Cadernos';

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final filePath = '$folderPath/$safeTitle.cncanvas';
    final doc = NoteDocument(
      id: 'note_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      filePath: filePath,
    );

    await CncanvasFileService.saveToCnCanvasFile(doc, filePath);
    await scanWorkspace();
    return doc;
  }

  /// Renomeia atomicamente a nota e o arquivo .cncanvas no disco
  Future<void> renameNote(NoteDocument note, String newTitle) async {
    final cleanTitle = newTitle.trim();
    if (cleanTitle.isEmpty || cleanTitle == note.title) return;

    final currentPath = note.filePath;
    if (currentPath != null && File(currentPath).existsSync()) {
      final parentDir = File(currentPath).parent.path;
      final safeTitle = cleanTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final newPath = '$parentDir/$safeTitle.cncanvas';

      if (currentPath != newPath) {
        final file = File(currentPath);
        try {
          await file.rename(newPath);
        } catch (_) {
          await file.copy(newPath);
          await file.delete();
        }
        note.filePath = newPath;
      }
    }

    note.title = cleanTitle;
    if (note.filePath != null) {
      await CncanvasFileService.saveToCnCanvasFile(note, note.filePath!);
    }
    await scanWorkspace();
    notifyListeners();
  }

  /// Aninha uma nota arrastada como subnota (filha) de outra nota
  Future<void> nestNoteAsSubnote(NoteDocument childNote, NoteDocument parentNote) async {
    if (childNote.id == parentNote.id) return;

    // Remove child de onde ela estiver na árvore
    _removeNoteFromList(_rootNotes, childNote.id);
    for (final nb in _notebooks) {
      _removeNoteFromList(nb.notes, childNote.id);
    }

    // Se já estiver como filha, evita duplicata
    if (!parentNote.children.any((n) => n.id == childNote.id)) {
      parentNote.children.add(childNote);
    }

    if (parentNote.filePath != null) {
      await CncanvasFileService.saveToCnCanvasFile(parentNote, parentNote.filePath!);
    }
    await scanWorkspace();
    notifyListeners();
  }

  /// Reordena uma nota arrastada para antes ou depois de uma nota de destino
  Future<void> reorderNote(NoteDocument dragged, NoteDocument target, bool before, {String? targetFolderName}) async {
    if (dragged.id == target.id) return;

    // Primeiro move o arquivo se for para outro caderno
    await moveNoteToNotebook(dragged, targetFolderName);

    // Ajusta a ordem na lista apropriada
    List<NoteDocument> list;
    if (targetFolderName != null && targetFolderName.isNotEmpty) {
      final nb = _notebooks.firstWhere((n) => n.name == targetFolderName, orElse: () => _notebooks.first);
      list = nb.notes;
    } else {
      list = _rootNotes;
    }

    list.removeWhere((n) => n.id == dragged.id);
    final targetIdx = list.indexWhere((n) => n.id == target.id);
    if (targetIdx != -1) {
      final insertIdx = before ? targetIdx : (targetIdx + 1);
      list.insert(insertIdx.clamp(0, list.length), dragged);
    } else {
      list.add(dragged);
    }

    notifyListeners();
  }

  bool _removeNoteFromList(List<NoteDocument> list, String noteId) {
    final idx = list.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      list.removeAt(idx);
      return true;
    }
    for (final item in list) {
      if (_removeNoteFromList(item.children, noteId)) return true;
    }
    return false;
  }

  /// Move uma nota entre cadernos (ou para a raiz de Cadernos/ se targetFolderName for null)
  Future<void> moveNoteToNotebook(NoteDocument note, String? targetFolderName) async {
    final currentPath = note.filePath;
    if (currentPath == null || !File(currentPath).existsSync()) return;

    final fileName = File(currentPath).uri.pathSegments.last;
    final targetDir = targetFolderName != null && targetFolderName.isNotEmpty
        ? '$_workspacePath/Cadernos/$targetFolderName'
        : '$_workspacePath/Cadernos';

    final targetDirPath = Directory(targetDir);
    if (!targetDirPath.existsSync()) {
      targetDirPath.createSync(recursive: true);
    }

    final newPath = '$targetDir/$fileName';
    if (currentPath != newPath) {
      final file = File(currentPath);
      try {
        await file.rename(newPath);
      } catch (_) {
        await file.copy(newPath);
        await file.delete();
      }
      note.filePath = newPath;
      await scanWorkspace();
    }
  }

  /// Abre a nota .cncanvas no navegador web padrão do sistema
  Future<void> openInBrowser(NoteDocument note) async {
    if (note.filePath == null || !File(note.filePath!).existsSync()) {
      await saveNoteNow(note);
    }
    if (note.filePath != null) {
      final path = note.filePath!;
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    }
  }

  /// Lixeira Etapa 1: Move a nota fisicamente para a pasta .trash/
  Future<void> moveToTrash(NoteDocument doc) async {
    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      final fileName = File(doc.filePath!).uri.pathSegments.last;
      final trashPath = '$_workspacePath/.trash/$fileName';
      final file = File(doc.filePath!);
      try {
        await file.rename(trashPath);
        doc.filePath = trashPath;
      } catch (_) {
        // Se rename falhar entre unidades, faz copy + delete
        await file.copy(trashPath);
        await file.delete();
        doc.filePath = trashPath;
      }
    }
    await scanWorkspace();
  }

  /// Lixeira Etapa 2: Restaura uma nota da .trash/ de volta para a pasta de Cadernos
  Future<void> restoreFromTrash(NoteDocument doc, {String? targetFolderName}) async {
    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      final fileName = File(doc.filePath!).uri.pathSegments.last;
      final targetFolder = targetFolderName != null
          ? '$_workspacePath/Cadernos/$targetFolderName'
          : '$_workspacePath/Cadernos';
      
      final targetPath = '$targetFolder/$fileName';
      final file = File(doc.filePath!);
      try {
        await file.rename(targetPath);
        doc.filePath = targetPath;
      } catch (_) {
        await file.copy(targetPath);
        await file.delete();
        doc.filePath = targetPath;
      }
    }
    await scanWorkspace();
  }

  /// Lixeira Etapa 3: Esvazia definitivamente todos os arquivos de .trash/
  Future<void> emptyTrash() async {
    final trashDir = Directory('$_workspacePath/.trash');
    if (trashDir.existsSync()) {
      try {
        final entities = trashDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      } catch (e) {
        debugPrint('[WorkspaceStorageService] Error emptying trash: $e');
      }
    }
    await scanWorkspace();
  }

  /// Altera o diretório do Workspace com migração assistida de arquivos
  Future<void> changeWorkspaceDirectory(String newPath, {required bool migrateExistingFiles}) async {
    if (newPath == _workspacePath) return;

    final oldPath = _workspacePath;
    final newDir = Directory(newPath);
    if (!newDir.existsSync()) {
      await newDir.create(recursive: true);
    }

    if (migrateExistingFiles && oldPath.isNotEmpty && Directory(oldPath).existsSync()) {
      // Migração: copia todos os arquivos de Cadernos/ para o novo destino
      final oldCadernos = Directory('$oldPath/Cadernos');
      final newCadernos = Directory('$newPath/Cadernos');
      if (oldCadernos.existsSync()) {
        if (!newCadernos.existsSync()) newCadernos.createSync(recursive: true);
        await _copyDirectoryRecursively(oldCadernos, newCadernos);
      }
    }

    _workspacePath = newPath;
    await _ensureDirectoryStructure();
    _startFileSystemWatcher();
    await scanWorkspace();
    notifyListeners();
  }

  static Future<void> _copyDirectoryRecursively(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    for (final entity in source.listSync(recursive: false)) {
      if (entity is Directory) {
        final newSubDir = Directory('${destination.path}/${entity.uri.pathSegments.where((s) => s.isNotEmpty).last}');
        await _copyDirectoryRecursively(entity, newSubDir);
      } else if (entity is File) {
        final newFilePath = '${destination.path}/${entity.uri.pathSegments.last}';
        await entity.copy(newFilePath);
      }
    }
  }

  @override
  void dispose() {
    _watcherSubscription?.cancel();
    _autosaveDebounceTimer?.cancel();
    _watcherDebounceTimer?.cancel();
    super.dispose();
  }
}
