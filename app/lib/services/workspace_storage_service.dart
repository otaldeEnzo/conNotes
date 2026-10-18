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

  final ChangeNotifier notesListNotifier = ChangeNotifier();

  void notifyNotesListChanged() {
    notesListNotifier.notifyListeners();
  }

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
  final Map<String, NoteDocument> _pendingDocs = {};
  final Map<String, DateTime> _recentInternalWrites = {};
  final Map<String, ({DateTime lastModified, NoteDocument doc})> _mtimeCache = {};

  void _recordInternalWrite(String path, [NoteDocument? doc]) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    _recentInternalWrites[normalized] = DateTime.now();
    if (doc != null) {
      try {
        final stat = File(path).statSync();
        _mtimeCache[normalized] = (lastModified: stat.modified, doc: doc);
      } catch (_) {}
    }
  }

  Future<NoteDocument?> _loadCachedDoc(File file) async {
    try {
      final stat = await file.stat();
      final normalizedPath = file.path.replaceAll('\\', '/').toLowerCase();
      final cached = _mtimeCache[normalizedPath];
      if (cached != null && cached.lastModified.isAtSameMomentAs(stat.modified)) {
        return cached.doc;
      }
      final doc = await CncanvasFileService.loadFromCnCanvasFile(file.path);
      if (doc != null) {
        _mtimeCache[normalizedPath] = (lastModified: stat.modified, doc: doc);
      } else {
        _mtimeCache.remove(normalizedPath);
      }
      return doc;
    } catch (_) {
      return null;
    }
  }

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
    notesListNotifier.notifyListeners();
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
      final dir = Directory('$_workspacePath/Cadernos');
      if (dir.existsSync()) {
        _watcherSubscription = dir.watch(recursive: true).listen((event) {
          final p = event.path;
          // Ignorar arquivos temporários .tmp imediatamente antes de qualquer verificação
          if (p.endsWith('.tmp')) {
            return;
          }
          // Ignorar arquivos temporários ou de sistema
          if (p.contains(r'\.') || p.contains('/.')) {
            return;
          }
          // Apenas reagir se for arquivo .cncanvas ou alteração de pasta
          if (!p.endsWith('.cncanvas') && !FileSystemEntity.isDirectorySync(p)) {
            return;
          }

          // Ignorar eventos gerados por escritas internas recentes (janela de 2.5 segundos)
          final normalized = p.replaceAll('\\', '/').toLowerCase();
          final writeTime = _recentInternalWrites[normalized];
          if (writeTime != null) {
            if (DateTime.now().difference(writeTime).inMilliseconds < 2500) {
              return;
            } else {
              _recentInternalWrites.remove(normalized);
            }
          }

          // Debounce para evitar varreduras repetitivas em operações de escrita rápida
          _watcherDebounceTimer?.cancel();
          _watcherDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
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
          final doc = await _loadCachedDoc(entity);
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
            final doc = await _loadCachedDoc(entity);
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
          final doc = await _loadCachedDoc(entity);
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

  /// Sanitiza um nome de arquivo ou pasta contra Path Traversal (..), caracteres de controle de shell e nomes reservados do Windows
  static String sanitizeFileSystemName(String rawName) {
    var cleaned = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F&^%!;]'), '_')
        .trim();
    // Remove pontos e espaços finais (inválidos na API Win32)
    while (cleaned.endsWith('.') || cleaned.endsWith(' ')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    while (cleaned.startsWith('.')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      cleaned = 'Sem_Titulo';
    }
    final reservedWin = RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$', caseSensitive: false);
    if (reservedWin.hasMatch(cleaned)) {
      cleaned = '_$cleaned';
    }
    if (cleaned.length > 120) {
      cleaned = cleaned.substring(0, 120).trim();
    }
    return cleaned;
  }

  /// Resolve um caminho único no diretório alvo para evitar sobrescrita silenciosa de notas existentes
  static String _resolveUniqueFilePath(
    String dirPath,
    String baseNameWithoutExt, {
    String? ignoreCurrentPath,
    String extension = '.cncanvas',
  }) {
    final safeBase = sanitizeFileSystemName(baseNameWithoutExt);
    final normalizedIgnore = ignoreCurrentPath?.replaceAll('\\', '/').toLowerCase();

    var candidate = '$dirPath/$safeBase$extension';
    if (normalizedIgnore != null && candidate.replaceAll('\\', '/').toLowerCase() == normalizedIgnore) {
      return candidate;
    }
    int counter = 2;
    while (File(candidate).existsSync()) {
      final candidateNorm = candidate.replaceAll('\\', '/').toLowerCase();
      if (normalizedIgnore != null && candidateNorm == normalizedIgnore) {
        return candidate;
      }
      candidate = '$dirPath/$safeBase ($counter)$extension';
      counter++;
    }
    return candidate;
  }

  /// Agenda o salvamento contínuo (Autosave com debounce de ~400ms) de todas as notas pendentes
  void queueAutosave(NoteDocument doc, {String? targetFolderName}) {
    if ((doc.filePath == null || doc.filePath!.isEmpty) && _workspacePath.isNotEmpty) {
      final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
          ? sanitizeFileSystemName(targetFolderName)
          : null;
      final folder = safeFolder != null
          ? '$_workspacePath/Cadernos/$safeFolder'
          : '$_workspacePath/Cadernos';
      doc.filePath = _resolveUniqueFilePath(folder, doc.title);
    }
    _pendingSaveDocIds.add(doc.id);
    _pendingDocs[doc.id] = doc;
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await flushPendingSaves();
    });
  }

  /// Descarrega imediatamente todas as notas com autosave pendente diretamente no disco
  Future<void> flushPendingSaves() async {
    _autosaveDebounceTimer?.cancel();
    if (_pendingDocs.isNotEmpty) {
      final docsToSave = List<NoteDocument>.from(_pendingDocs.values);
      _pendingDocs.clear();
      _pendingSaveDocIds.clear();
      for (final doc in docsToSave) {
        await saveNoteNow(doc);
      }
    }
  }

  /// Alias para queueAutosave
  void scheduleAutoSave(NoteDocument doc) => queueAutosave(doc);

  /// Registro em memória de títulos e caminhos atualizados para manter abas abertas sincronizadas
  final Map<String, ({String title, String? filePath})> _liveNoteMetadata = {};

  /// Busca uma nota pelo ID em toda a árvore (raiz, cadernos e subnotas recursivas)
  NoteDocument? findNoteById(String noteId) {
    NoteDocument? searchList(List<NoteDocument> list) {
      for (final n in list) {
        if (n.id == noteId) return n;
        if (n.children.isNotEmpty) {
          final found = searchList(n.children);
          if (found != null) return found;
        }
      }
      return null;
    }

    final inRoot = searchList(_rootNotes);
    if (inRoot != null) return inRoot;

    for (final nb in _notebooks) {
      final inNb = searchList(nb.notes);
      if (inNb != null) return inNb;
    }
    return null;
  }

  /// Retorna o título mais recente da nota para sincronização imediata com a NoteTabBar
  String? getLiveNoteTitle(String noteId) {
    final live = _liveNoteMetadata[noteId];
    if (live != null) return live.title;
    return findNoteById(noteId)?.title;
  }

  /// Salva imediatamente a nota no disco em formato .cncanvas
  Future<void> saveNoteNow(NoteDocument doc, {String? targetFolderName}) async {
    if (_workspacePath.isEmpty) return;

    // Sincroniza título e caminho caso a nota tenha sido renomeada ou movida pela Sidebar enquanto aberta
    final liveMeta = _liveNoteMetadata[doc.id];
    if (liveMeta != null) {
      doc.title = liveMeta.title;
      if (liveMeta.filePath != null && liveMeta.filePath!.isNotEmpty) {
        doc.filePath = liveMeta.filePath;
      }
    }

    String filePath = doc.filePath ?? '';
    if (filePath.isEmpty) {
      final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
          ? sanitizeFileSystemName(targetFolderName)
          : null;
      final folder = safeFolder != null
          ? '$_workspacePath/Cadernos/$safeFolder'
          : '$_workspacePath/Cadernos';
      
      final dir = Directory(folder);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      filePath = _resolveUniqueFilePath(folder, doc.title);
    }

    try {
      _recordInternalWrite(filePath, doc);
      await CncanvasFileService.saveToCnCanvasFile(doc, filePath);
      _recordInternalWrite(filePath, doc);
      _liveNoteMetadata[doc.id] = (title: doc.title, filePath: doc.filePath);
    } catch (e) {
      debugPrint('[WorkspaceStorageService] Erro ao salvar nota ${doc.id}: $e');
    }
  }

  /// Cria um novo caderno físico no disco
  Future<NotebookFolder> createNotebook(String name, {Color color = const Color(0xFF00E1FF), String iconKey = 'book'}) async {
    final safeName = sanitizeFileSystemName(name);
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
    notesListNotifier.notifyListeners();
    return folder;
  }

  /// Cria uma nova nota .cncanvas em um caderno específico ou na raiz (resolvendo título único como 'a (2)' se já existir)
  Future<NoteDocument> createNote({required String title, String? targetFolderName}) async {
    final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
        ? sanitizeFileSystemName(targetFolderName)
        : null;
    final folderPath = safeFolder != null
        ? '$_workspacePath/Cadernos/$safeFolder'
        : '$_workspacePath/Cadernos';

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final filePath = _resolveUniqueFilePath(folderPath, title);
    // Extrai o título resolvido (ex: se 'a' já existia, o título vira 'a (2)')
    final resolvedTitle = File(filePath).uri.pathSegments.last.replaceAll('.cncanvas', '');

    final doc = NoteDocument(
      id: 'note_${DateTime.now().microsecondsSinceEpoch}',
      title: resolvedTitle,
      filePath: filePath,
    );

    _liveNoteMetadata[doc.id] = (title: resolvedTitle, filePath: filePath);
    _recordInternalWrite(filePath, doc);
    await CncanvasFileService.saveToCnCanvasFile(doc, filePath);
    _recordInternalWrite(filePath, doc);
    await scanWorkspace();
    notifyListeners();
    notesListNotifier.notifyListeners();
    return doc;
  }

  /// Renomeia atomicamente a nota e o arquivo .cncanvas no disco sem sobrescrever outras notas
  Future<void> renameNote(NoteDocument note, String newTitle) async {
    final cleanTitle = newTitle.trim();
    if (cleanTitle.isEmpty || cleanTitle == note.title) return;

    String resolvedTitle = cleanTitle;
    final currentPath = note.filePath;
    if (currentPath != null && File(currentPath).existsSync()) {
      final parentDir = File(currentPath).parent.path;
      final newPath = _resolveUniqueFilePath(
        parentDir,
        cleanTitle,
        ignoreCurrentPath: currentPath,
      );
      resolvedTitle = File(newPath).uri.pathSegments.last.replaceAll('.cncanvas', '');

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

    note.title = resolvedTitle;
    _liveNoteMetadata[note.id] = (title: resolvedTitle, filePath: note.filePath);

    if (note.filePath != null) {
      _recordInternalWrite(note.filePath!, note);
      await CncanvasFileService.saveToCnCanvasFile(note, note.filePath!);
      _recordInternalWrite(note.filePath!, note);
    }
    await scanWorkspace();
    notifyListeners();
    notesListNotifier.notifyListeners();
  }

  /// Aninha uma nota arrastada como subnota (filha) de outra nota e remove o arquivo autônomo órfão após confirmação
  Future<void> nestNoteAsSubnote(NoteDocument childNote, NoteDocument parentNote) async {
    if (childNote.id == parentNote.id) return;

    // Se childNote já pertencia a outro pai, desvincula do pai anterior
    final oldParent = findParentNote(childNote.id);
    if (oldParent != null && oldParent.id != parentNote.id) {
      oldParent.children.removeWhere((c) => c.id == childNote.id);
      if (oldParent.filePath != null && File(oldParent.filePath!).existsSync()) {
        try {
          _recordInternalWrite(oldParent.filePath!, oldParent);
          await CncanvasFileService.saveToCnCanvasFile(oldParent, oldParent.filePath!);
          _recordInternalWrite(oldParent.filePath!, oldParent);
        } catch (_) {}
      }
    }

    // Remove child de onde ela estiver na árvore
    _removeNoteFromList(_rootNotes, childNote.id);
    for (final nb in _notebooks) {
      _removeNoteFromList(nb.notes, childNote.id);
    }

    final oldStandalonePath = childNote.filePath;
    childNote.filePath = null;

    // Se já estiver como filha, evita duplicata
    if (!parentNote.children.any((n) => n.id == childNote.id)) {
      parentNote.children.add(childNote);
    }

    if (parentNote.filePath != null) {
      _recordInternalWrite(parentNote.filePath!, parentNote);
      await CncanvasFileService.saveToCnCanvasFile(parentNote, parentNote.filePath!);
      _recordInternalWrite(parentNote.filePath!, parentNote);
      // Remove o arquivo autônomo antigo somente após o pai ter sido salvo atomicamente no disco
      if (oldStandalonePath != null &&
          oldStandalonePath != parentNote.filePath &&
          File(oldStandalonePath).existsSync()) {
        try {
          await File(oldStandalonePath).delete();
        } catch (_) {}
      }
    }
    await scanWorkspace();
    notifyListeners();
    notesListNotifier.notifyListeners();
  }

  /// Localiza a nota pai de uma subnota (se houver)
  NoteDocument? findParentNote(String childId) {
    NoteDocument? search(List<NoteDocument> list) {
      for (final doc in list) {
        if (doc.children.any((c) => c.id == childId)) {
          return doc;
        }
        final deeper = search(doc.children);
        if (deeper != null) return deeper;
      }
      return null;
    }

    final inRoot = search(_rootNotes);
    if (inRoot != null) return inRoot;

    for (final nb in _notebooks) {
      final inNb = search(nb.notes);
      if (inNb != null) return inNb;
    }
    return null;
  }

  /// Promove uma subnota para nota autônoma (independente), salvando-a em arquivo .cncanvas próprio
  /// e removendo-a atomicamente da lista de filhos da nota pai no disco, evitando qualquer duplicação.
  Future<NoteDocument?> promoteSubnote(NoteDocument subnote, {String? targetFolderName}) async {
    final parent = findParentNote(subnote.id);
    if (parent != null) {
      parent.children.removeWhere((c) => c.id == subnote.id);
      if (parent.filePath != null && File(parent.filePath!).existsSync()) {
        try {
          _recordInternalWrite(parent.filePath!, parent);
          await CncanvasFileService.saveToCnCanvasFile(parent, parent.filePath!);
          _recordInternalWrite(parent.filePath!, parent);
        } catch (e) {
          debugPrint('[WorkspaceStorageService] Erro ao salvar nota pai após desaninhamento: $e');
        }
      }
    }

    final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
        ? sanitizeFileSystemName(targetFolderName)
        : null;
    final folder = safeFolder != null
        ? '$_workspacePath/Cadernos/$safeFolder'
        : '$_workspacePath/Cadernos';

    final dir = Directory(folder);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final newFilePath = _resolveUniqueFilePath(folder, subnote.title, ignoreCurrentPath: subnote.filePath);
    subnote.filePath = newFilePath;
    _recordInternalWrite(newFilePath, subnote);
    await CncanvasFileService.saveToCnCanvasFile(subnote, newFilePath);
    _recordInternalWrite(newFilePath, subnote);
    _liveNoteMetadata[subnote.id] = (title: subnote.title, filePath: newFilePath);

    if (targetFolderName != null && targetFolderName.isNotEmpty) {
      final nb = _notebooks.where((n) => n.name == targetFolderName).firstOrNull ?? _notebooks.firstOrNull;
      if (nb != null) {
        nb.notes.removeWhere((n) => n.id == subnote.id);
        nb.notes.add(subnote);
      } else {
        _rootNotes.removeWhere((n) => n.id == subnote.id);
        _rootNotes.add(subnote);
      }
    } else {
      _rootNotes.removeWhere((n) => n.id == subnote.id);
      _rootNotes.add(subnote);
    }

    await scanWorkspace();
    notifyListeners();
    notesListNotifier.notifyListeners();
    return subnote;
  }

  /// Reordena uma nota arrastada para antes ou depois de uma nota de destino
  Future<void> reorderNote(NoteDocument dragged, NoteDocument target, bool before, {String? targetFolderName}) async {
    if (dragged.id == target.id) return;

    // Se a nota arrastada era uma subnota, remove da nota pai e salva o pai
    final parent = findParentNote(dragged.id);
    if (parent != null) {
      parent.children.removeWhere((c) => c.id == dragged.id);
      if (parent.filePath != null && File(parent.filePath!).existsSync()) {
        try {
          _recordInternalWrite(parent.filePath!, parent);
          await CncanvasFileService.saveToCnCanvasFile(parent, parent.filePath!);
          _recordInternalWrite(parent.filePath!, parent);
        } catch (_) {}
      }

      if (dragged.filePath == null || !File(dragged.filePath!).existsSync()) {
        final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
            ? sanitizeFileSystemName(targetFolderName)
            : null;
        final folder = safeFolder != null
            ? '$_workspacePath/Cadernos/$safeFolder'
            : '$_workspacePath/Cadernos';
        final dir = Directory(folder);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final newPath = _resolveUniqueFilePath(folder, dragged.title);
        dragged.filePath = newPath;
        _recordInternalWrite(newPath, dragged);
        await CncanvasFileService.saveToCnCanvasFile(dragged, newPath);
        _recordInternalWrite(newPath, dragged);
        _liveNoteMetadata[dragged.id] = (title: dragged.title, filePath: newPath);
      }
    } else {
      // Primeiro move o arquivo se for para outro caderno
      await moveNoteToNotebook(dragged, targetFolderName);
    }

    // Ajusta a ordem na lista apropriada
    List<NoteDocument> list;
    if (targetFolderName != null && targetFolderName.isNotEmpty) {
      final nb = _notebooks.where((n) => n.name == targetFolderName).firstOrNull ?? _notebooks.firstOrNull;
      list = nb != null ? nb.notes : _rootNotes;
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
    notesListNotifier.notifyListeners();
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

  /// Move uma nota entre cadernos (ou para a raiz de Cadernos/ se targetFolderName for null) sem sobrescrever existentes
  Future<void> moveNoteToNotebook(NoteDocument note, String? targetFolderName) async {
    // Se a nota for uma subnota, promove-a para nota autônoma no caderno ou raiz de destino
    final parent = findParentNote(note.id);
    if (parent != null) {
      await promoteSubnote(note, targetFolderName: targetFolderName);
      return;
    }

    final currentPath = note.filePath;
    if (currentPath == null || !File(currentPath).existsSync()) return;

    final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
        ? sanitizeFileSystemName(targetFolderName)
        : null;
    final targetDir = safeFolder != null
        ? '$_workspacePath/Cadernos/$safeFolder'
        : '$_workspacePath/Cadernos';

    final targetDirPath = Directory(targetDir);
    if (!targetDirPath.existsSync()) {
      targetDirPath.createSync(recursive: true);
    }

    if (File(currentPath).parent.path.replaceAll('\\', '/') == targetDir.replaceAll('\\', '/')) {
      return;
    }

    final newPath = _resolveUniqueFilePath(
      targetDir,
      note.title,
      ignoreCurrentPath: currentPath,
    );
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
      notesListNotifier.notifyListeners();
    }
  }

  /// Abre a nota no navegador web padrão do sistema via HTML autônomo temporário (imune a Command Injection)
  Future<void> openInBrowser(NoteDocument note) async {
    if (note.filePath == null || !File(note.filePath!).existsSync()) {
      await saveNoteNow(note);
    }
    if (note.filePath != null) {
      final safeId = sanitizeFileSystemName(note.id);
      final tempHtmlPath = '${Directory.systemTemp.path}/connotes_web_$safeId.html';
      await CncanvasFileService.exportToHtml(note, tempHtmlPath);

      final absoluteHtmlPath = File(tempHtmlPath).absolute.path;
      if (Platform.isWindows) {
        await Process.run('rundll32.exe', ['url.dll,FileProtocolHandler', absoluteHtmlPath], runInShell: false);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absoluteHtmlPath], runInShell: false);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [absoluteHtmlPath], runInShell: false);
      }
    }
  }

  /// Lixeira Etapa 1: Move a nota fisicamente para a pasta .trash/ sem colidir com arquivos de mesmo nome
  Future<void> moveToTrash(NoteDocument doc) async {
    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      final trashDir = Directory('$_workspacePath/.trash');
      if (!trashDir.existsSync()) {
        trashDir.createSync(recursive: true);
      }
      final trashPath = _resolveUniqueFilePath(
        trashDir.path,
        doc.title,
        ignoreCurrentPath: doc.filePath,
      );
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
    notesListNotifier.notifyListeners();
  }

  /// Lixeira Etapa 2: Restaura uma nota da .trash/ de volta para a pasta de Cadernos sem sobrescrever notas existentes
  Future<void> restoreFromTrash(NoteDocument doc, {String? targetFolderName}) async {
    if (doc.filePath != null && File(doc.filePath!).existsSync()) {
      final safeFolder = targetFolderName != null && targetFolderName.isNotEmpty
          ? sanitizeFileSystemName(targetFolderName)
          : null;
      final targetFolder = safeFolder != null
          ? '$_workspacePath/Cadernos/$safeFolder'
          : '$_workspacePath/Cadernos';
      
      final targetDir = Directory(targetFolder);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final targetPath = _resolveUniqueFilePath(
        targetFolder,
        doc.title,
        ignoreCurrentPath: doc.filePath,
      );
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
    notesListNotifier.notifyListeners();
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
    notesListNotifier.notifyListeners();
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
    notesListNotifier.notifyListeners();
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
