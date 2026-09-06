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

  runApp(
    ValueListenableBuilder<Key>(
      valueListenable: rootKeyNotifier,
      builder: (context, key, _) {
        return ConNotesApp(key: key);
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
  bool _isShowingCanvas = false;
  late AnimationController _transitionController;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _openNoteInCanvas(NoteDocument note) {
    setState(() {
      _currentCanvasNote = note;
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
      _isShowingCanvas = true;
    });
    _transitionController.forward();
  }

  void _backToHome() {
    final noteToSummarize = _currentCanvasNote;
    setState(() {
      _isShowingCanvas = false;
    });
    _transitionController.reverse();
    // Dispara a sintetização por IA em background de forma 100% não-bloqueante
    if (noteToSummarize != null) {
      NoteAiSummaryService.instance.summarizeOnClose(noteToSummarize);
    }
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
          home: _isShowingCanvas
              ? CanvasHomeScreen(
                  key: const ValueKey('canvas_home_screen_persistent'),
                  initialNote: _currentCanvasNote,
                  onBackToHome: _backToHome,
                )
              : HomeScaffold(
                  key: const ValueKey('home_scaffold'),
                  onOpenNote: _openNoteInCanvas,
                  onCreateNote: _createAndOpenNewNote,
                ),
        );
      },
    );
  }
}
