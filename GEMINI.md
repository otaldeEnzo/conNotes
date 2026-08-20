## graphify (Protocolo Obrigatório Graphify-First & Economia Estrita de Tokens)

Este projeto possui um grafo de conhecimento em `graphify-out/` com estrutura de comunidades, nós centrais (*god nodes*) e relações entre arquivos.

Regras Estritas de Execução:
- **Primeiro Passo Obrigatório**: Para QUALQUER tarefa de depuração (bugs), adição de funcionalidade, refatoração ou entendimento da base de código, execute SEMPRE `graphify query "<pergunta ou símbolo>"` como a PRIMEIRA ação.
- **Fluxo Operacional Estrito (1-2-3-4)**:
  1. `graphify query "<termo>"` (identifica o nó e método exato)
  2. `view_file` (MÁXIMO 1 VEZ por turno, diretamente no intervalo do método a ser alterado)
  3. `replace_file_content` (edição cirúrgica direta)
  4. `graphify update .` (sincronização do grafo)
- **Proibição de Busca Cega e Grep Redundante**: É ESTRITAMENTE PROIBIDO executar buscas cegas (`grep_search` amplo, varreduras com `find_by_name`) ou múltiplos greps se o Graphify já apontou a localização dos nós.
- **Regra de Leitura Única e Ultra-Cirúrgica (Anti-Token Waste)**: 
  - O `view_file` só pode ser executado **no máximo 1 vez por arquivo afetado**, diretamente no intervalo exato de linhas do método identificado pelo grafo.
  - É **PROIBIDO** fazer leituras fragmentadas consecutivas (`L1-100`, `L100-200`, `L200-300`) ou abrir múltiplos arquivos periféricos que não serão editados.
- **Proibição de Comandos Redundantes**: É PROIBIDO executar comandos de análise repetitivos (ex: `flutter analyze` em múltiplos arquivos periféricos) após alterações pontuais, a menos que explicitamente solicitado pelo usuário.
- **Relações e Conceitos**: Utilize `graphify path "<A>" "<B>"` para entender dependências entre módulos e `graphify explain "<conceito>"` para fluxos específicos.
- **Navegação de Alto Nível**: Para navegação ampla, utilize `graphify-out/wiki/index.md` em vez de ler arquivos de código crus.
- **Sincronização Pós-Edição**: Após qualquer alteração no código-fonte, execute `graphify update .` para manter o grafo e a wiki atualizados.

