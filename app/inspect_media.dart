import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('../Cadernos/Nova Nota 4.cncanvas');
  final content = file.readAsStringSync();
  final start = content.indexOf('<script id="connotes-data" type="application/json">');
  final end = content.indexOf('</script>', start);
  final jsonStr = content.substring(start + '<script id="connotes-data" type="application/json">'.length, end);
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final canvasData = map['canvasData'] as Map<String, dynamic>? ?? {};
  final cards = canvasData['cards'] as List<dynamic>? ?? [];
  for (final c in cards) {
    if (c['cardType'] == 'media') {
      final mediaData = c['mediaData'] as String? ?? '';
      print('Media card ID: ${c['id']}');
      print('mediaData length: ${mediaData.length}');
      print('mediaData prefix: ${mediaData.substring(0, mediaData.length > 50 ? 50 : mediaData.length)}');
    }
  }
}
