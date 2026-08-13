use crate::ai::*;
use crate::types::*;
use dioxus::prelude::*;

#[component]
pub fn AiAssistantModal(
    is_open: Signal<bool>,
    ai_config: Signal<AiConfig>,
    context_text: Signal<String>,
    selected_card_id: Signal<Option<usize>>,
    active_note_id: Signal<Option<usize>>,
    notes: Signal<Vec<NoteItem>>,
) -> Element {
    if !is_open() {
        return rsx! {};
    }

    let mut user_query = use_signal(String::new);
    let mut selected_task = use_signal(|| AiTaskType::Explain);
    let mut ai_response = use_signal(String::new);
    let mut is_loading = use_signal(|| false);
    let mut show_settings = use_signal(|| false);
    let mut error_msg = use_signal(|| Option::<String>::None);

    // Copy notification feedback
    let mut copied = use_signal(|| false);

    // Local form state for settings
    let mut temp_api_key = use_signal(|| ai_config().api_key.clone());
    let mut temp_provider = use_signal(|| ai_config().provider.clone());
    let mut temp_model = use_signal(|| ai_config().model.clone());
    let mut temp_endpoint = use_signal(|| ai_config().endpoint.clone());

    let execute_ai = move |_| {
        is_loading.set(true);
        error_msg.set(None);
        ai_response.set(String::new());

        let cfg = ai_config();
        let task = selected_task();
        let ctx = context_text();
        let query = user_query();

        if cfg.provider != AiProvider::Auto && !cfg.api_key.trim().is_empty() {
            // Build prompt
            let full_prompt = format!(
                "Tarefa: {}\nContexto das Notas:\n{}\n\nInstrução do usuário:\n{}",
                task.title(),
                ctx,
                query
            );

            let js_code = build_api_fetch_js(&cfg, &full_prompt);

            let mut eval_runner = document::eval(&js_code);

            spawn(async move {
                match eval_runner.recv::<String>().await {
                    Ok(resp) => {
                        if resp.starts_with("API_ERROR:") || resp.starts_with("FETCH_ERROR:") {
                            // Fallback on error with notice
                            let fallback = generate_native_ai_response(task, &ctx, &query);
                            ai_response.set(format!(
                                "> ⚠️ *Nota: Erro de API remota ({}). Usando Engine Nativa local:*\n\n{}",
                                resp, fallback
                            ));
                        } else {
                            ai_response.set(resp);
                        }
                    }
                    Err(_) => {
                        let fallback = generate_native_ai_response(task, &ctx, &query);
                        ai_response.set(fallback);
                    }
                }
                is_loading.set(false);
            });
        } else {
            // Use Instant Native Engine
            let resp = generate_native_ai_response(task, &ctx, &query);
            ai_response.set(resp);
            is_loading.set(false);
        }
    };

    let insert_as_new_card = move |_| {
        let resp = ai_response();
        if resp.trim().is_empty() {
            return;
        }

        if let Some(note_id) = active_note_id() {
            let card_type = if resp.contains("```mermaid") {
                "text"
            } else if resp.contains("$$") || resp.contains("\\begin") {
                "math"
            } else if resp.contains("Flashcard") || resp.contains("Card 1") {
                "flashcard"
            } else {
                "text"
            };

            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                    let new_id = note.cards.iter().map(|c| c.id).max().unwrap_or(0) + 1;
                    let new_num = format!("{:02}", note.cards.len() + 1);

                    // Place card at a clean position
                    let max_y = note.cards.iter().map(|c| c.y + c.height).fold(50.0f64, f64::max);

                    note.cards.push(NoteCard {
                        id: new_id,
                        number: new_num,
                        card_type: card_type.to_string(),
                        title: format!("✨ Resposta IA - {}", selected_task().title()),
                        content: resp.clone(),
                        x: 60.0,
                        y: max_y + 30.0,
                        width: 460.0,
                        height: 320.0,
                        selected: true,
                        collapsed: false,
                        locked: false,
                        accent_color: Some("#00e1ff".to_string()),
                    });
                }
            });
        }
        is_open.set(false);
    };

    let replace_selected_card_content = move |_| {
        let resp = ai_response();
        if resp.trim().is_empty() {
            return;
        }

        if let (Some(note_id), Some(card_id)) = (active_note_id(), selected_card_id()) {
            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                    if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                        card.content = resp.clone();
                    }
                }
            });
        }
        is_open.set(false);
    };

    rsx! {
        div {
            class: "ai-modal-backdrop",
            onclick: move |_: MouseEvent| is_open.set(false),

            div {
                class: "moscaro ai-modal-card",
                onclick: move |e: MouseEvent| e.stop_propagation(),

                // MODAL HEADER
                div { class: "ai-modal-header",
                    div { class: "ai-header-title",
                        span { class: "ai-sparkle-icon", "✨" }
                        h3 { "Assistente de Inteligência Artificial" }
                        span { class: "ai-badge-tag", "{ai_config().provider.name()}" }
                    }
                    div { class: "ai-header-controls",
                        button {
                            class: if show_settings() { "ai-icon-btn active" } else { "ai-icon-btn" },
                            title: "Configurar API / Provedor",
                            onclick: move |_| show_settings.toggle(),
                            "⚙️"
                        }
                        button {
                            class: "ai-icon-btn close-btn",
                            title: "Fechar (Esc)",
                            onclick: move |_| is_open.set(false),
                            "✕"
                        }
                    }
                }

                // SETTINGS PANEL (IF TOGGLED)
                if show_settings() {
                    div { class: "ai-settings-panel",
                        div { class: "ai-setting-row",
                            label { "Provedor:" }
                            select {
                                value: match temp_provider() {
                                    AiProvider::Gemini => "gemini",
                                    AiProvider::OpenAI => "openai",
                                    AiProvider::Ollama => "ollama",
                                    AiProvider::Auto => "auto",
                                },
                                onchange: move |e: Event<FormData>| {
                                    match e.value().as_str() {
                                        "gemini" => temp_provider.set(AiProvider::Gemini),
                                        "openai" => temp_provider.set(AiProvider::OpenAI),
                                        "ollama" => temp_provider.set(AiProvider::Ollama),
                                        _ => temp_provider.set(AiProvider::Auto),
                                    }
                                },
                                option { value: "auto", "⚡ Engine Nativa (Sem API Key / Instantâneo)" }
                                option { value: "gemini", "Google Gemini API" }
                                option { value: "openai", "OpenAI API (GPT-4o / ChatGPT)" }
                                option { value: "ollama", "Ollama Local (Servidor HTTP local)" }
                            }
                        }

                        if temp_provider() != AiProvider::Auto {
                            div { class: "ai-setting-row",
                                label { "Chave de API (API Key):" }
                                input {
                                    r#type: "password",
                                    placeholder: "Insira sua API Key...",
                                    value: "{temp_api_key}",
                                    oninput: move |e: FormEvent| temp_api_key.set(e.value())
                                }
                            }
                            div { class: "ai-setting-row",
                                label { "Modelo:" }
                                input {
                                    placeholder: "ex: gemini-1.5-flash ou gpt-4o-mini",
                                    value: "{temp_model}",
                                    oninput: move |e: FormEvent| temp_model.set(e.value())
                                }
                            }
                            if temp_provider() == AiProvider::Ollama {
                                div { class: "ai-setting-row",
                                    label { "Endpoint Ollama:" }
                                    input {
                                        placeholder: "http://localhost:11434",
                                        value: "{temp_endpoint}",
                                        oninput: move |e: FormEvent| temp_endpoint.set(e.value())
                                    }
                                }
                            }
                        }

                        div { class: "ai-settings-actions",
                            button {
                                class: "ai-btn-save",
                                onclick: move |_| {
                                    ai_config.set(AiConfig {
                                        provider: temp_provider(),
                                        api_key: temp_api_key(),
                                        model: temp_model(),
                                        endpoint: temp_endpoint(),
                                        temperature: 0.7,
                                    });
                                    show_settings.set(false);
                                },
                                "Salvar Configurações"
                            }
                        }
                    }
                }

                // GRID DE ACOES RÁPIDAS
                div { class: "ai-tasks-grid",
                    for task in [
                        AiTaskType::Explain,
                        AiTaskType::MathToLatex,
                        AiTaskType::MermaidDiagram,
                        AiTaskType::GenerateFlashcards,
                        AiTaskType::FixAndRefine,
                        AiTaskType::StepByStepMath,
                        AiTaskType::Summarize,
                        AiTaskType::Custom,
                    ] {
                        {
                            let is_sel = selected_task() == task;
                            rsx! {
                                button {
                                    key: "{task.title()}",
                                    class: if is_sel { "ai-task-card active" } else { "ai-task-card" },
                                    onclick: move |_| selected_task.set(task),
                                    span { class: "task-icon", "{task.icon()}" }
                                    span { class: "task-title", "{task.title()}" }
                                }
                            }
                        }
                    }
                }

                // CONTEXT & USER PROMPT INPUT
                div { class: "ai-prompt-container",
                    if !context_text().trim().is_empty() {
                        div { class: "ai-context-preview",
                            span { class: "preview-label", "📌 Contexto Selecionado:" }
                            div { class: "preview-text", "{context_text()}" }
                        }
                    }

                    div { class: "ai-input-wrapper",
                        textarea {
                            class: "ai-prompt-textarea",
                            placeholder: "Digite instruções personalizadas ou perguntas para a IA...",
                            value: "{user_query}",
                            oninput: move |e: FormEvent| user_query.set(e.value())
                        }
                        button {
                            class: "ai-submit-btn",
                            disabled: is_loading(),
                            onclick: execute_ai,
                            if is_loading() { "⚡ Processando..." } else { "✨ Enviar para IA" }
                        }
                    }
                }

                // AI OUTPUT DISPLAY
                if !ai_response().is_empty() || is_loading() {
                    div { class: "ai-output-box",
                        div { class: "ai-output-header",
                            span { "💬 Resposta Gerada:" }
                            div { class: "ai-output-actions",
                                button {
                                    class: "ai-action-btn",
                                    onclick: move |_| {
                                        copied.set(true);
                                    },
                                    if copied() { "✓ Copiado!" } else { "📋 Copiar" }
                                }
                                button {
                                    class: "ai-action-btn primary",
                                    onclick: insert_as_new_card,
                                    "➕ Inserir como Bloco"
                                }
                                if selected_card_id().is_some() {
                                    button {
                                        class: "ai-action-btn replace",
                                        onclick: replace_selected_card_content,
                                        "✏️ Substituir no Card"
                                    }
                                }
                            }
                        }
                        div { class: "ai-output-content",
                            if is_loading() {
                                div { class: "ai-loading-spinner", "⚡ A IA está processando sua solicitação..." }
                            } else {
                                div { style: "white-space: pre-wrap; font-family: inherit; line-height: 1.6;",
                                    "{ai_response()}"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#[component]
pub fn PairingModal(
    is_open: Signal<bool>,
    generated_pin: Signal<String>,
    engine: crate::sync::SyncEngine,
    discovery: crate::sync::PeerDiscovery,
) -> Element {
    if !is_open() {
        return rsx! {};
    }

    let mut input_pin = use_signal(String::new);
    let mut pairing_success = use_signal(|| false);

    rsx! {
        div {
            class: "modal-overlay",
            onclick: move |_| is_open.set(false),
            div {
                class: "moscaro modal-card auth-modal-card",
                onclick: move |evt| evt.stop_propagation(),
                style: "max-width: 460px; padding: 24px;",

                div { 
                    h3 { style: "margin: 0; font-size: 1.25rem; font-weight: 600; display: flex; align-items: center; gap: 8px;",
                        "🔗 Pareamento de Dispositivo"
                    }
                    button {
                        style: "background: none; border: none; color: rgba(255,255,255,0.6); font-size: 1.2rem; cursor: pointer;",
                        onclick: move |_| is_open.set(false),
                        "✕"
                    }
                }

                div { 
                    span { style: "display: block; font-size: 0.85rem; color: rgba(255,255,255,0.7); margin-bottom: 8px;", "PIN de Pareamento Deste Dispositivo:" }
                    div { style: "font-size: 2.2rem; font-family: monospace; font-weight: 700; letter-spacing: 4px; color: #00e1ff;",
                        "{generated_pin()}"
                    }
                    span { style: "display: block; font-size: 0.75rem; color: rgba(255,255,255,0.5); margin-top: 6px;", "Válido na rede local para sincronização direta P2P" }
                }

                div { style: "margin-bottom: 20px;",
                    label { style: "display: block; font-size: 0.85rem; color: rgba(255,255,255,0.8); margin-bottom: 8px;", "Digite o PIN de Outro Dispositivo:" }
                    div { style: "display: flex; gap: 8px;",
                        input {
                            style: "flex: 1; background: rgba(0,0,0,0.4); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 10px 14px; color: #fff; font-family: monospace; font-size: 1.1rem; letter-spacing: 2px;",
                            placeholder: "Ex: 849201",
                            value: "{input_pin()}",
                            oninput: move |evt| input_pin.set(evt.value().clone()),
                        }
                        button {
                            style: "background: linear-gradient(135deg, #00e1ff, #3b82f6); border: none; border-radius: 8px; padding: 0 18px; color: #fff; font-weight: 600; cursor: pointer;",
                            onclick: move |_| {
                                let raw_pin = input_pin().replace('-', "").replace(' ', "").trim().to_string();
                                if !raw_pin.is_empty() {
                                    let peers = discovery.get_active_peers();
                                    engine.broadcast_delta(&peers, crate::types::OperationDelta::PairingRequest {
                                        pin: raw_pin,
                                        device_id: engine.device_id.clone(),
                                        device_name: "ConnectedNotes Peer".to_string(),
                                    });
                                    pairing_success.set(true);
                                }
                            },
                            "Conectar"
                        }
                    }
                }

                if pairing_success() {
                    div { 
                        "✓ Solicitação de pareamento enviada na rede P2P!"
                    }
                }

                div { style: "font-size: 0.78rem; color: rgba(255,255,255,0.5); line-height: 1.4; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 14px;",
                    "🔒 100% Local-First: O pareamento conecta diretamente seu PC e Notebook sem intermediários ou servidores na nuvem."
                }
            }
        }
    }
}

#[component]
pub fn ProfileModal(
    is_open: Signal<bool>,
    user_profile: Signal<Option<UserProfile>>,
) -> Element {
    if !is_open() {
        return rsx! {};
    }

    let mut user_name = use_signal(|| {
        user_profile().map(|p| p.user_id).unwrap_or_else(|| "Novo Usuário".to_string())
    });
    let mut device_name = use_signal(|| {
        user_profile().map(|p| p.device_name).unwrap_or_else(|| "PC Principal".to_string())
    });
    let mut saved_feedback = use_signal(|| false);

    let on_save = move |_| {
        let name = user_name().trim().to_string();
        let dev = device_name().trim().to_string();

        if !name.is_empty() {
            let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs().to_string()).unwrap_or_default();
            let new_prof = UserProfile {
                user_id: name,
                device_name: dev,
                secret_pin: "000-000".to_string(),
                created_at: now,
            };

            if let Ok(conn) = crate::db::init_db("vault.db") {
                let _ = crate::db::save_user_profile(&conn, &new_prof);
            }

            user_profile.set(Some(new_prof));
            saved_feedback.set(true);
        }
    };

    rsx! {
        div {
            class: "modal-overlay",
            onclick: move |_| is_open.set(false),
            div {
                class: "moscaro modal-card profile-modal-card",
                onclick: move |evt| evt.stop_propagation(),
                style: "max-width: 440px; padding: 24px;",

                div { 
                    h3 { style: "margin: 0; font-size: 1.25rem; font-weight: 600; display: flex; align-items: center; gap: 8px;",
                        "👤 Conta & Perfil Local"
                    }
                    button {
                        style: "background: none; border: none; color: rgba(255,255,255,0.6); font-size: 1.2rem; cursor: pointer;",
                        onclick: move |_| is_open.set(false),
                        "✕"
                    }
                }

                div { style: "display: flex; align-items: center; gap: 16px; margin-bottom: 20px; background: rgba(255,255,255,0.04); padding: 14px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.08);",
                    div { style: "width: 48px; height: 48px; border-radius: 50%; background: linear-gradient(135deg, #00e1ff, #a855f7); display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: bold;",
                        "👤"
                    }
                    div {
                        div { style: "font-weight: 600; font-size: 1rem;", "{user_name()}" }
                        div { style: "font-size: 0.8rem; color: rgba(255,255,255,0.6);", "Dispositivo: {device_name()}" }
                    }
                }

                div { style: "margin-bottom: 16px;",
                    label { style: "display: block; font-size: 0.82rem; color: rgba(255,255,255,0.8); margin-bottom: 6px;", "Nome do Usuário:" }
                    input {
                        style: "width: 100%; background: rgba(0,0,0,0.4); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 10px 14px; color: #fff; font-size: 0.95rem;",
                        placeholder: "Ex: Enzo",
                        value: "{user_name()}",
                        oninput: move |e| user_name.set(e.value().clone()),
                    }
                }

                div { style: "margin-bottom: 20px;",
                    label { style: "display: block; font-size: 0.82rem; color: rgba(255,255,255,0.8); margin-bottom: 6px;", "Nome Deste Dispositivo:" }
                    input {
                        style: "width: 100%; background: rgba(0,0,0,0.4); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 10px 14px; color: #fff; font-size: 0.95rem;",
                        placeholder: "Ex: PC Principal / Notebook Dell",
                        value: "{device_name()}",
                        oninput: move |e| device_name.set(e.value().clone()),
                    }
                }

                if saved_feedback() {
                    div { 
                        "✓ Perfil local salvo no vault.db!"
                    }
                }

                div { 
                    button {
                        style: "background: rgba(255,255,255,0.1); border: none; border-radius: 8px; padding: 10px 16px; color: #fff; font-size: 0.9rem; cursor: pointer;",
                        onclick: move |_| is_open.set(false),
                        "Usar sem conta"
                    }
                    button {
                        style: "background: linear-gradient(135deg, #00e1ff, #3b82f6); border: none; border-radius: 8px; padding: 10px 20px; color: #fff; font-weight: 600; font-size: 0.9rem; cursor: pointer;",
                        onclick: on_save,
                        "Salvar Perfil"
                    }
                }
            }
        }
    }
}

#[component]
pub fn SettingsView(
    ai_config: Signal<AiConfig>,
    user_profile: Signal<Option<UserProfile>>,
) -> Element {
    let mut active_section = use_signal(|| "geral".to_string());

    // State for Geral
    let mut auto_save = use_signal(|| true);
    let mut startup_open_last = use_signal(|| true);

    // State for Visual
    let mut theme_mode = use_signal(|| "cyberpunk".to_string());
    let mut ui_scale = use_signal(|| "100%".to_string());

    // State for Sync
    let mut p2p_enabled = use_signal(|| true);
    let mut sync_interval = use_signal(|| "50ms".to_string());

    // State for IA
    let mut temp_api_key = use_signal(|| ai_config().api_key.clone());
    let mut temp_provider = use_signal(|| match ai_config().provider {
        AiProvider::Auto => "auto",
        AiProvider::Gemini => "gemini",
        AiProvider::OpenAI => "openai",
        AiProvider::Ollama => "ollama",
    }.to_string());
    let mut temp_model = use_signal(|| ai_config().model.clone());

    let save_ai_settings = move |_| {
        let mut cfg = ai_config();
        cfg.api_key = temp_api_key();
        cfg.model = temp_model();
        cfg.provider = match temp_provider().as_str() {
            "gemini" => AiProvider::Gemini,
            "openai" => AiProvider::OpenAI,
            "ollama" => AiProvider::Ollama,
            _ => AiProvider::Auto,
        };
        ai_config.set(cfg);
    };

    rsx! {
        div {
            class: "moscaro settings-modal",
            style: "width: 100%; height: 100%; display: flex; flex-direction: column; z-index: 10;",

            // HEADER DA NOTA DE CONFIGURAÇÕES
            div { style: "display: flex; justify-content: space-between; align-items: center; padding: 20px 32px; border-bottom: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.02);",
                div { style: "display: flex; align-items: center; gap: 12px;",
                    span { style: "font-size: 1.6rem;", "⚙️" }
                    div {
                        h2 { style: "margin: 0; font-size: 1.35rem; font-weight: 700; background: linear-gradient(135deg, #fff, #00e1ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent;",
                            "Configurações do Sistema"
                        }
                        span { style: "font-size: 0.8rem; color: rgba(255,255,255,0.5);", "Ajustes gerais, aparência visual, sincronização P2P e IA" }
                    }
                }
            }

                // BODY COM SIDEBAR DE SEÇÕES E CONTEÚDO
                div { style: "display: flex; flex: 1; overflow: hidden;",
                    // SEÇÕES SIDEBAR
                    div { style: "width: 200px; background: rgba(0,0,0,0.25); border-right: 1px solid rgba(255,255,255,0.08); padding: 16px 12px; display: flex; flex-direction: column; gap: 6px;",
                        button {
                            style: if active_section() == "geral" { "background: rgba(0, 225, 255, 0.15); color: #00e1ff; font-weight: 600; text-align: left; padding: 10px 14px; border-radius: 8px; border: 1px solid rgba(0, 225, 255, 0.3); cursor: pointer;" } else { "background: none; color: rgba(255,255,255,0.7); text-align: left; padding: 10px 14px; border-radius: 8px; border: none; cursor: pointer;" },
                            onclick: move |_| active_section.set("geral".to_string()),
                            "⚙️ Geral"
                        }
                        button {
                            style: if active_section() == "visual" { "background: rgba(0, 225, 255, 0.15); color: #00e1ff; font-weight: 600; text-align: left; padding: 10px 14px; border-radius: 8px; border: 1px solid rgba(0, 225, 255, 0.3); cursor: pointer;" } else { "background: none; color: rgba(255,255,255,0.7); text-align: left; padding: 10px 14px; border-radius: 8px; border: none; cursor: pointer;" },
                            onclick: move |_| active_section.set("visual".to_string()),
                            "🎨 Visual"
                        }
                        button {
                            style: if active_section() == "sync" { "background: rgba(0, 225, 255, 0.15); color: #00e1ff; font-weight: 600; text-align: left; padding: 10px 14px; border-radius: 8px; border: 1px solid rgba(0, 225, 255, 0.3); cursor: pointer;" } else { "background: none; color: rgba(255,255,255,0.7); text-align: left; padding: 10px 14px; border-radius: 8px; border: none; cursor: pointer;" },
                            onclick: move |_| active_section.set("sync".to_string()),
                            "🔄 Sincronização"
                        }
                        button {
                            style: if active_section() == "ia" { "background: rgba(0, 225, 255, 0.15); color: #00e1ff; font-weight: 600; text-align: left; padding: 10px 14px; border-radius: 8px; border: 1px solid rgba(0, 225, 255, 0.3); cursor: pointer;" } else { "background: none; color: rgba(255,255,255,0.7); text-align: left; padding: 10px 14px; border-radius: 8px; border: none; cursor: pointer;" },
                            onclick: move |_| active_section.set("ia".to_string()),
                            "✨ Inteligência Artificial"
                        }
                    }

                    // CONTEÚDO DA SEÇÃO ATIVA
                    div { style: "flex: 1; padding: 24px 32px; overflow-y: auto;",
                        if active_section() == "geral" {
                            div { style: "display: flex; flex-direction: column; gap: 20px;",
                                h3 { style: "margin: 0; font-size: 1.1rem; color: #00e1ff;", "Configurações Gerais" }
                                div { style: "display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.03); padding: 14px 18px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.06);",
                                    div {
                                        div { style: "font-weight: 600;", "Salvamento Automático no Cofre" }
                                        div { style: "font-size: 0.8rem; color: rgba(255,255,255,0.5);", "Grava alterações instantaneamente no banco vault.db e no disco local." }
                                    }
                                    input {
                                        r#type: "checkbox",
                                        checked: auto_save(),
                                        style: "width: 18px; height: 18px; cursor: pointer;",
                                        onchange: move |_| auto_save.toggle()
                                    }
                                }
                                div { style: "display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.03); padding: 14px 18px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.06);",
                                    div {
                                        div { style: "font-weight: 600;", "Restaurar Últimas Abas ao Iniciar" }
                                        div { style: "font-size: 0.8rem; color: rgba(255,255,255,0.5);", "Abre automaticamente os documentos que estavam ativos na sessão anterior." }
                                    }
                                    input {
                                        r#type: "checkbox",
                                        checked: startup_open_last(),
                                        style: "width: 18px; height: 18px; cursor: pointer;",
                                        onchange: move |_| startup_open_last.toggle()
                                    }
                                }
                            }
                        } else if active_section() == "visual" {
                            div { style: "display: flex; flex-direction: column; gap: 20px;",
                                h3 { style: "margin: 0; font-size: 1.1rem; color: #00e1ff;", "Aparência & Tema Visual" }
                                div { style: "display: flex; flex-direction: column; gap: 8px;",
                                    label { style: "font-size: 0.85rem; color: rgba(255,255,255,0.8);", "Tema da Interface:" }
                                    select {
                                        
                                        value: "{theme_mode()}",
                                        onchange: move |e| theme_mode.set(e.value().clone()),
                                        option { value: "cyberpunk", "Cyberpunk Liquid Glass (Escuro)" }
                                        option { value: "moscaro", "Moscaro Minimalist Light" }
                                        option { value: "dracula", "Dracula Neon Purple" }
                                    }
                                }
                                div { style: "display: flex; flex-direction: column; gap: 8px;",
                                    label { style: "font-size: 0.85rem; color: rgba(255,255,255,0.8);", "Escala de Zoom da Interface:" }
                                    select {
                                        
                                        value: "{ui_scale()}",
                                        onchange: move |e| ui_scale.set(e.value().clone()),
                                        option { value: "90%", "Compacto (90%)" }
                                        option { value: "100%", "Padrão (100%)" }
                                        option { value: "110%", "Expandido (110%)" }
                                    }
                                }
                            }
                        } else if active_section() == "sync" {
                            div { style: "display: flex; flex-direction: column; gap: 20px;",
                                h3 { style: "margin: 0; font-size: 1.1rem; color: #00e1ff;", "Sincronização P2P & Rede Local" }
                                div { style: "display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.03); padding: 14px 18px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.06);",
                                    div {
                                        div { style: "font-weight: 600;", "Ativar Sincronização P2P Wi-Fi" }
                                        div { style: "font-size: 0.8rem; color: rgba(255,255,255,0.5);", "Permite que aparelhos pareados via PIN conversem na rede local." }
                                    }
                                    input {
                                        r#type: "checkbox",
                                        checked: p2p_enabled(),
                                        style: "width: 18px; height: 18px; cursor: pointer;",
                                        onchange: move |_| p2p_enabled.toggle()
                                    }
                                }
                                div { style: "display: flex; flex-direction: column; gap: 8px;",
                                    label { style: "font-size: 0.85rem; color: rgba(255,255,255,0.8);", "Taxa de Atualização de Deltas:" }
                                    select {
                                        
                                        value: "{sync_interval()}",
                                        onchange: move |e| sync_interval.set(e.value().clone()),
                                        option { value: "50ms", "Ultra Rápido (50ms - 60 FPS)" }
                                        option { value: "150ms", "Equilibrado (150ms)" }
                                        option { value: "500ms", "Economia de Energia (500ms)" }
                                    }
                                }
                            }
                        } else if active_section() == "ia" {
                            div { style: "display: flex; flex-direction: column; gap: 16px;",
                                h3 { style: "margin: 0; font-size: 1.1rem; color: #00e1ff;", "Configurações do Assistente de IA" }
                                div { style: "display: flex; flex-direction: column; gap: 6px;",
                                    label { style: "font-size: 0.85rem; color: rgba(255,255,255,0.8);", "Provedor de IA:" }
                                    select {
                                        
                                        value: "{temp_provider()}",
                                        onchange: move |e| temp_provider.set(e.value().clone()),
                                        option { value: "auto", "Auto (Provedor Automático)" }
                                        option { value: "gemini", "Google Gemini API" }
                                        option { value: "openai", "OpenAI ChatGPT" }
                                        option { value: "ollama", "Ollama (IA Local 100% Offline)" }
                                    }
                                }
                                div { style: "display: flex; flex-direction: column; gap: 6px;",
                                    label { style: "font-size: 0.85rem; color: rgba(255,255,255,0.8);", "Chave de API (API Key):" }
                                    input {
                                        r#type: "password",
                                        
                                        placeholder: "Cole sua chave de API aqui",
                                        value: "{temp_api_key()}",
                                        oninput: move |e| temp_api_key.set(e.value().clone())
                                    }
                                }
                                button {
                                    style: "align-self: flex-end; background: linear-gradient(135deg, #00e1ff, #3b82f6); border: none; border-radius: 8px; padding: 10px 20px; color: #fff; font-weight: 600; cursor: pointer; margin-top: 10px;",
                                    onclick: save_ai_settings,
                                    "Salvar Configurações de IA"
                                }
                            }
                        }
                    }
                }
        }
    }
}
