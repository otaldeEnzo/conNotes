# Fase 11.2: Renderização Rica de Formatação, Ciclo de Vida de Blocos (Ctrl+Enter / Ctrl+Backspace), LaTeX/Mermaid e Deseleção Precisa

Este plano detalha as correções e melhorias estruturais para a experiência de edição e visualização de **Cards STEM**, atendendo pontualmente a todas as observações e feedback de atalhos do usuário:

1. **Formatação de Texto e Cores sem Vazamento de Código**: Negrito (`**`), Itálico (`*`), Sublinhado (`<u>`), Marca-texto (`==` / `<mark>`) e Cor (`<span style="color: #HEX">`) renderizando estilos visuais autênticos em vez de código cru.
2. **Escopo de Tamanho de Fonte**: Alterar o tamanho da fonte com texto selecionado afeta a seleção/bloco ativo em vez de inflar o card inteiro inadvertidamente.
3. **Escopo de Ações por Bloco**: Ações da barra flutuante quando o usuário está editando um bloco afetam estritamente aquele bloco.
4. **Ciclo de Vida de Blocos com Atalhos Específicos (`Ctrl + Enter` e `Ctrl + Backspace`)**:
   - **`Enter` Normal**: Insere quebra de linha normal dentro do bloco ativo de texto.
   - **`Ctrl + Enter`**: Cria um novo bloco imediatamente abaixo do bloco atual e transfere o foco.
   - **`Ctrl + Backspace`**: Deleta o bloco ativo e transfere o foco para o bloco anterior.
   - Botão `+` e botão de lixeira no bloco para acesso visual via mouse.
5. **Deseleção Precisa ao Clicar Fora do Card**: Ajuste do cálculo geométrico de hit-test para que qualquer clique fora do card ou da barra flutuante retire a seleção imediatamente.
6. **Renderização Gráfica Real de Mermaid & LaTeX**: Visualização de diagramas Mermaid em vetores gráficos e fórmulas KaTeX inline (`$...$`) e em bloco (`$$...$$`).

---

## User Review Required

> [!NOTE]
> **Avaliação de Viabilidade dos Atalhos**:
> - `Ctrl + Enter` para criação de blocos: **100% viável e altamente ergonômico**. Permite que o usuário use `Enter` comum para criar parágrafos e quebras de linha dentro do mesmo bloco sem fragmentá-lo em vários blocos, reservando `Ctrl + Enter` para instanciar um novo bloco independente.
> - `Ctrl + Backspace` para exclusão de blocos: **100% viável e seguro**. Evita que o usuário apague acidentalmente o bloco inteiro ao tentar apenas apagar caracteres normais com `Backspace`.

---

## Proposed Changes

### 1. `markdown_latex_block_view.dart` & Parsers de Formatação Rica

#### [MODIFY] [markdown_latex_block_view.dart](file:///C:/Users/Enzo/Documents/conNotes/app/lib/widgets/markdown_latex_block_view.dart)
- **Extensão de Sintaxe Markdown**:
  - Implementar suporte completo a tags HTML inline (`<u>...</u>`, `<mark>...</mark>`, `<span style="color: #HEX">...</span>`, `<font color="...">`) e sintaxe de highlight `==texto==`.
  - Configurar `MarkdownBody` com `extensionSet: md.ExtensionSet.gitHubFlavored` e builders customizados para elementos de estilo.
- **Inserção Inteligente de Estilos sem Código Vazio**:
  - Se houver texto selecionado: envelopa com o estilo (`**selecao**`, `<u>selecao</u>`, `==selecao==`, `<span style="color: #HEX">selecao</span>`).
  - Se NÃO houver texto selecionado: formata a palavra onde o cursor está ou o bloco inteiro com o estilo/cor escolhido, evitando criar tags vazias (`====`, `<u></u>`).
