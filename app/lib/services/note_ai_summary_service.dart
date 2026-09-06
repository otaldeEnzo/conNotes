import 'dart:async';
import 'package:flutter/foundation.dart';
import '../widgets/note_models.dart';
import 'ai_service_bridge.dart';
import 'settings_service.dart';
import 'workspace_storage_service.dart';

/// Serviço inteligente responsável pela geração assíncrona de Resumos por IA / OCR de notas.
///
/// Políticas de Execução:
/// 1. NUNCA disparado pelo autosave contínuo (zero sobrecarga de IA enquanto o usuário escreve).
/// 2. Disparado automaticamente de forma assíncrona ao fechar/sair da nota (onBackToHome).
/// 3. Disparado sob demanda pelo usuário (menu de contexto da nota).
class NoteAiSummaryService extends ChangeNotifier {
  static final NoteAiSummaryService instance = NoteAiSummaryService._();
  NoteAiSummaryService._();

  final Set<String> _processingNoteIds = {};

  /// Retorna se uma nota específica está tendo seu resumo gerado no momento
  bool isProcessing(String noteId) => _processingNoteIds.contains(noteId);

  /// Disparado automaticamente ao fechar ou sair de uma nota.
  /// Só executa se a nota tiver conteúdo relevante e não tiver sido resumida após as últimas alterações.
  Future<void> summarizeOnClose(NoteDocument? note) async {
    if (note == null) return;
    
    // Se a IA não estiver ativada nas configurações, ignorar
    final settings = SettingsService.instance.settings;
    if (!settings.enableGemini && !settings.enableOpenAi && !settings.enableClaude && !settings.enableOllama) {
      return;
    }

    // Se já estiver gerando para esta nota, evitar duplicação
    if (_processingNoteIds.contains(note.id)) return;

    // Verificar se a nota tem conteúdo suficiente
    final hasContent = note.cards.isNotEmpty || note.strokes.length >= 5;
    if (!hasContent) return;

    // Se o resumo existente já é mais recente que a última alteração relevante, não refazer
    if (note.aiSummary != null && 
        note.summaryUpdatedAt != null && 
        note.summaryUpdatedAt!.isAfter(note.updatedAt)) {
      return;
    }

    await _generateSummaryInternal(note);
  }

  /// Força a geração ou regeneração de resumo sob demanda pelo usuário (ex: teste ou clique nos 3 pontinhos)
  Future<void> forceSummarize(NoteDocument note) async {
    if (_processingNoteIds.contains(note.id)) return;
    await _generateSummaryInternal(note);
  }

