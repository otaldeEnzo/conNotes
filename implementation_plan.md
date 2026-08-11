# 📘 Especificação Mestre de Funcionalidades: ConnectedNotes (Documentação de Reescrita 100%)

Esta documentação detalha **todas as funcionalidades, comportamentos, ferramentas, motores de cálculo e regras de interface** do ConnectedNotes. Ela serve como guia definitivo para a reescrita do software do zero sem nenhuma perda de recursos.

---

## 🏛️ PILAR 1: Canvas Infinito & Câmera 2D

### 1.1 Sistema de Câmera 2D
- **Pan (Deslocamento com Limites Superior e Esquerdo)**:
  - Ativado por **botão do meio do mouse (Scroll Click)** ou **Alt + Botão Esquerdo**.
  - Suporte a gesto de 2 dedos em Touchpads / Telas Touch.
  - **Limitação de Borda**: O canvas é limitado superiormente ($y \ge 0$) e na lateral esquerda ($x \ge 0$), expandindo de forma infinita apenas para a direita ($x \to +\infty$) e para baixo ($y \to +\infty$).
- **Zoom Infinito Ancorado**:
  - Intervalo de escala de **5% (0.05x)** até **500% (5.00x)**.
  - O ponto de ancoragem do zoom é estritamente a posição atual do ponteiro do mouse (`cursor_pos`).
  - Suporte a atalhos numéricos (`Ctrl + 0` para resetar zoom em 100%, `Ctrl + +` / `Ctrl + -`).

### 1.2 Grid de Fundo & Modos de Visualização
- **Grid de Pontos (Dot Grid)**:
  - Matriz de pontos com espaçamento dinâmico (40px base) que escala suavemente com o zoom.
  - Ocorre um *fade-out* automático quando o zoom cai abaixo de 20% para evitar ruído visual.
- **Modos de Papel**:
  - **Pontilhado (Default)**
  - **Quadriculado (Grid de Linhas)**
  - **Pautado (Linhas de Caderno)**
  - **Isométrico (Grid de Triângulos para Desenho Técnico/Engenharia)**
  - **Liso (Sem grid)**
- **Tema Visual**:
  - Modos **Dark** (Fundo `#0a0d14`), **Light** (Fundo `#f8fafc`), **Nord**, **Gruvbox**, **Dracula** e **Midnight**.

---

## 🧮 PILAR 2: Tipos de Blocos Interativos & Computacionais

Cada bloco no Canvas é um container flutuante de alta performance com título editável, indicador de cor do tipo, botão de fechar, arraste pelo cabeçalho e redimensionamento dinâmico.

