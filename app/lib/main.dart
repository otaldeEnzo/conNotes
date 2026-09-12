import 'dart:ui';
import 'package:flutter/material.dart';
import 'theme/moscaro_v2_tokens.dart';
import 'theme/moscaro_theme_controller.dart';
import 'services/windows_mime_association_service.dart';
import 'services/stylus_native_channel.dart';
import 'ffi/native_bridge.dart';
import 'widgets/canvas_scaffold.dart';
import 'widgets/home/home_scaffold.dart';
import 'widgets/note_models.dart';
import 'services/workspace_storage_service.dart';
import 'services/settings_service.dart';
import 'services/note_ai_summary_service.dart';
import 'services/app_session_service.dart';
import 'widgets/settings_models.dart';

import 'package:flutter/services.dart';
import 'services/diagnostics_override_controller.dart';
import 'services/performance_telemetry_controller.dart';
import 'widgets/debug/performance_debug_hud.dart';
import 'widgets/debug/performance_diagnostics_modal.dart';

final ValueNotifier<Key> rootKeyNotifier = ValueNotifier(UniqueKey());
final ValueNotifier<bool> performanceOverlayNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceTelemetryController.instance.initialize();
  WindowsMimeAssociationService.registerMimeAssociation();
  StylusNativeChannel.instance.initialize();
  final isRustReady = ConnotesNativeBridge.instance.isAvailable;
  debugPrint('[ConNotes] Motor Rust Core inicializado: $isRustReady');

  final savedSettings = await SettingsService.instance.loadSettings();
  MoscaroTokens.blurSigma = savedSettings.blurSigma;
  MoscaroThemeController.instance.initialize(
    themeId: savedSettings.activeThemeId,
    bgModeId: savedSettings.customBgMode,
    customSolidHex: savedSettings.customBgColorHex,
    customGradStartHex: savedSettings.customGradStartHex,
    customGradEndHex: savedSettings.customGradEndHex,
    textureId: savedSettings.customTextureType,
    imagePath: savedSettings.customImagePath,
    imageOpacity: savedSettings.customImageOpacity,
    customThemes: savedSettings.customThemes,
  );

  await WorkspaceStorageService.instance.initialize(
    customPath: savedSettings.workspaceDirectoryPath,
  );

  await AppSessionService.instance.loadSession();

  runApp(
    ValueListenableBuilder<Key>(
      valueListenable: rootKeyNotifier,
      builder: (context, key, _) {
        return ExcludeSemantics(
          child: ConNotesApp(key: key),
        );
      },
    ),
  );
}


class ConNotesApp extends StatefulWidget {
  const ConNotesApp({super.key});

  @override
  State<ConNotesApp> createState() => _ConNotesAppState();
}