  Future<void> _generateSummaryInternal(NoteDocument note) async {
    _processingNoteIds.add(note.id);
    notifyListeners();

    try {
      final settings = SettingsService.instance.settings;
      final availableModels = AiServiceBridge.instance.getAvailableModels(settings);

      // 1. Extrair conteúdo textual e estrutural dos cartões STEM
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('Você é um assistente acadêmico especialista em sintetizar notas de estudo e pesquisa.');
      promptBuffer.writeln('Título da nota: "${note.title}"');

      if (note.cards.isNotEmpty) {
        promptBuffer.writeln('\nConteúdo dos Blocos de Estudo encontrados:');
        for (final card in note.cards) {
          final content = card.content.trim();
          if (content.isNotEmpty) {
            promptBuffer.writeln('- ${card.title}: $content');
          }
        }
      }

      if (note.tags.isNotEmpty) {
        promptBuffer.writeln('\nDisciplinas/Tags associadas: ${note.tags.join(", ")}');
      }

      promptBuffer.writeln('\nDiretrizes Obrigatórias:');
      promptBuffer.writeln('1. O usuário quer saber DO QUE a nota trata (tema, assunto, conceitos-chave, equações ou tópicos de estudo).');
      promptBuffer.writeln('2. NUNCA mencione contagem de traços, número de blocos, linhas de tinta ou detalhes técnicos de desenho (proibido falar "X traços", "desenhos livres", "diagrama com traços", etc.).');
      promptBuffer.writeln('3. Escreva um resumo completo, fluido e conciso em português (cerca de 25 a 45 palavras), sem reticências no final e sem introduções genéricas como "Esta nota trata de...".');

      if (availableModels.isEmpty) {
        // Fallback local caso nenhuma chave de API esteja configurada
        final fallback = _generateLocalHeuristicSummary(note);
        note.aiSummary = fallback;
        note.summaryUpdatedAt = DateTime.now();
        await WorkspaceStorageService.instance.saveNoteNow(note);
        return;
      }

      // 2. Usar o modelo preferido configurado ou o primeiro disponível
      final preferredModelId = settings.activeAiModelId;
      final targetModel = availableModels.firstWhere(
        (m) => m.id == preferredModelId,
        orElse: () => availableModels.first,
      );

      final stream = AiServiceBridge.instance.streamPrompt(
        userPrompt: promptBuffer.toString(),
        model: targetModel,
      );

      final fullResponseBuffer = StringBuffer();
      await for (final chunk in stream) {
        fullResponseBuffer.write(chunk);
      }

      var cleanSummary = fullResponseBuffer.toString().trim();
      
      // Limpar blocos de sugestões que o assistente STEM possa ter incluído
      if (cleanSummary.contains('[SUGESTOES:')) {
        cleanSummary = cleanSummary.split('[SUGESTOES:').first.trim();
      }

      // Remover eventuais aspas extras ou reticências finais da IA
      if (cleanSummary.startsWith('"') && cleanSummary.endsWith('"')) {
        cleanSummary = cleanSummary.substring(1, cleanSummary.length - 1).trim();
      }
      while (cleanSummary.endsWith('...') || cleanSummary.endsWith('..') || cleanSummary.endsWith('.')) {
        if (cleanSummary.endsWith('...')) {
          cleanSummary = cleanSummary.substring(0, cleanSummary.length - 3).trim();
        } else if (cleanSummary.endsWith('..')) {
          cleanSummary = cleanSummary.substring(0, cleanSummary.length - 2).trim();
        } else {
          break; // Deixar um único ponto final válido
        }
      }

      final lower = cleanSummary.toLowerCase();
      final isErrorResponse = cleanSummary.isEmpty ||
          lower.startsWith('erro:') ||
          lower.contains('temporariamente sobrecarregado') ||
          lower.contains('limite de requisições') ||
          lower.contains('não foi possível obter resposta') ||
          lower.contains('chave de api do gemini inválida') ||
          lower.contains('está temporariamente indisponível');

      if (!isErrorResponse) {
        note.aiSummary = cleanSummary;
        note.summaryUpdatedAt = DateTime.now();
        await WorkspaceStorageService.instance.saveNoteNow(note);
      }
    } catch (e) {
      debugPrint('[NoteAiSummaryService] Erro ao sintetizar nota ${note.id}: $e');
    } finally {
      _processingNoteIds.remove(note.id);
      notifyListeners();
    }
  }

  String _generateLocalHeuristicSummary(NoteDocument note) {
    if (note.cards.isNotEmpty) {
      final textSnippets = <String>[];
      for (final card in note.cards) {
        final text = card.content.replaceAll('\n', ' ').trim();
        if (text.isNotEmpty) {
          textSnippets.add(text);
        }
      }
      if (textSnippets.isNotEmpty) {
        final joined = textSnippets.join(' • ');
        return joined.length > 130 ? '${joined.substring(0, 127).trimRight()}...' : joined;
      }
    }

    final tagText = note.tags.isNotEmpty ? note.tags.first : 'Estudos Gerais';
    if (note.strokes.isNotEmpty) {
      return 'Registro visual e esquemas temáticos em $tagText, prontos para desenvolvimento e formulação.';
    }
    return 'Espaço de estudo em $tagText pronto para formulações, esquemas conceituais e resolução de problemas.';
  }
}
