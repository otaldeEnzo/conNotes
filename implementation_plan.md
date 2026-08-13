# Plano de Desenvolvimento: STEM Canvas Note-Taking & IA System (Native High-Performance)

## 1. Visão Geral do Produto & Solução
Um aplicativo de anotações com **Infinite Canvas** e **Assistência de IA** especialmente otimizado para a área de **EXATAS/STEM** (fórmulas LaTeX, diagramas matemáticos, gráficos, código, anotações manuscritas/desenhos e texto estruturado).

### Resolução do Problema Principal:
- **Zero-Friction Multi-device Sync (Local-First Realtime)**:
  - Sincronização continuada instantânea via WebSockets/WebRTC com CRDTs (Automerge/Yjs em Rust).
  - Mudou no celular (Android/iOS) -> instantaneamente visível no tablet/PC sem necessidade de upload/download manual de arquivos.
  - **Offline-first total**: Funcione perfeitamente offline na faculdade, sincronizando quando houver rede.

---

## 2. Arquitetura Híbrida de Alta Performance (Sem Chromium / Sem Electron)

A arquitetura definitiva escolhida combina o melhor de dois mundos para garantir **60-120+ FPS, resposta instantânea de caneta e o Design System `moscaro-v2`**:

### A. Camada de Fundo & Core (Rust + Wgpu / GPU Pure)
- **Rust (`wgpu` + Shaders WGSL)**:
  - Renderização direta na placa de vídeo via Vulkan / Metal / DirectX 12.
  - Baixíssima latência na captura e desenho de traços de **Ink/Stylus** (caneta).
  - Renderização do **Dot Grid com efeito Glow sob o mouse**, linhas do papel pautado e expressões matemáticas.
  - Engine de sincronização CRDT (Local-First) e persistência de arquivos.

### B. Camada de Interface & UI (`moscaro-v2` em Flutter com Impeller Engine)
- **Flutter + Impeller Graphics Engine**:
  - Compilação nativa para Windows, Android, iOS e macOS.
  - Zero uso de Chromium/Webviews. O motor **Impeller** executa shaders de vidro (*BackdropFilter*) e gradientes Aurora direto na GPU sem engasgos.
  - **Design System `moscaro-v2` via Extensions**: Aplicação universal do estilo visual `moscaro-v2` em qualquer componente (botões, painéis, modais) com uma única extensão/chamada:
    ```dart
    widget.moscaroV2();
    ```

---

### Arquitetura em Camadas
```text
┌─────────────────────────────────────────────────────────────┐
│ Camada UI (Flutter + Impeller Engine - Estilo moscaro-v2)  │
│ [ Pílulas de Ferramentas ]      [ Painel IA com Blur ]      │
├─────────────────────────────────────────────────────────────┤
│ Camada Nativa GPU (Rust + Wgpu / Shaders WGSL - 120 FPS)    │
│ [ Traço da Caneta ]   [ Grid Dot Glow ]   [ Fórmulas STEM ] │
└─────────────────────────────────────────────────────────────┘
```

### B. Especificação Visual Premium & Design System Centralizado (`moscaro-v2`)

Para garantir manutenibilidade e consistência absoluta, criaremos o **Design System `moscaro-v2`**:
- **Estilização Reutilizável (`moscaro-v2`)**: Todos os componentes (botões simples, botões expansíveis, pílulas, modais, cards, caixas de diálogo) herdarão a classe/estilo `moscaro-v2` automaticamente. Não haverá definição manual repetitiva de estilos para novas features.
- **Borda Dinâmica Aurora**: Integrada ao token de foco/seleção do `moscaro-v2`.
- **Efeito Glassmorphism & Blur**: Padrão para todos os containers e pílulas.

### C. Opções de Fundo do Canvas (Configurável pelo Usuário)
O usuário poderá alternar entre 3 opções de fundo (e no futuro carregar fundos personalizados):
1. **Dot Grid (Padrão Stitch)**: Matriz de pontos interativa com efeito de *glow* reativo ao mouse.
2. **Pautado (Lined / Notebook)**: Linhas horizontais discretas e de alta precisão para anotações manuscritas/texto.
3. **Em Branco (Blank Canvas)**: Fundo limpo e minimalista para diagramação livre.

### D. Suporte Completo a Ink & Stylus (Caneta)
- Integração nativa de eventos de ponteiro de alta precisão (`PointerEvents`, pressão, inclinação/tilt, palma rejeitada) para uso com **Apple Pencil**, **Samsung S-Pen**, **Stylus Android/Windows** e mesas digitalizadoras.

---

## 3. Tecnologias Especializadas STEM & Exatas

1. **Fórmulas e Matemática**:
   - Renderizador nativo de equações (KaTeX/Typst Math engine em Rust ou C++).
   - Suporte a entrada por caneta (Ink/Stylus) com suavização de traços acelerada por GPU.
2. **Assistente de IA Integrado (STEM AI Assistant)**:
   - Resolução passo a passo de equações.
   - Explicação de conceitos, física, química, cálculo e álgebra linear.
   - Geração e plotagem de gráficos de funções em tempo real acelerados por GPU.

---

## 4. Etapas de Desenvolvimento Planejadas

### Fase 1: Design System `moscaro-v2` & Engine Canvas (3 Fundos + Aurora + Glow)
- Criação do **Design System `moscaro-v2`** (tokens, botões normais/expansíveis, inputs, pílulas).
- Engine de Canvas com alternância de 3 fundos (Dot Grid com Glow, Pautado, Em Branco).
- Suporte inicial a **Ink & Stylus** para desenho e anotação manual.

### Fase 2: Motor Realtime Multi-dispositivo (Local-First + CRDT Rust)
- Protocolo de sincronização rápida p2p / server relay de ultra-baixa latência.
- Armazenamento SQLite / RocksDB local nativo.

### Fase 3: Renderizador Math/STEM & Traço de Caneta Avançado
- Renderização de matemática (LaTeX) de alta performance.
- Sistema de suavização de traços (Ink vector stabilization).

### Fase 4: Integração do Assistente de IA STEM
- Engine de IA integrada ao canvas com capacidade de ler expressões e gerar gráficos.

