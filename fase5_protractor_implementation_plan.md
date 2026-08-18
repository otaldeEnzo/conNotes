# Plano de Implementação: Transferidor STEM & Sub-barra de Medição (Fase 5.2)

Implementação do **Transferidor STEM Interativo (Protractor Tool)** integrado a uma nova **Sub-barra de Ferramentas de Medição** com alternância fluida entre Régua e Transferidor no padrão visual **Moscaro v2**.

---

## 1. Visão Geral da Arquitetura

```text
┌────────────────────────────────────────────────────────────────────────┐
│ UI Layer (Flutter + Impeller)                                          │
│                                                                        │
│   [ Sub-Barra de Medição:  (📐 Régua)  (📐 Transferidor) ]             │
│                               ▲                                        │
│   [ ToolbarPill: ... (Caneta) (Borracha) (Formas) [📐 Medição] (IA) ]  │
│                                                                        │
│ Canvas Layer (Interação STEM):                                         │
│   - StemProtractorWidget / StemRulerWidget                             │
│   - Atração Magnética de Caneta (Ink Snapping no Arco e na Base Reta)  │
│   - Graduações Angulares 0°-180° Upright + Entrada Numérica Exata      │
└────────────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> **Comportamento de Fechamento / Alternância**:
> Seguindo o feedback e a consistência com as demais sub-barras (`ShapesSubBar`, `EraserSubBar`, `PenSlotsSubBar`), a `RulerSubBar` **não possui botão explícito de fechar**. O fechamento ou ocultação ocorre naturalmente ao clicar novamente no botão de medição da Toolbar ou ao selecionar outra ferramenta (como a caneta ou seleção).

---

## 2. Componentes e Arquivos

### A. Sub-Barra de Ferramentas de Medição
- **Arquivo**: `lib/widgets/ruler_sub_bar.dart` [NOVO]
- **Responsabilidade**:
  - Sub-barra flutuante renderizada logo acima da `ToolbarPill` quando a ferramenta de medição estiver aberta.
  - Estilizada universalmente com `.moscaroV2()`.
  - Contém exclusivamente a seleção do tipo de instrumento de medição:
    1. **Régua Linear**: Ativa a régua milimétrica com guias retas.
    2. **Transferidor**: Ativa o transferidor semi-circular com guias de arco e ângulos.

### B. Modelo Geométrico do Transferidor STEM
- **Arquivo**: `lib/widgets/stem_protractor_model.dart` [NOVO]
- **Responsabilidade**:
  - Estado imutável `StemProtractorState` (`center`, `radius`, `angle`, `isVisible`).
  - Métodos geométricos de teste de clique (`containsPoint`, `isNearArc`, `isNearOrigin`, `isNearRotateHandle`).
  - **Atração Magnética (Ink Snapping)**:
    - Snap ao longo do **arco circular externo** (permite traçar arcos perfeitos e circunferências com a caneta).
    - Snap ao longo da **linha de base horizontal/diametral**.
  - **Trava Magnética de Ângulo (Angle Snap)** em ângulos notáveis (0°, 15°, 30°, 45°, 60°, 90°, 120°, 135°, 150°, 180°).
  - Normalização de graus 0° a 180° em ambos os sentidos.

### C. Visual & Interatividade do Transferidor
- **Arquivo**: `lib/widgets/stem_protractor_widget.dart` [NOVO]
- **Responsabilidade**:
  - Componente visual baseado em `StemProtractorPainter` e camadas de interação com estética **Moscaro v2**.
  - **Mostrador de Graus**:
    - Arco externo com divisões de 1°, 5° e 10°.
    - Numeração angular dupla padrão de engenharia (0° a 180° horário e anti-horário).
    - Numeração sempre mantida na orientação vertical (*upright*).
  - **HUD Central de Ângulo**:
    - Exibe o ângulo atual de inclinação.
    - Suporte a **duplo clique** para abrir diálogo Moscaro e digitar o ângulo exato.
  - Alça de rotação e alça de ajuste de raio.

### D. Ícone SVG do Transferidor
- **Arquivo**: `lib/widgets/svg_icon.dart` [MODIFICAÇÃO]
- **Responsabilidade**:
  - Adição do vetor inline SVG `'protractor'` limpo e padronizado (sem uso de emojis).

### E. Integração no Canvas Principal
- **Arquivo**: `lib/main.dart` [MODIFICAÇÃO]
- **Responsabilidade**:
  - Estado para ferramenta de medição ativa: `StemMeasurementToolType { none, ruler, protractor }`.
  - Exibição da `RulerSubBar` na fileira de sub-barras acima da ToolbarPill.
  - Captura e despacho de eventos de ponteiro para arraste, rotação e atração magnética do traço para o arco do transferidor.

---

## 3. Plano de Verificação

### Testes Visuais e Interativos
1. **Sub-Barra**:
   - Clicar no botão de medição na Toolbar principal abre a `RulerSubBar` (sem botão extra de fechar).
   - Alternar entre Régua e Transferidor esconde um e exibe o outro instantaneamente.
   - Clicar novamente no botão de medição na barra principal ou trocar de ferramenta fecha a sub-barra.
2. **Transferidor**:
   - Mover o transferidor pelo corpo/centro.
   - Rotacionar suavemente pela borda com sensibilidade amortecida e snap nos ângulos notáveis.
   - Dar duplo clique no mostrador de graus para digitar um ângulo exato (ex: 45° ou 135°).
   - Desenhar com a caneta próximo ao arco: o traço deve ser atraído magneticamente ao contorno circular do transferidor.
3. **Design & Regras**:
   - Confirmar ausência total de emojis e uso estrito de SVGs.
   - Confirmar estética Moscaro v2 (vidro escuro translúcido, borda neon ciano, tipografia limpa).
