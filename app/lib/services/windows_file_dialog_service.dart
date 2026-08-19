import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Serviço Especializado em Diálogos Nativos de Arquivos e Pastas para Windows.
class WindowsFileDialogService {
  WindowsFileDialogService._();

  static bool _isPicking = false;

  /// Abre a janela nativa do Windows Explorer para selecionar uma imagem (.png, .jpg, .jpeg, .webp, .bmp)
  static Future<String?> pickImageFile() async {
    if (_isPicking) return null;
    _isPicking = true;
    try {
      // 1. Tentar via FilePicker do Flutter
      final List<PlatformFile>? files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        dialogTitle: 'Selecionar Imagem de Fundo STEM',
      );
      if (files != null && files.isNotEmpty && files.first.path != null) {
        final path = files.first.path!;
        if (File(path).existsSync()) {
          return path;
        }
      }
      if (files == null || files.isEmpty) {
        return null;
      }
    } catch (e) {
      // 2. Fallback Nativo do Windows via Processo PowerShell Forms somente se o plugin falhar
      if (Platform.isWindows) {
        try {
          final result = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            "Add-Type -AssemblyName System.Windows.Forms; \$d = New-Object System.Windows.Forms.OpenFileDialog; \$d.Title = 'Selecionar Imagem de Fundo STEM'; \$d.Filter = 'Imagens (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|Todos (*.*)|*.*'; \$res = \$d.ShowDialog(); if (\$res -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output \$d.FileName }",
          ]);
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty && File(path).existsSync()) {
            return path;
          }
        } catch (_) {}
      }
    } finally {
      _isPicking = false;
    }

    return null;
  }

  /// Abre a janela nativa para selecionar uma pasta no Windows
  static Future<String?> pickDirectory({String dialogTitle = 'Selecionar Pasta de Cadernos do conNotes'}) async {
    if (_isPicking) return null;
    _isPicking = true;
    try {
      final String? selectedPath = await FilePickerPlatform.instance.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
      if (selectedPath != null && selectedPath.isNotEmpty && Directory(selectedPath).existsSync()) {
        return selectedPath;
      }
      if (selectedPath == null || selectedPath.isEmpty) {
        return null;
      }
    } catch (e) {
      if (Platform.isWindows) {
        try {
          final result = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            "Add-Type -AssemblyName System.Windows.Forms; \$d = New-Object System.Windows.Forms.FolderBrowserDialog; \$d.Description = '$dialogTitle'; \$d.ShowNewFolderButton = \$true; \$res = \$d.ShowDialog(); if (\$res -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output \$d.SelectedPath }",
          ]);
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty && Directory(path).existsSync()) {
            return path;
          }
        } catch (_) {}
      }
    } finally {
      _isPicking = false;
    }

    return null;
  }
}
