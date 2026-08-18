# Regras de Desenvolvimento do Projeto (conNotes)

## 1. Design System Centralizado `moscaro-v2`
- **Generalização de Estilo**: Nunca defina propriedades visuais manualmente para componentes individuais de forma repetitiva.
- **Assinatura Universal**: Todo novo elemento de interface (botões normais, botões expansíveis, pílulas de ferramentas, caixas de diálogo, modais, cards, etc) DEVE utilizar a extensão/encapsulador `.moscaroV2()` (ou token equivalente do design system).
- **Características do `moscaro-v2`**:
  - Efeito Glassmorphism com desfoque de fundo limpo (`BackdropFilter`).
  - Bordas finas com brilho sutil e opção de borda animada gradiente estilo **Aurora**.
  - Cantos arredondados e paleta escura profunda inspirada no Google Stitch (`#0d0e12` / `#0a0b0d`).

## 2. Uso Estrito de Ícones SVG (Sem Emojis)
- **PROIBIDO O USO DE EMOJIS**: NENHUMA interface, botão, aba, card ou elemento visual deve utilizar caracteres emoji (ex: 🚀, 📝, 💡).
- **Uso Exclusivo de Ícones SVG**: Todos os ícones do sistema devem ser vetores SVG padronizados, limpos, consistentes e otimizados, garantindo um visual profissional, elegante e moderno.

## 3. Arquitetura & Performance Nativa
- **Zero Chromium / Zero Electron**: O programa NUNCA rodará sobre Electron ou navegadores pesados baseados em Chromium.
- **Arquitetura Híbrida**:
  - **Camada de Fundo/Canvas**: Escrita em **Rust + Wgpu** (Vulkan, Metal, DirectX 12) rodando em Shaders nativos na GPU para suporte a baixa latência de Stylus/Ink e 60-120+ FPS.
  - **Camada de Interface (UI)**: Desenvolvida em **Flutter com Impeller Engine**, garantindo compilação nativa multiplataforma e execução suave de shaders.

## 4. Canvas & Experiência de Anotação STEM
- **Tipos de Fundo**: O sistema deve permitir a alternância imediata entre:
  1. *Dot Grid* com efeito de *glow* reativo ao ponteiro do mouse.
  2. *Pautado* (linhas horizontais para cadernos/anotações).
  3. *Em Branco*.
- **Suporte Nativo a Stylus/Ink**: Detecção de pressão, inclinação (tilt) e rejeição de palma para canetas digitalizadoras (Apple Pencil, S-Pen, etc.).
- **Sincronização Continuada (Local-First)**: Troca instantânea de estado entre dispositivos sem exigir ações manuais de "enviar/baixar arquivo".

## 5. Regras de Processo & Arquitetura de Código
- **Programação Modular (1 Componente por Arquivo)**: O código deve ser estritamente modular. Cada componente visual, widget, model ou serviço DEVE residir em seu próprio arquivo isolado e focado (ex: `moscaro_button.dart`, `aurora_border_painter.dart`, `canvas_dot_grid.dart`), evitando arquivos monolíticos ou misturas de componentes em um único arquivo.
- **Nomenclatura de Arquivos de Plano por Fase**: Cada nova fase terá o seu próprio arquivo de plano dedicado nomeado especificamente (ex: `fase1_implementation_plan.md`), preservando o plano mestre original em `implementation_plan.md`.