### 2.1 Bloco de Texto Rico (Rich Text / Note Block)
- Editor WYSIWYG completo com suporte a formatação rápida.
- **Formatação de Texto**: Negrito, Itálico, Sublinhado, Tachado, Código inline.
- **Títulos**: H1, H2, H3.
- **Listas**: Listas com marcadores, listas numeradas, listas de tarefas com checkbox.
- **Blocos de Citação & Highlight**: Destaques coloridos de texto.
- **Auto-conversão de Markdown**: Digitar `# ` vira H1, `* ` vira lista, ```` ``` ```` vira código.

### 2.2 Bloco de Matemática & Equações LaTeX
- Editor de equações em formato **LaTeX / KaTeX**.
- Renderização matemática vetorial cristalina de alta resolução.
- **Suporte a Símbolos Avançados**: Matrizes, Integrais duplas/triplas, Somatórios, Limites, Vetores, Letras Gregas, Frações compostas.
- **Omnibar de Símbolos Rápida**: Palette de atalhos matemáticos comuns no topo do bloco.
- **Conversão Automática de Texto em Equação** via serviço de IA/Reconhecimento.

### 2.3 Bloco de Código Interactive (JS / Python Sandbox)
- **Editor de Código com Syntax Highlighting** (Suporte a JavaScript e Python).
- **Avaliador Python Local & Remoto**:
  - Execução local via **Pyodide WebAssembly Worker** no navegador (sem necessidade de servidor).
  - Suporte a execução remota via sincronização com kernel do **Google Colab / Jupyter**.
  - Suporte a bibliotecas científicas: `numpy`, `scipy`, `matplotlib`, `sympy`.
- **Avaliador JavaScript Nativo**:
  - Execução síncrona com interceptação de `console.log` e suporte a desenho interativo via container DOM `canvas 2d`.
- **Abas de Saída**: Alternância entre aba **Código** e aba **Saída de Terminal / Gráficos Matplotlib**.
- **Linter Integrado**: Análise estática de erros de sintaxe com botão de auto-correção.

### 2.4 Bloco GeoGebra (Geometria Dinâmica & Gráficos 3D)
- Applet interativo completo do GeoGebra incorporado.
- Alternância entre **Geometria 2D**, **Álgebra**, **CAS (Computação Algébrica)** e **Gráficos 3D**.
- Redimensionamento suave sem distorção de aspecto do applet.

### 2.5 Visualizadores Especiais STEM (CN Compute Visualizers)
- **Linear Transform Block**: Visualizador vetorial interativo de transformações lineares $y = A \cdot x$ com matrizes $2\times2$.
- **Taylor Series Visualizer**: Gráfico interativo comparando uma função $f(x)$ com sua aproximação em Séries de Taylor até ordem $N$.
- **Vector Field Visualizer**: Campo vetorial 2D $\vec{F}(x,y) = (P(x,y), Q(x,y))$ com linhas de fluxo.
- **Phase Portrait Visualizer**: Retrato de fase para sistemas de equações diferenciais $x' = f(x,y), y' = g(x,y)$.
- **Conformal Map Visualizer**: Mapeamentos conformes no plano complexo $w = f(z)$.
- **Fourier Synthesis Visualizer**: Decomposição e síntese de ondas por Séries de Fourier.

### 2.6 Bloco Diagrama Mermaid.js
- Renderização em tempo real de diagramas de fluxo (*Flowcharts*), diagramas de classe, estado, sequência, Gantt e ER.

### 2.7 Bloco Mapa Mental (Mindmap Block)
- Construtor interativo de nós de pensamento de árvore expansível com adição de filhos (`Tab` / `Enter`).

### 2.8 Bloco Tabela de Dados (Data Table Block)
- Tabela estilo planilha com adição de linhas/colunas, tipos de dados (Texto, Número, Data) e cálculos de soma/média no rodapé.

### 2.9 Bloco Estudo de PDF (PDF Block)
- Leitor de PDF com extração de texto, realce de trecho com caneta e ancoragem de comentários nas páginas.

### 2.10 Bloco Circuito Elétrico (Circuit Block)
- Simulador e desenhador de esquemáticos elétricos (Resistores, Capacitores, Fontes V/I, AmpOps).

### 2.11 Blocos Educacionais & Exercícios
- **Exercise Block**: Cartão de exercício com enunciado, opção de múltipla escolha ou resposta aberta e gabarito oculto com revelação por clique.
- **Proof Debugger Block**: Verificador de passos de demonstração matemática.
- **Flashcard Block**: Cartão de memorização rápida com rotação 3D (Frente/Verso).

---

## ✒️ PILAR 3: Desenho Vetorial, Formas & Conexões

### 3.1 Caneta & Marca-texto
- **Caneta Livre (Pen)**:
  - Traçado vetorial com resposta à pressão da caneta/stylus.
  - Algoritmo de simplificação **Ramer-Douglas-Peucker (RDP)** tuning 0.15px para curvas suaves.
  - Paleta de cores selecionáveis (Roxo, Ciano, Esmeralda, Rosa, Âmbar, Branco, Preto).
  - Slider de espessura de traço (1px a 12px).
- **Marca-texto (Highlighter)**:
  - Traçado com opacidade translúcida e mistura de camada (*Multiply blend mode*).
- **Borracha (Eraser)**:
  - **Borracha de Objeto**: Deleta o traço inteiro ao tocar em qualquer ponto.
  - **Borracha Vetorial / Recorte**: Fatia e divide o traço no raio do ponteiro da borracha.

### 3.2 Reconhecimento de Formas (Shape Recognition Pro)
- Reconhecimento automático de formas desenhadas à mão (*Neat Shapes*):
  - Retângulos, Círculos, Elipses, Triângulos (Equilátero, Retângulo, Isósceles), Pentágonos, Hexágonos, Octógonos, Losangos e Linhas Retas.
  - Se o usuário segurar o traço parado por 350ms após desenhar, ele sofre o *Snap* geométrico perfeito.

### 3.3 Conexões & Setas Inteligentes entre Blocos
- Conectores dinâmicos vinculando as ancoragens dos blocos (Top, Bottom, Left, Right).
- Estilos de Linha: **Reta**, **Curva Bézier**, **Ortogonal (Esquema de passos 90°)**.
- Estilos de Ponta: **Seta Simples**, **Seta Dupla**, **Linha Simples**.
- As conexões se re-calculam e acompanham o bloco em tempo real durante o arraste.

---

## ⚡ PILAR 4: Motor STEM NATIVO Rust (`cn_compute`)

### 4.1 Solver de Equações Diferenciais Ordinárias (EDO)
- Métodos numéricos nativos compilados em Rust: **Euler**, **Heun**, **Runge-Kutta de 4ª Ordem (RK4)**, **Dormand-Prince (RK45 Adaptativo)**.
- Tolerância absoluta e relativa configuráveis.

### 4.2 Álgebra Linear & Matrizes
- Operações matriciais nativas: Inversão de matrizes, Decomposição LU, Valores e Vetores Próprios (*Eigenvalues/Eigenvectors*), Multiplicação e Determinante.

### 4.3 Cálculo de Incertezas & Propagação de Erros Experimentais
- Propagação de incerteza por Derivadas Parciais:
  $$\sigma_f = \sqrt{\sum \left(\frac{\partial f}{\partial x_i} \sigma_{x_i}\right)^2}$$
- Útil para relatórios de laboratório de física e química.

---

## 📂 PILAR 5: Gestão de Notas, Árvore & Abas

### 5.1 Árvore de Notas & Estrutura Hierárquica (Sidebar)
- Navegação por Pastas e Sub-notas em profundidade ilimitada.
- Arraste e solte (*Drag and Drop*) de notas entre pastas.
- Criação rápida de notas de qualquer tipo (Canvas, Texto Rico, Código, PDF).
- Sistema de **Tags / Etiquetas** com filtragem rápida no rodapé (`#Física`, `#Laboratório`).
- Campo de Busca em Tempo Real (`Ctrl + P`).

