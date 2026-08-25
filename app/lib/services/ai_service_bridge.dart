import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_provider_models.dart';
import '../widgets/settings_models.dart';
import 'settings_service.dart';

/// Ponte Unificada de IA Multi-Provedor com suporte a Streaming SSE e System Prompts STEM.
class AiServiceBridge {
  static final AiServiceBridge instance = AiServiceBridge._();
  AiServiceBridge._();

  /// Constrói o System Prompt calibrado para ciências exatas e conversação natural humana
  String buildStemSystemPrompt(AppSettingsState settings, {String? scopeContext}) {
    final buffer = StringBuffer();
    buffer.writeln('Você é o assistente inteligente STEM do conNotes. Você ajuda o usuário de forma natural, humana, empática e direta ao ponto.');
    buffer.writeln('');
    buffer.writeln('DIRETRIZES DE COMPORTAMENTO:');
    buffer.writeln('1. Conversação Humana e Natural: Seja amigável, direto e objetivo. Evite respostas engessadas, robóticas ou prolixas.');
    buffer.writeln('2. Saudações e Conversas Simples: Se o usuário enviar ou escrever uma saudação ("Oi", "Olá", "Como vai?", etc.), responda com simpatia e prontidão para ajudar (ex: "Olá! Tudo bem? Como posso te ajudar hoje nos seus estudos ou projetos?").');
    buffer.writeln('3. NUNCA explique como você reconheceu os traços, nem dê definições acadêmicas sobre "Handwriting Recognition" ou o funcionamento do app, a menos que o usuário pergunte explicitamente sobre engenharia de software.');
    buffer.writeln('4. Interpretação Direta: Trate qualquer caligrafia ou desenho selecionado diretamente como a dúvida, pergunta, fórmula ou mensagem do usuário.');
    buffer.writeln('5. Resolução STEM: Para exercícios, provas e cálculos, resolva de forma didática e elegante, usando KaTeX (\$f(x)\$ ou \$\$\\int x dx\$\$).');
    buffer.writeln('6. Callouts: Use callouts (> [!TIP], > [!THEOREM]) somente quando for relevante para enriquecer uma teoria matemática ou física real.');

    if (settings.enableAiMermaidDiagrams) {
      buffer.writeln('7. Diagramas: Gere blocos ```mermaid ... ``` quando o usuário pedir esquemas visuais.');
    }

    if (settings.enableAiSocraticMode) {
      buffer.writeln('8. Modo Socrático: Guie o estudante com dicas passo a passo e perguntas reflexivas em problemas de exatas.');
    }

    buffer.writeln('9. Sugestões de Continuação: Ao final da resposta, inclua 2 ou 3 sugestões curtas de ações ou perguntas de continuação entre colchetes na última linha no formato exato:');
    buffer.writeln('   [SUGESTOES: "⚡ Ação 1", "📐 Ação 2", "📊 Ação 3"]');
    buffer.writeln('   Exemplo para matemática: [SUGESTOES: "⚡ Deduzir passo a passo", "📐 Estruturar em KaTeX", "📊 Esboçar gráfico"]');
    buffer.writeln('   Exemplo para conceitos: [SUGESTOES: "💡 Exemplo prático", "❓ Testar meu conhecimento"]');

    if (scopeContext != null && scopeContext.trim().isNotEmpty) {
      buffer.writeln('\n--- CONTEXTO DO CANVAS ---');
      buffer.writeln(scopeContext);
      buffer.writeln('--- FIM DO CONTEXTO ---\n');
    }

    return buffer.toString();
  }

  /// Retorna a lista de modelos atualmente disponíveis com base nas chaves preenchidas e ativadas
  List<AiModelDefinition> getAvailableModels(AppSettingsState settings) {
    return AiModelDefinition.allModels.where((model) {
      switch (model.provider) {
        case AiProviderType.gemini:
          return settings.enableGemini && _isValidGeminiKey(settings.geminiApiKey);
        case AiProviderType.openAi:
          return settings.enableOpenAi && _isValidOpenAiKey(settings.openAiApiKey);
        case AiProviderType.claude:
          return settings.enableClaude && _isValidClaudeKey(settings.claudeApiKey);
        case AiProviderType.ollama:
          return settings.enableOllama && _isValidOllamaUrl(settings.ollamaEndpointUrl);
      }
    }).toList();
  }

