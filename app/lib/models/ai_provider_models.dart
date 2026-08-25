enum AiProviderType {
  gemini,
  openAi,
  claude,
  ollama,
}

enum AiScopeType {
  activeNote,
  currentNotebook,
  allNotes,
}

/// Definição de Modelo de IA suportado no conNotes.
class AiModelDefinition {
  final String id;
  final String displayName;
  final AiProviderType provider;
  final String description;
  final String badge;
  final String contextWindow;
  final bool isLocal;

  const AiModelDefinition({
    required this.id,
    required this.displayName,
    required this.provider,
    required this.description,
    this.badge = '',
    this.contextWindow = '128k',
    this.isLocal = false,
  });

  /// Lista de Modelos STEM Curados Oficiais
  static const List<AiModelDefinition> allModels = [
    // Google Gemini (Endpoints Oficiais Google AI Studio - Agosto 2026)
    AiModelDefinition(
      id: 'gemini-3.7-flash',
      displayName: 'Gemini 3.7 Flash',
      provider: AiProviderType.gemini,
      description: 'Último lançamento: raciocínio agêntico, velocidade e precisão máxima.',
      badge: 'Novo',
      contextWindow: '1M tokens',
    ),
    AiModelDefinition(
      id: 'gemini-3.6-flash',
      displayName: 'Gemini 3.6 Flash',
      provider: AiProviderType.gemini,
      description: 'Ultra velocidade, tarefas agênticas e raciocínio avançado.',
      badge: 'Recomendado',
      contextWindow: '1M tokens',
    ),
    AiModelDefinition(
      id: 'gemini-3.5-flash',
      displayName: 'Gemini 3.5 Flash',
      provider: AiProviderType.gemini,
      description: 'Estável e de alta capacidade para programação e anotações STEM.',
      badge: 'Estável',
      contextWindow: '1M tokens',
    ),
    AiModelDefinition(
      id: 'gemini-3.1-pro-preview',
      displayName: 'Gemini 3.1 Pro',
      provider: AiProviderType.gemini,
      description: 'Máxima inteligência e profundidade para deduções e provas complexas.',
      badge: 'Mais Inteligente',
      contextWindow: '2M tokens',
    ),
    AiModelDefinition(
      id: 'gemini-3.5-flash-lite',
      displayName: 'Gemini 3.5 Flash-Lite',
      provider: AiProviderType.gemini,
      description: 'Baixíssima latência para respostas imediatas e resumos ágeis.',
      badge: 'Ultrarrápido',
      contextWindow: '1M tokens',
    ),

    // OpenAI
    AiModelDefinition(
      id: 'gpt-4o',
      displayName: 'GPT-4o',
      provider: AiProviderType.openAi,
      description: 'Modelo multimodal de alta precisão da OpenAI.',
      badge: 'OpenAI',
      contextWindow: '128k',
    ),
    AiModelDefinition(
      id: 'gpt-4o-mini',
      displayName: 'GPT-4o mini',
      provider: AiProviderType.openAi,
      description: 'Rápido, econômico e eficiente em raciocínio lógico.',
      badge: 'Econômico',
      contextWindow: '128k',
    ),

    // Anthropic Claude
    AiModelDefinition(
      id: 'claude-3-5-sonnet',
      displayName: 'Claude 3.5 Sonnet',
      provider: AiProviderType.claude,
      description: 'Líder em geração de código e explicações estruturadas.',
      badge: 'Claude',
      contextWindow: '200k',
    ),

    // Ollama Local
    AiModelDefinition(
      id: 'ollama-local',
      displayName: 'Ollama Local (Offline)',
      provider: AiProviderType.ollama,
      description: 'Executa modelos locais (DeepSeek-R1, Llama 3, Qwen) 100% offline.',
      badge: 'Local / Offline',
      contextWindow: '32k-128k',
      isLocal: true,
    ),
  ];

  static AiModelDefinition findById(String id) {
    return allModels.firstWhere(
      (m) => m.id == id,
      orElse: () => allModels.first,
    );
  }
}
