# Sugestões de Evolução e Roadmap do conNotes

Este documento apresenta sugestões estratégicas e técnicas para o desenvolvimento futuro do **conNotes**, divididas por áreas fundamentais do sistema.

---

## 1. Motor Gráfico & GPU (Rust + Wgpu / Performance)

### 1.1 QuadTree / R-Tree Espacial Calculado na GPU via Compute Shader
- **Descrição**: Mover o índice espacial de culling/hit testing das milhares de curvas de tinta e cards para Compute Shaders WGSL no Rust.
- **Benefício**: Canvas infinitos com +200.000 traços renderizam mantendo 120 FPS estáveis sem gargalos na CPU (< 1ms no frame time de culling).

### 1.2 Exportação Vetorial de Alta Fidelidade Direta em Rust (SVG / PDF Nativo)
- **Descrição**: Módulos em Rust para exportar o canvas e traços diretamente para PDF/SVG em threads de background, sem depender do Canvas do Flutter.
- **Benefício**: Evita congelamento da interface durante exportação de cadernos extensos e mantém fidelidade sub-pixel dos traços da caneta digitalizadora.

### 1.3 Suporte Nativo Multiplataforma para Metal (macOS/iOS) e Vulkan (Linux/Android)
- **Descrição**: Expandir o pipeline D3D12/wgpu para bindings nativos de textura compartilhada no macOS (Metal Shared Texture) e Linux/Android (Vulkan/EGL Direct Import).
- **Benefício**: Garantir a mesma baixíssima latência de traço (< 5ms) com Apple Pencil e S-Pen no ecossistema multiplataforma.

---

## 2. Recursos STEM & Anotações Avançadas

### 2.1 Reconhecimento de Matemática Manuscrita para LaTeX (Handwritten Math-to-LaTeX)
- **Descrição**: Integrar modelo local ONNX (ex: `LaTeX-OCR` quantizado) executado via Rust/ONNX Runtime.
- **Benefício**: O usuário escreve uma equação integral/diferencial no canvas, seleciona com o laço de seleção e converte instantaneamente para um card formatado em LaTeX renderizado de forma vetorial.

### 2.2 Plotter de Funções 2D/3D Dinâmico & Interativo
- **Descrição**: Card especializado para plotagem de equações cartesianas $y = f(x)$ e superfícies $z = f(x, y)$ com sliders em tempo real para parâmetros dinâmicos (frequência, amplitude, constante de fase).
- **Benefício**: Permite exploração visual imediata para disciplinas de cálculo, física e engenharia dentro do próprio caderno.

### 2.3 Gestos Inteligentes & Snapping Geométrico para Diagramas STEM
- **Descrição**: Suporte a *Hold-to-Shape* (pressionar e segurar com a caneta ao final do traço para converter em reta, círculo, elipse ou polígono perfeito) e snaps magnéticos automáticos entre conectores para esquemáticos elétricos, diagramas de blocos e fluxogramas.

---

## 3. IA Local-First & Produtividade Inteligente

### 3.1 Busca Semântica RAG Local (Retrieval-Augmented Generation) com Embeddings
- **Descrição**: Indexar automaticamente o conteúdo de texto, notas, PDFs e transcrições OCR em um banco vetorial local (LanceDB / Qdrant embarcado em Rust).
- **Benefício**: Permite fazer perguntas à IA local em linguagem natural, como *"Em qual caderno discutimos o Teorema de Green?"* ou *"Resuma as equações de Maxwell registradas nas notas deste mês"*.

### 3.2 Transcrição de Áudio Sincronizada com Escrita (Audio-to-Ink Sync)
- **Descrição**: Gravação de áudio em background durante aulas/reuniões com o modelo Whisper local, associando carimbos de tempo da fala aos traços desenhados na tela naquele instante.
- **Benefício**: Tocar em qualquer traço ou palavra anotada reproduz o áudio exato capturado naquele segundo da aula.

### 3.3 Geração Automática de Flashcards & Repetição Espaçada
- **Descrição**: Extração automática de definições, teoremas e cards de chamada para gerar decks de flashcards compatíveis com o Anki ou sistema nativo de repetição espaçada.

---

## 4. Colaboração, Sincronização & Persistência

### 4.1 Sincronização P2P Sem Servidor Central (CRDTs em Rust via WebRTC/QUIC)
- **Descrição**: Utilizar CRDTs (*Conflict-free Replicated Data Types*) em Rust (`automerge-rs` ou `y-crdt`) para permitir colaboração em tempo real na mesma rede local (Wi-Fi/LAN) com criptografia ponta a ponta e zero dependência de nuvem de terceiros.

### 4.2 Histórico do Tempo (Time Machine Slider) por Canvas
- **Descrição**: Slider visual Moscaro V2 que permite "rebobinar" a construção do canvas e assistir à evolução da escrita e criação das notas passo a passo.

---

## 5. Design System Moscaro V2 & Experiência de Uso (UX)

### 5.1 Minimapa Navegável Infinito com Preview Translucido
- **Descrição**: Componente de minimapa em pílula Moscaro V2 com brilho Aurora flutuando no canto do canvas, exibindo a visão global da área de trabalho e a caixa do viewport atual para navegação veloz.

### 5.2 Modo Foco Imersivo (Focus Mode) & Ambientes Sonoros Adaptativos
- **Descrição**: Ocultação automática de barras de ferramentas durante a escrita ativa com a stylus e adição de gerador de áudio sintético ambiente (ruído rosa, som de chuva ou ondas binaurais) focado no aprendizado e concentração.

---

## 6. Qualidade de Código, Testes & Infraestrutura

### 6.1 Suíte de Benchmark de Latência e Testes de Carga de Traço (Ink Load Testing)
- **Descrição**: Suíte automatizada de testes no Rust e Flutter simulando a inserção contínua de 100.000 pontos por segundo para medir o *frame time budget* (meta de 8.3ms para 120Hz) e detectar fugas de memória no FFI.
