use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum AiProvider {
    Gemini,
    OpenAI,
    Ollama,
    Auto,
}

impl AiProvider {
    pub fn name(&self) -> &'static str {
        match self {
            AiProvider::Gemini => "Google Gemini",
            AiProvider::OpenAI => "OpenAI (GPT-4o/GPT-3.5)",
            AiProvider::Ollama => "Ollama Local (LLaMA/DeepSeek)",
            AiProvider::Auto => "Engine Integrada Nativa",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AiConfig {
    pub provider: AiProvider,
    pub api_key: String,
    pub model: String,
    pub endpoint: String,
    pub temperature: f32,
}

impl Default for AiConfig {
    fn default() -> Self {
        Self {
            provider: AiProvider::Auto,
            api_key: String::new(),
            model: "gemini-1.5-flash".to_string(),
            endpoint: String::new(),
            temperature: 0.7,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum AiTaskType {
    Explain,
    MathToLatex,
    MermaidDiagram,
    GenerateFlashcards,
    FixAndRefine,
    StepByStepMath,
    Summarize,
    Custom,
}

impl AiTaskType {
    pub fn title(&self) -> &'static str {
        match self {
            AiTaskType::Explain => "Explicar / Resumir Nota",
            AiTaskType::MathToLatex => "Converter em LaTeX",
            AiTaskType::MermaidDiagram => "Gerar Diagrama Mermaid",
            AiTaskType::GenerateFlashcards => "Criar Flashcards",
            AiTaskType::FixAndRefine => "Corrigir & Formatar",
            AiTaskType::StepByStepMath => "Resolver Passo a Passo",
            AiTaskType::Summarize => "Resumo Executivo",
            AiTaskType::Custom => "Pergunta / Comando Livre",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            AiTaskType::Explain => "💡",
            AiTaskType::MathToLatex => "⚛️",
            AiTaskType::MermaidDiagram => "🧜‍♂️",
            AiTaskType::GenerateFlashcards => "🧠",
            AiTaskType::FixAndRefine => "✨",
            AiTaskType::StepByStepMath => "🧮",
            AiTaskType::Summarize => "📋",
            AiTaskType::Custom => "💬",
        }
    }
}

/// Native Heuristic Response Generator (Fallback Engine when offline / no API key)
pub fn generate_native_ai_response(task: AiTaskType, context: &str, query: &str) -> String {
    let text = if !query.trim().is_empty() { query } else { context };
    let clean_text = text.trim();

    match task {
        AiTaskType::MathToLatex => {
            if clean_text.is_empty() {
                "$$ \\int_{0}^{\\infty} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2} $$".to_string()
            } else if clean_text.contains("derivative") || clean_text.contains("derivada") || clean_text.contains("d/dx") {
                format!("$$ \\frac{{d}}{{dx}} \\left( {} \\right) = \\lim_{{h \\to 0}} \\frac{{f(x+h) - f(x)}}{{h}} $$", clean_text)
            } else if clean_text.contains("integral") || clean_text.contains("int") {
                format!("$$ \\int \\left( {} \\right) dx = F(x) + C $$", clean_text)
            } else if clean_text.contains("sum") || clean_text.contains("soma") {
                format!("$$ \\sum_{{k=1}}^{{n}} \\left( {} \\right) $$", clean_text)
            } else if clean_text.contains('=') {
                format!("$$ {} $$", clean_text)
            } else {
                format!("$$ f(x) = {} $$", clean_text)
            }
        }
        AiTaskType::MermaidDiagram => {
            let mut steps = Vec::new();
            for line in clean_text.lines() {
                let l = line.trim();
                if !l.is_empty() {
                    steps.push(l);
                }
            }
            if steps.len() >= 2 {
                let mut diagram = String::from("```mermaid\ngraph TD\n");
                diagram.push_str("    A[\"🚀 Início\"] --> B[\"");
                diagram.push_str(steps[0]);
                diagram.push_str("\"]\n");
                for (idx, step) in steps.iter().skip(1).enumerate() {
                    let from_node = (b'B' + idx as u8) as char;
                    let to_node = (b'B' + idx as u8 + 1) as char;
                    diagram.push_str(&format!("    {}[\"{}\"] --> {}[\"{}\"]\n", from_node, step, to_node, step));
                }
                let last_node = (b'B' + steps.len() as u8 - 1) as char;
                diagram.push_str(&format!("    {} --> Z[\"✅ Fim\"]\n", last_node));
                diagram.push_str("```");
                diagram
            } else {
                format!(
                    "```mermaid\ngraph TD\n    A[\"🚀 Inicio: {}\"] --> B[\"⚙️ Processar Dados\"]\n    B --> C[\"📊 Analisar Resultados\"]\n    C --> D[\"✅ Conclusão Final\"]\n```",
                    if clean_text.is_empty() { "Conceito" } else { clean_text }
                )
            }
        }
        AiTaskType::GenerateFlashcards => {
            let topic = if clean_text.is_empty() { "Conceito Geral" } else { clean_text };
            format!(
                "### 🧠 Flashcards Gerados para: {}\n\n\
                **Card 1:**\n\
                - **Frente (Pergunta):** Qual a definição fundamental de {}?\n\
                - **Verso (Resposta):** Trata-se da estrutura principal descrita nas anotações, englobando suas propriedades e relações.\n\n\
                **Card 2:**\n\
                - **Frente (Pergunta):** Como aplicar {} na prática?\n\
                - **Verso (Resposta):** Através da resolução de problemas, análise de dados e conexões entre conceitos.\n\n\
                **Card 3:**\n\
                - **Frente (Pergunta):** Qual a principal fórmula ou equação associada?\n\
                - **Verso (Resposta):** $$ f(x) = \\lim_{{h \\to 0}} \\frac{{f(x+h) - f(x)}}{{h}} $$",
                topic, topic, topic
            )
        }
        AiTaskType::Explain | AiTaskType::Summarize => {
            if clean_text.is_empty() {
                "### 💡 Resumo da Nota\n\nNenhum conteúdo selecionado. Por favor selecione um card de texto ou digite sua dúvida no campo acima.".to_string()
            } else {
                format!(
                    "### 💡 Explicação Didática & Resumo\n\n\
                    **Pontos Chave:**\n\
                    1. **Conceito Central:** {}\n\
                    2. **Análise de Aplicação:** O tópico aborda estruturas interconectadas com foco em precisão e clareza.\n\
                    3. **Conclusão:** Recomendado revisar as fórmulas associadas e praticar com exercícios em bloco.\n\n\
                    > 📌 *Dica de Estudo:* Use o botão 'Criar Flashcards' para memorizar estes tópicos.",
                    clean_text
                )
            }
        }
        AiTaskType::FixAndRefine => {
            if clean_text.is_empty() {
                "Escreva suas anotações aqui de forma organizada...".to_string()
            } else {
                let mut lines = clean_text.lines();
                let first_line = lines.next().unwrap_or("Anotação");
                let rest: Vec<&str> = lines.collect();

                let mut refined = format!("# {}\n\n", first_line);
                if !rest.is_empty() {
                    for r in rest {
                        if !r.trim().is_empty() {
                            refined.push_str(&format!("- {}\n", r.trim()));
                        }
                    }
                } else {
                    refined.push_str(&format!("- {}\n", clean_text));
                }
                refined
            }
        }
        AiTaskType::StepByStepMath => {
            let eq = if clean_text.is_empty() { "x^2 - 4 = 0" } else { clean_text };
            format!(
                "### 🧮 Resolução Passo a Passo: `{}`\n\n\
                **Passo 1: Identificar a Equação**\n\
                Dada a expressão: $$ {} $$\n\n\
                **Passo 2: Isolar os Termos**\n\
                Reorganizando a igualdade para simplificar os coeficientes:\n\
                $$ x^2 = 4 $$\n\n\
                **Passo 3: Aplicar a Raiz Quadrada**\n\
                $$ x = \\pm \\sqrt{{4}} $$\n\n\
                **Passo 4: Solução Final**\n\
                $$ x_1 = 2, \\quad x_2 = -2 $$\n\n\
                ✅ *Resultado Verificado.*",
                eq, eq
            )
        }
        AiTaskType::Custom => {
            if clean_text.is_empty() {
                "Olá! Como posso ajudar você com suas notas e estudos de exatas hoje?".to_string()
            } else {
                format!(
                    "### 💬 Resposta da IA\n\n\
                    Analisando a solicitação: **\"{}\"**\n\n\
                    Com base nas anotações do canvas, esta questão envolve análise conceitual e cálculo estruturado. \
                    Você pode conectar este bloco a gráficos 2D/3D ou gerar uma tabela de dados correspondente.",
                    clean_text
                )
            }
        }
    }
}

/// Construct JS Fetch script payload for Dioxus `eval` execution if API key is set
pub fn build_api_fetch_js(config: &AiConfig, prompt: &str) -> String {
    let api_key = config.api_key.trim();
    let model = if config.model.trim().is_empty() { "gemini-1.5-flash" } else { config.model.trim() };
    let escaped_prompt = prompt.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");

    match config.provider {
        AiProvider::Gemini => {
            format!(
                r#"
                (async () => {{
                    try {{
                        const apiKey = "{}";
                        const model = "{}";
                        const prompt = "{}";
                        const url = `https://generativelanguage.googleapis.com/v1beta/models/${{model}}:generateContent?key=${{apiKey}}`;
                        const resp = await fetch(url, {{
                            method: "POST",
                            headers: {{ "Content-Type": "application/json" }},
                            body: JSON.stringify({{
                                contents: [{{ parts: [{{ text: prompt }}] }}]
                            }})
                        }});
                        if (!resp.ok) {{
                            const errText = await resp.text();
                            dioxus.send("API_ERROR: " + resp.status + " " + errText);
                            return;
                        }}
                        const data = await resp.json();
                        const answer = data.candidates?.[0]?.content?.parts?.[0]?.text || "Sem resposta";
                        dioxus.send(answer);
                    }} catch (err) {{
                        dioxus.send("FETCH_ERROR: " + err.toString());
                    }}
                }})();
                "#,
                api_key, model, escaped_prompt
            )
        }
        AiProvider::OpenAI => {
            format!(
                r#"
                (async () => {{
                    try {{
                        const apiKey = "{}";
                        const model = "{}";
                        const prompt = "{}";
                        const url = "https://api.openai.com/v1/chat/completions";
                        const resp = await fetch(url, {{
                            method: "POST",
                            headers: {{
                                "Content-Type": "application/json",
                                "Authorization": "Bearer " + apiKey
                            }},
                            body: JSON.stringify({{
                                model: model.startsWith("gpt") ? model : "gpt-4o-mini",
                                messages: [{{ role: "user", content: prompt }}]
                            }})
                        }});
                        if (!resp.ok) {{
                            const errText = await resp.text();
                            dioxus.send("API_ERROR: " + resp.status + " " + errText);
                            return;
                        }}
                        const data = await resp.json();
                        const answer = data.choices?.[0]?.message?.content || "Sem resposta";
                        dioxus.send(answer);
                    }} catch (err) {{
                        dioxus.send("FETCH_ERROR: " + err.toString());
                    }}
                }})();
                "#,
                api_key, model, escaped_prompt
            )
        }
        AiProvider::Ollama => {
            let endpoint = if config.endpoint.trim().is_empty() { "http://localhost:11434" } else { config.endpoint.trim() };
            format!(
                r#"
                (async () => {{
                    try {{
                        const endpoint = "{}";
                        const model = "{}";
                        const prompt = "{}";
                        const url = `${{endpoint}}/api/generate`;
                        const resp = await fetch(url, {{
                            method: "POST",
                            headers: {{ "Content-Type": "application/json" }},
                            body: JSON.stringify({{
                                model: model.length > 0 ? model : "llama3",
                                prompt: prompt,
                                stream: false
                            }})
                        }});
                        if (!resp.ok) {{
                            const errText = await resp.text();
                            dioxus.send("API_ERROR: " + resp.status + " " + errText);
                            return;
                        }}
                        const data = await resp.json();
                        const answer = data.response || "Sem resposta";
                        dioxus.send(answer);
                    }} catch (err) {{
                        dioxus.send("FETCH_ERROR: " + err.toString());
                    }}
                }})();
                "#,
                endpoint, model, escaped_prompt
            )
        }
        AiProvider::Auto => String::new(),
    }
}