  bool _isValidGeminiKey(String key) => key.trim().startsWith('AIzaSy') && key.trim().length > 20;
  bool _isValidOpenAiKey(String key) => key.trim().startsWith('sk-') && key.trim().length > 20;
  bool _isValidClaudeKey(String key) => key.trim().startsWith('sk-ant-') && key.trim().length > 20;
  bool _isValidOllamaUrl(String url) => url.trim().isNotEmpty && (url.trim().startsWith('http://') || url.trim().startsWith('https://'));

  /// Ponto de entrada unificado para streaming de resposta de qualquer modelo configurado
  Stream<String> streamPrompt({
    required String userPrompt,
    required AiModelDefinition model,
    String? scopeContext,
    String? imageBase64,
    List<String>? imagesBase64,
  }) {
    final settings = SettingsService.instance.settings;
    final systemPrompt = buildStemSystemPrompt(settings, scopeContext: scopeContext);

    final allImages = <String>[];
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      allImages.add(imageBase64);
    }
    if (imagesBase64 != null && imagesBase64.isNotEmpty) {
      for (final img in imagesBase64) {
        if (img.isNotEmpty && !allImages.contains(img)) {
          allImages.add(img);
        }
      }
    }

    switch (model.provider) {
      case AiProviderType.gemini:
        return _streamGemini(userPrompt, model.id, systemPrompt, settings.geminiApiKey, imagesBase64: allImages);
      case AiProviderType.openAi:
        return _streamOpenAi(userPrompt, model.id, systemPrompt, settings.openAiApiKey, imageBase64: allImages.isNotEmpty ? allImages.first : null);
      case AiProviderType.claude:
        return _streamClaude(userPrompt, model.id, systemPrompt, settings.claudeApiKey, imageBase64: allImages.isNotEmpty ? allImages.first : null);
      case AiProviderType.ollama:
        return _streamOllama(userPrompt, model.id, systemPrompt, settings.ollamaEndpointUrl);
    }
  }

  /// Streaming do Google Gemini (com suporte Multimodal a múltiplas imagens e resolução robusta)
  Stream<String> _streamGemini(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String apiKey, {
    List<String>? imagesBase64,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave de API do Gemini não configurada. Insira sua chave nas Configurações.';
      return;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final parts = <Map<String, dynamic>>[];
    if (imagesBase64 != null && imagesBase64.isNotEmpty) {
      for (final img in imagesBase64) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/png',
            'data': img,
          }
        });
      }
    }
    parts.add({'text': userPrompt});

    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 8192,
      }
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = requestBody;

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        String userFriendlyError = 'Não foi possível obter resposta da IA (Código ${response.statusCode}).';
        try {
          final errJson = jsonDecode(errBody) as Map<String, dynamic>;
          final msg = errJson['error']?['message'] as String? ?? '';
          final code = errJson['error']?['code'] ?? response.statusCode;
          final status = (errJson['error']?['status'] as String? ?? '').toUpperCase();

          if (code == 503 || status == 'UNAVAILABLE' || msg.toLowerCase().contains('overloaded') || msg.toLowerCase().contains('traffic')) {
            userFriendlyError = 'O servidor da IA está temporariamente sobrecarregado com alto tráfego. Por favor, tente enviar sua pergunta novamente em alguns instantes.';
          } else if (code == 429 || status == 'RESOURCE_EXHAUSTED' || msg.toLowerCase().contains('quota') || msg.toLowerCase().contains('rate limit')) {
            userFriendlyError = 'Limite de requisições por minuto atingido para sua chave de API. Aguarde alguns segundos antes de reenviar.';
          } else if (code == 404 || status == 'NOT_FOUND' || msg.toLowerCase().contains('not found')) {
            userFriendlyError = 'O modelo "$modelId" está temporariamente indisponível. Experimente selecionar "Gemini 2.5 Flash" na barra de IA.';
          } else if (code == 400 && (msg.toLowerCase().contains('key') || msg.toLowerCase().contains('api_key'))) {
            userFriendlyError = 'Chave de API do Gemini inválida. Por favor, verifique sua chave nas Configurações.';
          } else if (msg.isNotEmpty) {
            userFriendlyError = msg;
          }
        } catch (_) {}
        yield userFriendlyError;
        return;
      }

      int yieldedChunks = 0;
      final lineStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr.isEmpty || dataStr == '[DONE]') continue;
          try {
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            final candidates = json['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final candidateParts = candidates[0]['content']?['parts'] as List<dynamic>?;
              if (candidateParts != null) {
                for (final p in candidateParts) {
                  final text = p['text'] as String? ?? '';
                  if (text.isNotEmpty) {
                    yieldedChunks++;
                    yield text;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (yieldedChunks == 0) {
        yield 'Não houve resposta gerada pelo modelo. Por favor, tente reformular sua pergunta ou reenviar.';
      }
    } catch (e) {
      yield 'Falha na conexão com o Gemini: $e';
    } finally {
      client.close();
    }
  }

  /// Streaming da OpenAI (GPT-4o com suporte Multimodal a imagens)
  Stream<String> _streamOpenAi(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String apiKey, {
    String? imageBase64,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave da OpenAI não configurada nas Configurações.';
      return;
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final dynamic userContent = (imageBase64 != null && imageBase64.isNotEmpty)
        ? [
            {'type': 'text', 'text': userPrompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,$imageBase64'}
            }
          ]
        : userPrompt;

    final requestBody = jsonEncode({
      'model': modelId,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'stream': true,
      'temperature': 0.3,
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = requestBody;

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        yield 'Erro na API da OpenAI (${response.statusCode}): $errBody';
        return;
      }

      String sseBuffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        sseBuffer += chunk;
        while (sseBuffer.contains('\n\n')) {
          final eventEnd = sseBuffer.indexOf('\n\n');
          final event = sseBuffer.substring(0, eventEnd).trim();
          sseBuffer = sseBuffer.substring(eventEnd + 2);

          for (final line in event.split('\n')) {
            final trimmedLine = line.trim();
            if (trimmedLine.startsWith('data: ')) {
              final dataStr = trimmedLine.substring(6).trim();
              if (dataStr == '[DONE]') return;
              if (dataStr.isEmpty) continue;
              try {
                final json = jsonDecode(dataStr) as Map<String, dynamic>;
                final choices = json['choices'] as List<dynamic>?;
                if (choices != null && choices.isNotEmpty) {
                  final delta = choices[0]['delta'] as Map<String, dynamic>?;
                  final text = delta?['content'] as String? ?? '';
                  if (text.isNotEmpty) {
                    yield text;
                  }
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      yield 'Falha na conexão com a OpenAI: $e';
    } finally {
      client.close();
    }
  }

  /// Streaming do Anthropic Claude (com suporte Multimodal a imagens)
  Stream<String> _streamClaude(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String apiKey, {
    String? imageBase64,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave da Anthropic Claude não configurada nas Configurações.';
      return;
    }

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final dynamic userContent = (imageBase64 != null && imageBase64.isNotEmpty)
        ? [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': imageBase64,
              }
            },
            {'type': 'text', 'text': userPrompt}
          ]
        : userPrompt;

    final requestBody = jsonEncode({
      'model': modelId == 'claude-3-5-sonnet' ? 'claude-3-5-sonnet-20241022' : modelId,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userContent}
      ],
      'max_tokens': 4096,
      'stream': true,
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-api-key'] = apiKey
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = requestBody;

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        yield 'Erro na API do Claude (${response.statusCode}): $errBody';
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          try {
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'] as String? ?? '';
              if (text.isNotEmpty) {
                yield text;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      yield 'Falha na conexão com o Claude: $e';
    } finally {
      client.close();
    }
  }

  /// Streaming do Ollama Local (Offline)
  Stream<String> _streamOllama(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String endpointUrl,
  ) async* {
    final cleanUrl = endpointUrl.endsWith('/') ? endpointUrl.substring(0, endpointUrl.length - 1) : endpointUrl;
    final url = Uri.parse('$cleanUrl/api/generate');

    final requestBody = jsonEncode({
      'model': 'llama3', // fallback local
      'prompt': '$systemPrompt\n\nUsuário: $userPrompt\nAssistente:',
      'stream': true,
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = requestBody;

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        yield 'Erro no servidor Ollama local (${response.statusCode}). Certifique-se de que o Ollama está rodando.';
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final text = json['response'] as String? ?? '';
          if (text.isNotEmpty) {
            yield text;
          }
        } catch (_) {}
      }
    } catch (e) {
      yield 'Ollama não encontrado em $endpointUrl. Inicie o Ollama no seu computador.';
    } finally {
      client.close();
    }
  }
}
