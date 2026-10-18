import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_provider_models.dart';
import '../models/ai_message_model.dart';
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

    buffer.writeln('7. Geração Gráfica e Visual (Imagens e Ilustrações):');
    buffer.writeln('   - Quando o usuário pedir para "gerar uma imagem", "desenhar", "ilustrar", "esboçar" ou visualizar um conceito ou problema STEM:');
    buffer.writeln('   - NUNCA diga simplesmente que você "não consegue gerar imagens".');
    buffer.writeln('   - Para fluxos, relações conceituais, topologias e estruturas: gere OBRIGATORIAMENTE um bloco ```mermaid ... ```.');
    buffer.writeln('   - Para figuras geométricas, fios e curvas no espaço/plano, eixos cartesianos, forças, vetores e esquemas físicos: gere OBRIGATORIAMENTE uma ilustração gráfica vetorial completa em bloco ```svg ... ``` com viewBox apropriado (ex: viewBox="0 0 500 350"), linhas nítidas, rótulos de texto explicativos legíveis e contraste moderno. O conNotes renderiza o código SVG nativamente como imagem gráfica.');

    if (settings.enableAiSocraticMode) {
      buffer.writeln('8. Modo Socrático: Guie o estudante com dicas passo a passo e perguntas reflexivas em problemas de exatas.');
    }

    buffer.writeln('9. Sugestões de Continuação: Ao final da resposta, inclua 2 ou 3 sugestões curtas de ações ou perguntas de continuação entre colchetes na última linha no formato exato:');
    buffer.writeln('   [SUGESTOES: "Ação 1", "Ação 2", "Ação 3"]');
    buffer.writeln('   Exemplo para matemática: [SUGESTOES: "Deduzir passo a passo", "Estruturar em KaTeX", "Esboçar gráfico"]');
    buffer.writeln('   Exemplo para conceitos: [SUGESTOES: "Exemplo prático", "Testar meu conhecimento"]');
    buffer.writeln('10. Quebra de Fórmulas Longas: Para equações matemáticas extensas ou deduções com múltiplos passos, use blocos destacados (\$\$...\$\$) organizados com \\begin{aligned} ... \\end{aligned} alinhando nos operadores de igual (&=) com quebras de linha (\\\\). Evite equações excessivamente longas em uma única linha.');
    buffer.writeln('11. Verificação Rigorosa e Imediata de Resultados (Sem Complacência / Anti-Sycophancy): Antes de responder, efetue internamente o cálculo completo com rigor matemático absoluto. NUNCA seja complacente: se houver qualquer erro de cálculo, sinal, limite de integração, simplificação ou raciocínio, o modelo NUNCA deve dizer que o usuário acertou. Se o resultado ou qualquer passagem estiver incorreta ou incompleta, você DEVE OBRIGATORIAMENTE iniciar a resposta declarando de forma direta: "O seu resultado está incorreto" ou "Você errou o cálculo: o valor correto é X", apontando exatamente onde ocorreu o desvio antes de detalhar o passo a passo. Apenas e tão somente se a resolução e o resultado estiverem 100% corretos, declare: "Você acertou! O resultado está correto." Somente após esse veredito inicial apresente a resolução detalhada passo a passo.');
    buffer.writeln('12. Notação Matemática e LaTeX: NUNCA envolva fórmulas, variáveis, expressões ou notações de cálculo em crases de código inline (`...`). Toda e qualquer notação matemática ou de cálculo DEVE ser delimitada por cifrões (\$...\$ para inline ou \$\$...\$\$ para bloco destacado) para compilação nativa pelo KaTeX. NUNCA gere blocos de código ou diagramas vazios.');

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

  /// Filtra e extrai a janela deslizante de até 12 turnos recentes do histórico de conversa
  List<AiMessage> _getSlidingWindow(List<AiMessage>? history, {int maxTurns = 12}) {
    if (history == null || history.isEmpty) return const [];
    final valid = history.where((m) => m.content.trim().isNotEmpty && !m.isStreaming).toList();
    if (valid.length > maxTurns) {
      return valid.sublist(valid.length - maxTurns);
    }
    return valid;
  }

  /// Ponto de entrada unificado para streaming de resposta de qualquer modelo configurado
  Stream<String> streamPrompt({
    required String userPrompt,
    required AiModelDefinition model,
    List<AiMessage>? conversationHistory,
    String? scopeContext,
    String? imageBase64,
    List<String>? imagesBase64,
    String? customSystemPrompt,
    int? maxOutputTokens,
  }) {
    final settings = SettingsService.instance.settings;
    final systemPrompt = customSystemPrompt ?? buildStemSystemPrompt(settings, scopeContext: scopeContext);

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
        return _streamGemini(
          userPrompt,
          model.id,
          systemPrompt,
          settings.geminiApiKey,
          conversationHistory: conversationHistory,
          imagesBase64: allImages,
          maxOutputTokens: maxOutputTokens,
        );
      case AiProviderType.openAi:
        return _streamOpenAi(
          userPrompt,
          model.id,
          systemPrompt,
          settings.openAiApiKey,
          conversationHistory: conversationHistory,
          imageBase64: allImages.isNotEmpty ? allImages.first : null,
          maxOutputTokens: maxOutputTokens,
        );
      case AiProviderType.claude:
        return _streamClaude(
          userPrompt,
          model.id,
          systemPrompt,
          settings.claudeApiKey,
          conversationHistory: conversationHistory,
          imageBase64: allImages.isNotEmpty ? allImages.first : null,
          maxOutputTokens: maxOutputTokens,
        );
      case AiProviderType.ollama:
        return _streamOllama(
          userPrompt,
          model.id,
          systemPrompt,
          settings.ollamaEndpointUrl,
          conversationHistory: conversationHistory,
        );
    }
  }

  /// Sanitiza dados base64 de imagem extraindo o MIME type e removendo headers data URI
  static ({String cleanBase64, String mimeType}) _sanitizeBase64Image(String raw) {
    String cleanBase64 = raw.trim();
    String mimeType = 'image/jpeg';
    if (raw.contains(',')) {
      final split = raw.split(',');
      final header = split[0];
      cleanBase64 = split[1].trim();
      if (header.contains('image/webp')) {
        mimeType = 'image/webp';
      } else if (header.contains('image/png')) {
        mimeType = 'image/png';
      } else if (header.contains('image/gif')) {
        mimeType = 'image/gif';
      }
    }
    return (cleanBase64: cleanBase64, mimeType: mimeType);
  }

  /// Remove chaves de API acidentalmente presentes em mensagens de exceção HTTP/URI
  static String _redactSecrets(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'AIzaSy[A-Za-z0-9_\-]+'), '[REDACTED_GEMINI_KEY]')
        .replaceAll(RegExp(r'sk-[A-Za-z0-9_\-]+'), '[REDACTED_API_KEY]');
  }

  /// Streaming do Google Gemini (com suporte Multimodal a múltiplas imagens e resolução robusta)
  Stream<String> _streamGemini(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String apiKey, {
    List<AiMessage>? conversationHistory,
    List<String>? imagesBase64,
    int? maxOutputTokens,
    bool isFallback = false,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave de API do Gemini não configurada. Insira sua chave nas Configurações.';
      return;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse',
    );

    final window = _getSlidingWindow(conversationHistory, maxTurns: 12);
    final contents = <Map<String, dynamic>>[];

    for (final msg in window) {
      if (msg.role == AiMessageRole.system) continue;
      final role = msg.role == AiMessageRole.user ? 'user' : 'model';
      if (contents.isNotEmpty && contents.last['role'] == role) {
        final partsList = contents.last['parts'] as List<Map<String, dynamic>>;
        partsList.add({'text': msg.content});
      } else {
        contents.add({
          'role': role,
          'parts': <Map<String, dynamic>>[
            {'text': msg.content}
          ],
        });
      }
    }

    while (contents.isNotEmpty && contents.first['role'] == 'model') {
      contents.removeAt(0);
    }

    final currentParts = <Map<String, dynamic>>[];
    if (imagesBase64 != null && imagesBase64.isNotEmpty) {
      for (final img in imagesBase64) {
        final sanitized = _sanitizeBase64Image(img);
        currentParts.add({
          'inlineData': {
            'mimeType': sanitized.mimeType,
            'data': sanitized.cleanBase64,
          }
        });
      }
    }
    currentParts.add({'text': userPrompt});

    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastParts = contents.last['parts'] as List<Map<String, dynamic>>;
      lastParts.addAll(currentParts);
    } else {
      contents.add({
        'role': 'user',
        'parts': currentParts,
      });
    }

    final requestBody = jsonEncode({
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': maxOutputTokens ?? 16384,
        'thinkingConfig': {
          'thinkingBudget': 2048,
        },
      }
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey
      ..body = requestBody;

    final client = http.Client();
    try {
      final response = await client.send(request).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        // Fallback automático transparente dentro do provedor (se não estiver já em fallback)
        if (!isFallback && (response.statusCode == 429 || response.statusCode == 503 || response.statusCode == 404)) {
          final candidateFallbacks = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];
          for (final fbModel in candidateFallbacks) {
            if (fbModel == modelId) continue;
            debugPrint('[AiServiceBridge] Tentando fallback automático para $fbModel devido a status ${response.statusCode} em $modelId...');
            await Future.delayed(const Duration(milliseconds: 300));
            bool succeeded = false;
            final chunkBuffer = StringBuffer();
            await for (final chunk in _streamGemini(
              userPrompt,
              fbModel,
              systemPrompt,
              apiKey,
              conversationHistory: conversationHistory,
              imagesBase64: imagesBase64,
              maxOutputTokens: maxOutputTokens,
              isFallback: true,
            )) {
              if (!chunk.startsWith('Não foi possível') &&
                  !chunk.startsWith('Limite de requisições') &&
                  !chunk.startsWith('O servidor da IA está temporariamente sobrecarregado') &&
                  !chunk.startsWith('O modelo')) {
                succeeded = true;
                chunkBuffer.write(chunk);
                yield chunk;
              }
            }
            if (succeeded && chunkBuffer.isNotEmpty) {
              return;
            }
          }
        }

        final errBody = await response.stream.bytesToString().timeout(const Duration(seconds: 10));
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
            userFriendlyError = _redactSecrets(msg);
          }
        } catch (_) {}
        yield userFriendlyError;
        return;
      }

      int yieldedChunks = 0;
      final lineStream = response.stream
          .timeout(const Duration(seconds: 90))
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr.isEmpty || dataStr == '[DONE]') continue;
          try {
            final json = jsonDecode(dataStr) as Map<String, dynamic>;
            final candidates = json['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates[0] as Map<String, dynamic>;
              final candidateParts = firstCandidate['content']?['parts'] as List<dynamic>?;
              if (candidateParts != null) {
                for (final p in candidateParts) {
                  if (p is Map && p['thought'] == true) continue;
                  final text = p['text'] as String? ?? '';
                  if (text.isNotEmpty) {
                    yieldedChunks++;
                    yield text;
                  }
                }
              }
              final finishReason = firstCandidate['finishReason'] as String?;
              if (finishReason == 'MAX_TOKENS') {
                yield '\n\n*(Resposta pausada pelo limite de tokens da API. Digite "continuar" para ver o restante)*';
              }
            }
          } catch (_) {}
        }
      }

      if (yieldedChunks == 0) {
        yield 'Não houve resposta gerada pelo modelo. Por favor, tente reformular sua pergunta ou reenviar.';
      }
    } on TimeoutException {
      if (!isFallback && (modelId.contains('pro') || modelId.contains('2.5-flash'))) {
        debugPrint('[AiServiceBridge] Timeout com $modelId. Tentando fallback para gemini-2.5-flash-lite...');
        await Future.delayed(const Duration(milliseconds: 300));
        bool succeeded = false;
        final chunkBuffer = StringBuffer();
        await for (final chunk in _streamGemini(
          userPrompt,
          'gemini-2.5-flash-lite',
          systemPrompt,
          apiKey,
          conversationHistory: conversationHistory,
          imagesBase64: imagesBase64,
          maxOutputTokens: maxOutputTokens,
          isFallback: true,
        )) {
          if (!chunk.startsWith('Falha') && !chunk.startsWith('Não foi')) {
            succeeded = true;
            chunkBuffer.write(chunk);
            yield chunk;
          }
        }
        if (succeeded && chunkBuffer.isNotEmpty) {
          return;
        }
      }
      yield 'O servidor da IA demorou muito para responder (tempo limite esgotado). Verifique sua conexão de rede ou tente reenviar.';
    } catch (e) {
      yield 'Falha na conexão com o Gemini: ${_redactSecrets(e)}';
    } finally {
      client.close();
    }
  }

  /// Streaming da OpenAI (GPT-4o / GPT-4o-mini com suporte Multimodal a imagens)
  Stream<String> _streamOpenAi(
    String userPrompt,
    String modelId,
    String systemPrompt,
    String apiKey, {
    List<AiMessage>? conversationHistory,
    String? imageBase64,
    int? maxOutputTokens,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave da OpenAI não configurada nas Configurações.';
      return;
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final dynamic userContent;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final sanitized = _sanitizeBase64Image(imageBase64);
      userContent = [
        {'type': 'text', 'text': userPrompt},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:${sanitized.mimeType};base64,${sanitized.cleanBase64}'}
        }
      ];
    } else {
      userContent = userPrompt;
    }

    final window = _getSlidingWindow(conversationHistory, maxTurns: 12);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in window) {
      final role = switch (msg.role) {
        AiMessageRole.user => 'user',
        AiMessageRole.assistant => 'assistant',
        AiMessageRole.system => 'system',
      };
      messages.add({
        'role': role,
        'content': msg.content,
      });
    }

    messages.add({
      'role': 'user',
      'content': userContent,
    });

    final requestMap = <String, dynamic>{
      'model': modelId,
      'messages': messages,
      'stream': true,
      'temperature': 0.2,
      'max_tokens': (maxOutputTokens != null && maxOutputTokens > 0) ? maxOutputTokens : 8192,
    };

    final requestBody = jsonEncode(requestMap);

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
    List<AiMessage>? conversationHistory,
    String? imageBase64,
    int? maxOutputTokens,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Erro: Chave da Anthropic Claude não configurada nas Configurações.';
      return;
    }

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final dynamic userContent;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final sanitized = _sanitizeBase64Image(imageBase64);
      userContent = [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': sanitized.mimeType,
            'data': sanitized.cleanBase64,
          }
        },
        {'type': 'text', 'text': userPrompt}
      ];
    } else {
      userContent = userPrompt;
    }

    final window = _getSlidingWindow(conversationHistory, maxTurns: 12);
    final messages = <Map<String, dynamic>>[];

    for (final msg in window) {
      if (msg.role == AiMessageRole.system) continue;
      final role = msg.role == AiMessageRole.assistant ? 'assistant' : 'user';
      if (messages.isNotEmpty && messages.last['role'] == role) {
        messages.last['content'] = '${messages.last['content']}\n\n${msg.content}';
      } else {
        messages.add({
          'role': role,
          'content': msg.content,
        });
      }
    }

    while (messages.isNotEmpty && messages.first['role'] == 'assistant') {
      messages.removeAt(0);
    }

    if (messages.isNotEmpty && messages.last['role'] == 'user') {
      final lastContent = messages.last['content'];
      if (userContent is List) {
        messages.last['content'] = [
          {'type': 'text', 'text': lastContent.toString()},
          ...userContent,
        ];
      } else {
        messages.last['content'] = '$lastContent\n\n$userContent';
      }
    } else {
      messages.add({
        'role': 'user',
        'content': userContent,
      });
    }

    final requestBody = jsonEncode({
      'model': modelId == 'claude-3-5-sonnet' ? 'claude-3-5-sonnet-20241022' : modelId,
      'system': systemPrompt,
      'messages': messages,
      'max_tokens': maxOutputTokens ?? 8192,
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
    String endpointUrl, {
    List<AiMessage>? conversationHistory,
  }) async* {
    final cleanUrl = endpointUrl.endsWith('/') ? endpointUrl.substring(0, endpointUrl.length - 1) : endpointUrl;
    final url = Uri.parse('$cleanUrl/api/chat');

    final window = _getSlidingWindow(conversationHistory, maxTurns: 12);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in window) {
      final role = switch (msg.role) {
        AiMessageRole.user => 'user',
        AiMessageRole.assistant => 'assistant',
        AiMessageRole.system => 'system',
      };
      messages.add({
        'role': role,
        'content': msg.content,
      });
    }

    messages.add({
      'role': 'user',
      'content': userPrompt,
    });

    final targetModel = modelId.isNotEmpty && modelId != 'ollama' ? modelId : 'llama3';

    final requestBody = jsonEncode({
      'model': targetModel,
      'messages': messages,
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
          final message = json['message'] as Map<String, dynamic>?;
          final text = (message?['content'] ?? json['response']) as String? ?? '';
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
