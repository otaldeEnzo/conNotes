# Plano de Implementação Refinado: Tela de Configurações STEM (Fase 6)

Plano detalhado e alinhado através da sessão interativa de **`/grill-me`** para a implementação da **Tela de Configurações do conNotes** como uma página imersiva no Canvas com **`SettingsTabBar` dedicada**, **Sandbox interativa ao vivo** e **Persistência Local-First**.

---

## 1. Visão Geral da Arquitetura & Fluxo de Navegação

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Top Bar Normal (NoteTabBar):                                                                     │
│   [ ☰ ]  [ 📝 Nota 1  ✕ ] [ 📝 Física II  ✕ ] [ + ] [ ⚙️ Configurações ]       [ 🔍 100% ]       │
└──────────────────────────────────────┬───────────────────────────────────────────────────────────┘
                                       │ (Clique no ⚙️)
┌──────────────────────────────────────▼───────────────────────────────────────────────────────────┐
│ Settings Top Bar (SettingsTabBar):                                                               │
│   [ ← Voltar ] [ 🎨 Visual ] [ 📐 Canvas ] [ ✏️ Caneta ] [ 📏 Medição ] [ ⌨️ Atalhos ] [ 🤖 IA ]   │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Canvas Viewport (SettingsPageView):                                                              │
│                                                                                                  │
│   ┌──────────────────────────────────────────────┐  ┌────────────────────────────────────────┐   │
│   │ Controles & Opções Moscaro v2                │  │ Sandbox Interativa de Teste ao Vivo    │   │
│   │ - Intensidade do Blur (Vidro): [ 35 px ]     │  │ (Desenhe com a caneta aqui para testar │   │
│   │ - Borda Aurora Animada: [ Ativo ]            │  │  a sensibilidade, traço e blur na hora)│   │
│   │ - Suavização de Traço (RDP): [ 0.35 ]        │  │                                        │   │
│   │ - Snap Angular da Régua: [ 15° ]             │  │   ✎ ~ ~ ~ ~                            │   │
│   │ - [ Restaurar Padrões ]                      │  │                                        │   │
│   └──────────────────────────────────────────────┘  └────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Decisões de Design & UX (Alinhadas no Grill-Me)

1. **Página de Configurações Integrada ao Canvas**:
   - Não é um modal pop-up genérico. As configurações ocupam a área principal do Canvas em uma visualização imersiva estilizada com cards em **Vidro Líquido Moscaro** (`.moscaroV2()`).
2. **`SettingsTabBar` Substitutiva**:
   - Ao abrir as configurações, a `NoteTabBar` faz uma transição animada fluida para a `SettingsTabBar`.
   - Cada aba da barra superior representa uma categoria de preferências.
   - Um botão `← Voltar` à esquerda retorna instantaneamente para as notas ativas.
3. **Ponto de Entrada Único & Limpo**:
   - Ícone de engrenagem SVG posicionado no topo da `NoteTabBar`, ao lado do botão `+` de adicionar nova nota (e atalho `Ctrl + ,`).
4. **Toolbar Inferior Oculta com Sandbox ao Vivo**:
   - A barra de ferramentas inferior é recolhida suavemente para focar na configuração.
   - Um card **Sandbox Interativa** é embutido na visualização para que o usuário possa testar o traço da caneta, pressão, suavização e cores em tempo real sem precisar sair da tela de configurações.
5. **Persistência Local-First Automática**:
   - Cada alteração é salva instantaneamente no arquivo local `settings.json` através do `SettingsService`.
   - Botão discreto `Restaurar Padrões` em cada categoria.

---

## 3. Decomposição de Componentes & Arquivos (1 Componente por Arquivo)

### A. Camada de Estado & Persistência
- **Arquivo**: `lib/widgets/settings_models.dart` [NOVO]
  - Modelos imutáveis `AppSettingsState` com todos os parâmetros configuráveis:
    - **Visual**: `blurSigma` (10 a 50), `enableAuroraBorders` (bool), `showTelemetryHud` (bool).
    - **Canvas**: `gridSpacing` (16 a 48), `enableMouseGlow` (bool), `mouseGlowRadius` (80 a 240).
    - **Caneta**: `rdpSmoothingTolerance` (0.1 a 0.8), `pressureSensitivity` (0.5 a 1.5), `drawAndHoldDurationMs` (300 a 600).
    - **Medição**: `angleSnapStepDegrees` (0°, 5°, 15°, 30°), `inkSnapTolerance` (12 a 36).
    - **IA**: `geminiApiKey` (String), `defaultModel` (String).
- **Arquivo**: `lib/services/settings_service.dart` [NOVO]
  - Serviço singleton para carregar e salvar `settings.json` no disco local com fallback automático para os valores padrão.

### B. Barra Superior de Configurações
- **Arquivo**: `lib/widgets/settings_tab_bar.dart` [NOVO]
  - Barra superior no padrão `moscaro-v2` com o botão `← Voltar` e abas clicáveis:
    `Visual`, `Canvas & Grid`, `Caneta & Stylus`, `Medição`, `Atalhos`, `IA`.

### C. Visualizador Principal e Categorias
- **Arquivo**: `lib/widgets/settings_page_view.dart` [NOVO]
  - Container principal exibido no Canvas quando o modo de configurações estiver ativo.
- **Arquivo**: `lib/widgets/settings_sandbox_card.dart` [NOVO]
  - Mini canvas interativo para rabiscar e testar traços, pressão e suavização ao vivo.
- **Arquivo**: `lib/widgets/settings_shortcuts_view.dart` [NOVO]
  - Tabela visual e moderna com os atalhos de teclado do conNotes.

### D. Componentes Atômicos de Configuração
- **Arquivo**: `lib/widgets/settings_slider_tile.dart` [NOVO]
  - Slider customizado Moscaro com valor digital atual e limites.
- **Arquivo**: `lib/widgets/settings_toggle_tile.dart` [NOVO]
  - Switch customizado com halo neon ciano.

### E. Ícones SVG Vetoriais
- **Arquivo**: `lib/widgets/svg_icon.dart` [MODIFICAÇÃO]
  - Adição dos ícones inline: `'settings'`, `'arrow_left'`, `'keyboard'`, `'palette'`.

### F. Integração no `main.dart` e `NoteTabBar`
- **Arquivo**: `lib/widgets/note_tab_bar.dart` [MODIFICAÇÃO]
  - Adição do botão de configurações ao lado do botão `+`.
- **Arquivo**: `lib/main.dart` [MODIFICAÇÃO]
  - Estado `_isSettingsOpen` e `_activeSettingsCategory`.
  - Transição animada entre `NoteTabBar` e `SettingsTabBar`.
  - Exibição de `SettingsPageView` no Canvas quando `_isSettingsOpen == true`.

---

## 4. Plano de Verificação

1. **Navegação & Transição**:
   - Clicar no botão `⚙️` na `NoteTabBar` transiciona suavemente para a `SettingsTabBar`.
   - Clicar em `← Voltar` ou pressionar `Esc` retorna imediatamente para a nota anterior.
2. **Ajustes em Tempo Real**:
   - Mover o slider de blur ou suavização reflete instantaneamente na Sandbox e no app.
   - O arquivo `settings.json` é atualizado em disco sem engasgos.
3. **Sandbox Interativa**:
   - Desenhar na Sandbox da aba de caneta permite validar traços finos/grossos com a pressão atual configurada.
4. **Estética Moscaro v2**:
   - Validar ausência de emojis, uso estrito de ícones SVG e contraste visual.