### 5.2 Barra de Abas (*TabBar*)
- Suporte a múltiplas notas abertas em abas no topo da tela.
- Reordenação de abas por arraste.
- Atalho `Ctrl + W` para fechar aba, `Ctrl + Tab` para alternar.

### 5.3 Omnibar Científica (Barra Superior de Busca)
- Abertura rápida por `Ctrl + K`.
- Pesquisa global por conteúdo de blocos, títulos de notas, fórmulas LaTeX e código.

---

## 🌐 PILAR 6: Persistência Local & Rede P2P sem Nuvem

### 6.1 Banco de Dados SQLite Local (`cn_storage`)
- Arquivo local único `vault.db` criptografado ou em disco nativo.
- Salvamento automático (*Auto-save*) com debounce silencioso sem poluir o histórico de Desfazer (`Ctrl + Z`).
- Histórico de revisões e desfazer/refazer (*Undo/Redo Stack*).

### 6.2 Sincronização P2P Multi-Dispositivo (`cn_sync`)
- Descoberta automática de nós na mesma rede Wi-Fi/LAN via **mDNS (Multicast DNS)** e anúncio UDP.
- Transmissão de notas e blocos sem passar por nenhum servidor na nuvem (100% Privado e Descentralizado).
- Protocolo de sincronização delta por versão de documento.

---

### 📌 Resumo de Especificações para a Reescrita

| Componente | Requisito Principal |
|---|---|
| **Renderização** | 120 FPS cravados via GPU (WGPU/Vulkan/DirectX) |
| **Arquitetura de Cores** | Tema centralizado estilo CSS (`theme.rs`) |
| **Liquid Glass** | Dual Kawase Blur Shader nativo estilo iOS em VRAM |
| **Nível de Detalhe** | Sistema de LOD de 3 níveis por escala de zoom |
| **Persistência** | SQLite NATIVO `vault.db` (`cn_storage`) |
| **Cálculo Científico** | Motor Nativo Rust em Código de Máquina (`cn_compute`) |
| **Sincronização** | P2P mDNS/UDP sem nuvem (`cn_sync`) |

---

Esta documentação cobre **100% de todos os requisitos do ConnectedNotes** e servirá como a especificação mestre completa para o desenvolvimento do software.
