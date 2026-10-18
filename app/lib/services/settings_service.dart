import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../widgets/settings_models.dart';

/// Serviço Singleton responsável pela persistência Local-First das configurações do conNotes.
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const String _settingsFileName = 'settings.json';
  AppSettingsState _settings = const AppSettingsState();
  AppSettingsState get settings => _settings;
  AppSettingsState get currentSettings => _settings;
  ChangeNotifier get settingsNotifier => this;

  File _getSettingsFile() {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final sep = Platform.isWindows ? '\\' : '/';
        final dirPath = '$userProfile${sep}Documents${sep}conNotes';
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('$dirPath$sep$_settingsFileName');
      }
    } catch (_) {}
    return File(_settingsFileName);
  }

  File _getSecretsFile() {
    try {
      final appData = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Platform.environment['HOME'];
      if (appData != null && appData.isNotEmpty) {
        final sep = Platform.isWindows ? '\\' : '/';
        final dirPath = Platform.isWindows
            ? '$appData${sep}conNotes'
            : '$appData$sep.config${sep}conNotes';
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('$dirPath${sep}secrets.json');
      }
    } catch (_) {}
    return File('.connotes_secrets.json');
  }

  /// Carrega as configurações do disco ou retorna os valores padrão
  Future<AppSettingsState> loadSettings() async {
    try {
      final file = _getSettingsFile();
      Map<String, dynamic> json = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          json = jsonDecode(content) as Map<String, dynamic>;
        }
      }
      // Carrega chaves de API do armazenamento privado local (fora da pasta compartilhável Documents/conNotes)
      final secretsFile = _getSecretsFile();
      if (await secretsFile.exists()) {
        try {
          final secretsContent = await secretsFile.readAsString();
          if (secretsContent.trim().isNotEmpty) {
            final secretsJson = jsonDecode(secretsContent) as Map<String, dynamic>;
            for (final key in const ['geminiApiKey', 'openAiApiKey', 'claudeApiKey']) {
              final val = secretsJson[key] as String?;
              if (val != null && val.isNotEmpty) {
                json[key] = val;
              }
            }
          }
        } catch (_) {}
      }
      if (json.isNotEmpty) {
        debugPrint('[SettingsService] Configurações carregadas do disco.');
        _settings = AppSettingsState.fromJson(json);
        notifyListeners();
        return _settings;
      }
    } catch (e) {
      debugPrint('[SettingsService] Erro ao carregar configurações: $e');
    }
    _settings = AppSettingsState.defaults();
    notifyListeners();
    return _settings;
  }

  /// Atualiza em memória sem tocar no disco (útil para testes e previews)
  void updateSettingsInMemory(AppSettingsState settings) {
    _settings = settings;
    notifyListeners();
  }

  Future<void>? _saveQueue;

  /// Salva as configurações de forma persistente
  Future<void> updateSettings(AppSettingsState settings) => saveSettings(settings);

  static Future<void> _writeAtomically(File targetFile, String content) async {
    final uniqueTmp = File('${targetFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await uniqueTmp.writeAsString(content, flush: true);
      if (uniqueTmp.existsSync() && uniqueTmp.lengthSync() > 0) {
        bool replaced = false;
        // No Windows, o targetFile pode estar brevemente travado por outro processo ou antivírus
        for (int retry = 0; retry < 6; retry++) {
          try {
            await uniqueTmp.rename(targetFile.path);
            replaced = true;
            break;
          } on FileSystemException {
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
        if (!replaced) {
          await uniqueTmp.copy(targetFile.path);
          try {
            await uniqueTmp.delete();
          } catch (_) {}
        }
      }
    } finally {
      if (uniqueTmp.existsSync()) {
        try {
          await uniqueTmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _performSave(AppSettingsState settings) async {
    try {
      final file = _getSettingsFile();
      final publicJson = Map<String, dynamic>.from(settings.toJson())
        ..remove('geminiApiKey')
        ..remove('openAiApiKey')
        ..remove('claudeApiKey');
      final content = const JsonEncoder.withIndent('  ').convert(publicJson);
      await _writeAtomically(file, content);

      final secretsFile = _getSecretsFile();
      final secretsContent = const JsonEncoder.withIndent('  ').convert({
        'geminiApiKey': settings.geminiApiKey,
        'openAiApiKey': settings.openAiApiKey,
        'claudeApiKey': settings.claudeApiKey,
      });
      await _writeAtomically(secretsFile, secretsContent);
    } catch (e) {
      debugPrint('[SettingsService] Erro ao salvar configurações: $e');
    }
  }

  /// Salva as configurações de forma assíncrona e atômica no disco local (separando chaves de API em AppData)
  Future<void> saveSettings(AppSettingsState settings) {
    _settings = settings;
    notifyListeners();

    final prev = _saveQueue;
    final completer = Completer<void>();
    _saveQueue = completer.future;

    return Future.sync(() async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      try {
        await _performSave(settings);
      } finally {
        completer.complete();
      }
    });
  }
}
