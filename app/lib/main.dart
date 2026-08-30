import 'package:flutter/material.dart';
import 'theme/moscaro_v2_tokens.dart';
import 'theme/moscaro_theme_controller.dart';
import 'services/windows_mime_association_service.dart';
import 'services/stylus_native_channel.dart';
import 'ffi/native_bridge.dart';
import 'widgets/canvas_scaffold.dart';

import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(const ConNotesApp());
}

class ConNotesApp extends StatelessWidget {
  const ConNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MoscaroThemeController.instance,
      builder: (context, _) {
        final isLight = MoscaroTokens.isLight;
        return MaterialApp(
          title: 'conNotes STEM Canvas',
          debugShowCheckedModeBanner: false,
          theme: (isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
            scaffoldBackgroundColor: MoscaroTokens.backgroundDeep,
          ),
          home: const CanvasHomeScreen(),
        );
      },
    );
  }
}