- **Gerenciamento de Foco e Atalhos de Teclado (`CallbackShortcuts` / `Focus` / `KeyEvent`)**:
  - **`Ctrl + Enter`**: Cria um novo bloco logo abaixo e foca no novo campo de edição.
  - **`Ctrl + Backspace`**: Remove o bloco atual e move o foco para o bloco anterior.
  - Botão flutuante sutil `+` e botão de lixeira no hover do bloco.

---

### 2. Renderizador Gráfico de Diagramas Mermaid

#### [NEW] [mermaid_diagram_painter_view.dart](file:///C:/Users/Enzo/Documents/conNotes/app/lib/widgets/mermaid_diagram_painter_view.dart)
- Componente nativo de renderização de diagramas Mermaid:
  - **Fluxogramas (`graph TD / LR`)**: Nós estilizados em vidro líquido com cantos arredondados, rótulos e setas de transição fluorescentes.
  - **Diagramas de Sequência (`sequenceDiagram`)**: Linhas de vida dos atores, mensagens síncronas/assíncronas e caixas de nota.
  - **Diagramas de Estado (`stateDiagram-v2`)**: Estados iniciais `[*]`, transições com eventos e estados finais.
  - **Diagramas de Classes (`classDiagram`)**: Caixas de classe com atributos e métodos.
- Botão de alternância entre "Visualização Gráfica" e "Editar Código Mermaid".

---

### 3. Inserção Consistente de Fórmulas LaTeX

#### [MODIFY] [latex_stem_symbols_palette.dart](file:///C:/Users/Enzo/Documents/conNotes/app/lib/widgets/latex_stem_symbols_palette.dart)
- Garantir que a inserção de símbolos da paleta KaTeX:
  - Se dentro de um bloco de texto normal: insere como fórmula inline `$snippet$` para renderização imediata.
  - Se dentro de um bloco de equação `$$`: insere o código bruto KaTeX.

---

### 4. Ajuste Preciso de Deseleção e Hit-Testing do Canvas

#### [MODIFY] [main.dart](file:///C:/Users/Enzo/Documents/conNotes/app/lib/main.dart)
- Refinar `_findCardAtPoint`:
  - Limitar a margem de tolerância para exatamente `12.0px` em torno da moldura real do card e suas alças de redimensionamento.
  - Calcular a altura real precisa baseada nos blocos em vez de superestimar a altura virtual.
  - Permitir que qualquer clique fora da moldura do card e fora da pílula retire imediatamente a seleção (`_selectedCardId = null`) e feche os popovers abertos.

---

## Verification Plan

### Automated Verification
- Executar `flutter analyze lib/` garantindo 0 erros de compilação.
- Executar `graphify update .` para manter o grafo de conhecimento sincronizado.

### Manual Verification
1. **Formatação de Texto**:
   - Digitar texto, selecionar um trecho e clicar em **B**, **I**, **U**, **H** (marca-texto) e **Cor**. Verificar que o texto assume a formatação visual sem exibir tags de código cruas.
2. **Tamanho de Fonte**:
   - Selecionar texto ou editar um bloco e alterar o tamanho da fonte. Verificar que o efeito é direcionado ao bloco em edição sem afetar o card todo indevidamente.
3. **Ciclo de Vida de Blocos com Atalhos**:
   - Digitar texto e pressionar `Enter` (deve apenas criar nova linha no mesmo bloco).
   - Pressionar `Ctrl + Enter` (deve criar um novo bloco abaixo e focar nele).
   - Pressionar `Ctrl + Backspace` (deve deletar o bloco atual e retornar o foco ao anterior).
4. **Mermaid & LaTeX**:
   - Inserir um template de fluxograma/estado Mermaid e verificar a renderização visual dos nós e setas.
   - Inserir fórmulas LaTeX e verificar a renderização com KaTeX inline/bloco.
5. **Deseleção**:
   - Clicar fora do card no canvas e verificar que a seleção é removida imediatamente.
