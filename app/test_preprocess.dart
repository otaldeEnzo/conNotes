import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connotes_app/services/ocr_image_preprocessor.dart';
import 'package:connotes_app/services/settings_service.dart';

void main() async {
  final file = File('../Cadernos/Nova Nota 4.cncanvas');
  final content = file.readAsStringSync();
  final start = content.indexOf('<script id="connotes-data" type="application/json">');
  final end = content.indexOf('</script>', start);
  final jsonStr = content.substring(start + '<script id="connotes-data" type="application/json">'.length, end);
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final canvasData = map['canvasData'] as Map<String, dynamic>? ?? {};
  final cards = canvasData['cards'] as List<dynamic>? ?? [];
  
  final mediaCard = cards.firstWhere((c) => c['id'] == 'card_media_1788738910918249_1');
  final mediaData = mediaCard['mediaData'] as String;
  final b64 = mediaData.split(',').last;
  final rawBytes = base64Decode(b64);
  print('Raw bytes length: ${rawBytes.length}');

  try {
    final preprocessed = await OcrImagePreprocessor.prepareImageForOcr(rawBytes);
    print('Preprocessed bytes length: ${preprocessed.length}');
  } catch (e) {
    print('Erro no pre-processamento: $e');
  }
}
