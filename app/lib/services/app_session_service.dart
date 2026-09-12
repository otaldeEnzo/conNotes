import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'workspace_storage_service.dart';

/// Modelo de Dados para a Sessão Persistente do conNotes
class AppSessionData {
  final String? lastActiveNoteId;
  final String? lastActiveNotePath;
  final String activeScreen; // 'canvas' ou 'home'
  final List<String> openTabNoteIds;
  final List<String> openTabNotePaths;
  final String? selectedTabNoteId;
  final String? activePenSlotId;
  final DateTime lastUpdated;

  const AppSessionData({
    this.lastActiveNoteId,
    this.lastActiveNotePath,
    this.activeScreen = 'home',
    this.openTabNoteIds = const [],
    this.openTabNotePaths = const [],
    this.selectedTabNoteId,
    this.activePenSlotId,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'lastActiveNoteId': lastActiveNoteId,
    'lastActiveNotePath': lastActiveNotePath,
    'activeScreen': activeScreen,
    'openTabNoteIds': openTabNoteIds,
    'openTabNotePaths': openTabNotePaths,
    'selectedTabNoteId': selectedTabNoteId,
    'activePenSlotId': activePenSlotId,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory AppSessionData.fromJson(Map<String, dynamic> json) {
    return AppSessionData(
      lastActiveNoteId: json['lastActiveNoteId'] as String?,
      lastActiveNotePath: json['lastActiveNotePath'] as String?,
      activeScreen: json['activeScreen'] as String? ?? 'home',
      openTabNoteIds: (json['openTabNoteIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      openTabNotePaths: (json['openTabNotePaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      selectedTabNoteId: json['selectedTabNoteId'] as String?,
      activePenSlotId: json['activePenSlotId'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? (DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Serviço Singleton responsável pela persistência de sessão contínua (abas, última nota, telas)
class AppSessionService extends ChangeNotifier {
  static final AppSessionService instance = AppSessionService._internal();
  AppSessionService._internal();

  static const String _sessionFileName = '.session.json';
  AppSessionData? _currentSession;
  AppSessionData? get currentSession => _currentSession;

  File _getSessionFile() {
    try {
      final base = WorkspaceStorageService.instance.workspacePath.isNotEmpty
          ? WorkspaceStorageService.instance.workspacePath
          : WorkspaceStorageService.getDefaultWorkspacePath();
      final dir = Directory(base);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final sep = Platform.isWindows ? '\\' : '/';
      return File('$base$sep$_sessionFileName');
    } catch (_) {
      return File(_sessionFileName);
    }
  }

  /// Carrega os dados da última sessão do disco
  Future<AppSessionData?> loadSession() async {
    try {
      final file = _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          _currentSession = AppSessionData.fromJson(json);
          notifyListeners();
          return _currentSession;
        }
      }
    } catch (e) {
      debugPrint('[AppSessionService] Erro ao carregar sessão: $e');
    }
    return null;
  }

  /// Salva as informações da sessão de forma não-bloqueante
  Future<void> saveSession({
    String? lastActiveNoteId,
    String? lastActiveNotePath,
    String? activeScreen,
    List<String>? openTabNoteIds,
    List<String>? openTabNotePaths,
    String? selectedTabNoteId,
    String? activePenSlotId,
  }) async {
    final updated = AppSessionData(
      lastActiveNoteId: lastActiveNoteId ?? _currentSession?.lastActiveNoteId,
      lastActiveNotePath: lastActiveNotePath ?? _currentSession?.lastActiveNotePath,
      activeScreen: activeScreen ?? _currentSession?.activeScreen ?? 'home',
      openTabNoteIds: openTabNoteIds ?? _currentSession?.openTabNoteIds ?? const [],
      openTabNotePaths: openTabNotePaths ?? _currentSession?.openTabNotePaths ?? const [],
      selectedTabNoteId: selectedTabNoteId ?? _currentSession?.selectedTabNoteId,
      activePenSlotId: activePenSlotId ?? _currentSession?.activePenSlotId,
      lastUpdated: DateTime.now(),
    );

    _currentSession = updated;
    notifyListeners();

    try {
      final file = _getSessionFile();
      final content = const JsonEncoder.withIndent('  ').convert(updated.toJson());
      await file.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('[AppSessionService] Erro ao salvar sessão: $e');
    }
  }
}
