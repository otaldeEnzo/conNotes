import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Servico modular dedicado ao pre-processamento de imagens para OCR matematico.
/// 
/// Realiza:
/// 1. Auto-crop inteligente de bordas brancas/transparentes com margem segura.
/// 2. Remocao de marcas d'agua claras e realce de contraste (deixando o fundo 100% branco e os tracos pretos).
/// 3. Redimensionamento sob medida (maxDimension = 800) para garantir que a imagem consuma
///    apenas 1 tile de visao (~258 tokens) nas APIs de visao multimodal (Gemini, OpenAI, Claude).
/// 4. Execucao isolada em background thread (compute/Isolate) sem travar a UI.
class OcrImagePreprocessor {
  OcrImagePreprocessor._();

  static const int defaultMaxDimension = 640;
  static const int paddingPx = 14;

  /// Processa os bytes da imagem em background Isolate.
  static Future<Uint8List> prepareImageForOcr(
    Uint8List rawBytes, {
    int maxDimension = defaultMaxDimension,
  }) async {
    if (rawBytes.isEmpty) return rawBytes;

    try {
      final processedBytes = await compute(_isolatePreprocess, {
        'bytes': rawBytes,
        'maxDimension': maxDimension,
      });
      return processedBytes ?? rawBytes;
    } catch (e) {
      debugPrint('[OcrImagePreprocessor] Falha no pre-processamento: $e. Usando original.');
      return rawBytes;
    }
  }

  /// Logica de processamento executada dentro da Isolate.
  static Uint8List? _isolatePreprocess(Map<String, dynamic> params) {
    final rawBytes = params['bytes'] as Uint8List;
    final maxDim = params['maxDimension'] as int;

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // 1. Auto-crop de bordas brancas/vazias
    final cropped = _autoCropContent(decoded);

    // 2. Realce de contraste e binarizacao suave (elimina marcas d'agua claras)
    final enhanced = _enhanceContrastAndFilterWatermarks(cropped);

    // 3. Redimensionamento para enquadramento em 1 tile de visao (anti-token eater)
    img.Image resized = enhanced;
    if (enhanced.width > maxDim || enhanced.height > maxDim) {
      if (enhanced.width >= enhanced.height) {
        resized = img.copyResize(
          enhanced,
          width: maxDim,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = img.copyResize(
          enhanced,
          height: maxDim,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 4. Codifica em JPEG 85% ultra-rapido (pesa ~40KB em vez de ~600KB do PNG)
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  /// Detecta os limites do conteudo (tinta/simbolos) e recorta as margens excessivas.
  static img.Image _autoCropContent(img.Image src) {
    int minX = src.width;
    int minY = src.height;
    int maxX = -1;
    int maxY = -1;

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final a = pixel.a;
        if (a < 20) continue; // Transparente

        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        // Calculo da luminancia perceptiva padrao (ITU-R BT.601)
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;

        // Se o pixel nao for quase branco (> 238), e considerado traco/conteudo
        if (lum < 238) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // Se nao detectou conteudo ou a imagem inteira for uniforme, retorna original
    if (maxX < minX || maxY < minY) {
      return src;
    }

    // Adiciona margem de seguranca para simbolos matematicos e acentos
    final cropX = math.max(0, minX - paddingPx);
    final cropY = math.max(0, minY - paddingPx);
    final cropW = math.min(src.width - cropX, (maxX - minX + 1) + (paddingPx * 2));
    final cropH = math.min(src.height - cropY, (maxY - minY + 1) + (paddingPx * 2));

    if (cropW <= 0 || cropH <= 0) return src;

    return img.copyCrop(
      src,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );
  }

  /// Converte para tons de cinza e expande a faixa dinamica:
  /// Clarea marcas d'agua fracas e fundos claros para branco puro (255)
  /// e escurece os tracos das formulas para preto/cinza escuro, facilitando o OCR.
  static img.Image _enhanceContrastAndFilterWatermarks(img.Image src) {
    final gray = img.grayscale(src);

    // Ajusta cada pixel:
    // Pixels com lum > 200 (marcas d'agua claras, cinzas fracos) sao jogados para 255 (branco)
    // Pixels com lum <= 170 sao puxados para escuro com alto contraste
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final r = pixel.r;

        num newColor;
        if (r >= 210) {
          newColor = 255; // Elimina fundo e marcas d'agua cinzas claras
        } else if (r <= 120) {
          newColor = 0; // Tracos pretos solidos
        } else {
          // Remapeia a transicao de forma acentuada
          final normalized = (r - 120) / (210 - 120);
          newColor = (normalized * 255).clamp(0, 255);
        }

        gray.setPixelRgba(x, y, newColor, newColor, newColor, 255);
      }
    }

    return gray;
  }
}
