import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('../Cadernos');
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.cncanvas')) continue;
    final content = file.readAsStringSync();
    final start = content.indexOf('<script id="connotes-data" type="application/json">');
    final end = content.indexOf('</script>', start);
    if (start == -1 || end == -1) continue;
    final jsonStr = content.substring(start + '<script id="connotes-data" type="application/json">'.length, end);
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final canvasData = map['canvasData'] as Map<String, dynamic>? ?? {};
      final cards = canvasData['cards'] as List<dynamic>? ?? [];
      if (cards.isNotEmpty) {
        print('=== Arquivo: ${file.path} (Cards: ${cards.length}) ===');
        for (final c in cards) {
          print('  ID: ${c['id']} | Type: ${c['cardType']} | isProcessing: ${c['isProcessing']} | Title: "${c['title']}" | Content: "${c['content']}"');
        }
      }
    } catch (e) {
      print('Erro ao ler ${file.path}: $e');
    }
  }
}