class _ConNotesAppState extends State<ConNotesApp> with SingleTickerProviderStateMixin {
  NoteDocument? _currentCanvasNote;
  List<String>? _initialOpenTabIds;
  bool _isShowingCanvas = false;
  late AnimationController _transitionController;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _restoreStartupSession();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        await WorkspaceStorageService.instance.flushPendingSaves();
        return AppExitResponse.exit;
      },
      onHide: () {
        WorkspaceStorageService.instance.flushPendingSaves();
      },
      onPause: () {
        WorkspaceStorageService.instance.flushPendingSaves();
      },
    );
  }

  void _restoreStartupSession() {
    final settings = SettingsService.instance.currentSettings;
    if (settings.startupBehavior != AppStartupBehavior.lastOpenedNote) {
      return;
    }

    final session = AppSessionService.instance.currentSession;
    if (session == null) return;

    final allNotes = WorkspaceStorageService.instance.allNotes;
    NoteDocument? targetNote;

    final targetId = session.selectedTabNoteId ?? session.lastActiveNoteId;
    if (targetId != null && allNotes.isNotEmpty) {
      targetNote = allNotes.cast<NoteDocument?>().firstWhere(
        (n) => n?.id == targetId,
        orElse: () => null,
      );
    }

    if (targetNote == null && allNotes.isNotEmpty && session.openTabNoteIds.isNotEmpty) {
      for (final tabId in session.openTabNoteIds) {
        final match = allNotes.cast<NoteDocument?>().firstWhere((n) => n?.id == tabId, orElse: () => null);
        if (match != null) {
          targetNote = match;
          break;
        }
      }
    }

    if (targetNote != null) {
      _currentCanvasNote = targetNote;
      _initialOpenTabIds = session.openTabNoteIds;
      _isShowingCanvas = true;
      _transitionController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _openNoteInCanvas(NoteDocument note) {
    setState(() {
      _currentCanvasNote = note;
      final currentOpenIds = _initialOpenTabIds ?? AppSessionService.instance.currentSession?.openTabNoteIds ?? [];
      final updatedList = List<String>.from(currentOpenIds);
      if (!updatedList.contains(note.id)) {
        updatedList.add(note.id);
      }
      _initialOpenTabIds = updatedList;
      _isShowingCanvas = true;
    });
    _transitionController.forward();
  }

  void _createAndOpenNewNote() async {
    final newNote = await WorkspaceStorageService.instance.createNote(
      title: 'Nota ${WorkspaceStorageService.instance.allNotes.length + 1}',
    );
    setState(() {
      _currentCanvasNote = newNote;
      final currentOpenIds = _initialOpenTabIds ?? AppSessionService.instance.currentSession?.openTabNoteIds ?? [];
      final updatedList = List<String>.from(currentOpenIds);
      if (!updatedList.contains(newNote.id)) {
        updatedList.add(newNote.id);
      }
      _initialOpenTabIds = updatedList;
      _isShowingCanvas = true;
    });
    _transitionController.forward();
  }

  void _backToHome([List<String>? activeTabIds]) {
    final noteToSummarize = _currentCanvasNote;
    setState(() {
      if (activeTabIds != null && activeTabIds.isNotEmpty) {
        _initialOpenTabIds = List<String>.from(activeTabIds);
      }
      _isShowingCanvas = false;
    });
    _transitionController.reverse();
    // Dispara a sintetização por IA em background de forma 100% não-bloqueante
    if (noteToSummarize != null) {
      NoteAiSummaryService.instance.summarizeOnClose(noteToSummarize);
    }
    AppSessionService.instance.saveSession(
      activeScreen: 'home',
      openTabNoteIds: _initialOpenTabIds,
      selectedTabNoteId: _currentCanvasNote?.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MoscaroThemeController.instance,
        DiagnosticsOverrideController.instance,
        performanceOverlayNotifier,
      ]),
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        final diag = DiagnosticsOverrideController.instance;

        return MaterialApp(
          title: 'conNotes STEM Canvas',
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: diag.showNativeOverlay || performanceOverlayNotifier.value,
          theme: (isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
            scaffoldBackgroundColor: MoscaroTokens.backgroundDeep,
          ),
          builder: (context, child) {
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.f12): () {
                  diag.cycleHudMode();
                },
              },
              child: Focus(
                autofocus: true,
                child: Stack(
                  children: [
                    if (child != null) child,
                    const PerformanceDebugHud(),
                    const PerformanceDiagnosticsModal(),
                  ],
                ),
              ),
            );
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: _isShowingCanvas
                ? CanvasHomeScreen(
                    key: const ValueKey('canvas_home_screen_persistent'),
                    initialNote: _currentCanvasNote,
                    initialOpenNoteIds: _initialOpenTabIds,
                    onBackToHome: _backToHome,
                  )
                : HomeScaffold(
                    key: const ValueKey('home_scaffold'),
                    onOpenNote: _openNoteInCanvas,
                    onCreateNote: _createAndOpenNewNote,
                  ),
          ),
        );
      },
    );
  }
}
