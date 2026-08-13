#![allow(non_snake_case)]
mod db;

use dioxus::desktop::{Config, LogicalPosition, LogicalSize, WindowBuilder};
use dioxus::prelude::*;

mod i18n;
mod components;
mod icons;
mod types;
mod ai;
mod vault_sync;
mod sync;

pub use components::*;
pub use icons::*;
pub use types::*;
pub use ai::*;
pub use vault_sync::*;
pub use sync::*;

fn main() {
    env_logger::init();

    let data_dir = std::env::temp_dir().join(format!("dioxus_cn_vault_data_{}", std::process::id()));
    let _ = std::fs::create_dir_all(&data_dir);

    let config = Config::new()
        .with_data_directory(data_dir)
        .with_custom_head(format!("<style>{}</style>", STYLE_CSS))
        .with_window(
            WindowBuilder::new()
                .with_title("conNotes - Liquid Glass Canvas (100% Pure Rust)")
                .with_inner_size(LogicalSize::new(1440.0, 900.0))
                .with_position(LogicalPosition::new(80.0, 80.0))
                .with_resizable(true)
                .with_visible(true)
                .with_focused(true),
        );

    LaunchBuilder::desktop().with_cfg(config).launch(App);
}

const STYLE_CSS: &str = include_str!("../assets/moscaro-v2.css");

#[component]
pub fn IconLogo() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 24px; height: 24px; fill: none; stroke: url(#neon-gradient); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round; filter: drop-shadow(0 0 8px rgba(0,225,255,0.8));",
            defs {
                linearGradient { id: "neon-gradient", x1: "0%", y1: "0%", x2: "100%", y2: "100%",
                    stop { offset: "0%", stop_color: "#00e1ff" }
                    stop { offset: "100%", stop_color: "#a855f7" }
                }
            }
            path { d: "M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" }
        }
    }
}

#[component]
fn App() -> Element {
    println!("APP COMPONENT MOUNTING!");

    let (discovery, engine) = use_hook(|| {
        let device_id = uuid::Uuid::new_v4().to_string();

        let (listener, actual_port) = SyncEngine::bind_listener(44223);

        let discovery = PeerDiscovery::new(device_id.clone(), actual_port);
        discovery.start();

        let engine = SyncEngine::new(device_id, actual_port);
        engine.start_server(listener);

        (discovery, engine)
    });

    // App Settings Global Web Audio Context Initialization
    use_hook(|| {
        let _ = document::eval(
            r#"
            if(!window.audioCtx) {
                window.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            }
            window.playSynthSound = function(type, volume) {
                if(!window.audioCtx || volume <= 0) return;
                const osc = window.audioCtx.createOscillator();
                const gain = window.audioCtx.createGain();
                osc.connect(gain);
                gain.connect(window.audioCtx.destination);
                if(type === 'click') {
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(800, window.audioCtx.currentTime);
                    osc.frequency.exponentialRampToValueAtTime(300, window.audioCtx.currentTime + 0.1);
                    gain.gain.setValueAtTime(volume, window.audioCtx.currentTime);
                    gain.gain.exponentialRampToValueAtTime(0.01, window.audioCtx.currentTime + 0.1);
                    osc.start();
                    osc.stop(window.audioCtx.currentTime + 0.1);
                } else if (type === 'connect') {
                    osc.type = 'triangle';
                    osc.frequency.setValueAtTime(400, window.audioCtx.currentTime);
                    osc.frequency.setValueAtTime(600, window.audioCtx.currentTime + 0.1);
                    gain.gain.setValueAtTime(volume, window.audioCtx.currentTime);
                    gain.gain.exponentialRampToValueAtTime(0.01, window.audioCtx.currentTime + 0.2);
                    osc.start();
                    osc.stop(window.audioCtx.currentTime + 0.2);
                }
            };

            window.addEventListener('mousedown', (e) => {
                if (e.target.closest('button') || e.target.closest('.tab, .tool-btn, .sidebar-item, .card-header') || e.target.closest('[role="button"]')) {
                    if (window.uiVolume > 0) {
                        window.playSynthSound('click', window.uiVolume);
                    }
                }
            });
            window.addEventListener('mousemove', (e) => {
                document.documentElement.style.setProperty('--mouse-x', e.clientX + 'px');
                document.documentElement.style.setProperty('--mouse-y', e.clientY + 'px');
            });
            "#
        );
    });

    let (initial_folders, initial_notes, initial_visual, initial_ai, initial_app) = use_hook(|| {
        let mut v = VisualConfig::default();
        let mut a = AiConfig::default();
        let mut p = AppSettings::default();
        if let Ok(conn) = db::init_db("vault.db") {
            if let Ok(Some(vs)) = db::load_setting(&conn, "visual_config") {
                if let Ok(parsed) = serde_json::from_str(&vs) { v = parsed; }
            }
            if let Ok(Some(as_)) = db::load_setting(&conn, "ai_config") {
                if let Ok(parsed) = serde_json::from_str(&as_) { a = parsed; }
            }
            if let Ok(Some(ps_)) = db::load_setting(&conn, "app_settings") {
                if let Ok(parsed) = serde_json::from_str(&ps_) { p = parsed; }
            }
            if let Ok((f, n)) = db::load_all(&conn) {
                if !f.is_empty() || !n.is_empty() {
                    return (f, n, v, a, p);
                }
            }
        }
        let (disk_f, disk_n) = vault_sync::load_vault_from_disk();
        if !disk_f.is_empty() || !disk_n.is_empty() {
            return (disk_f, disk_n, v, a, p);
        }
        let (sf, sn) = db::seed_default_data();
        (sf, sn, v, a, p)
    });

    let mut folders = use_signal(|| initial_folders);
    let mut notes = use_signal(|| initial_notes);
    let mut dragging_card_id = use_signal(|| Option::<usize>::None);
    let mut is_drawing = use_signal(|| false);
    
    let mut visual_config = use_signal(|| initial_visual);
    let mut ai_config = use_signal(|| initial_ai);
    let mut app_settings = use_signal(|| initial_app);

    // Save settings automatically on change
    use_effect(move || {
        let vc = visual_config();
        let ac = ai_config();
        let aps = app_settings();
        if let Ok(conn) = db::init_db("vault.db") {
            let _ = db::save_setting(&conn, "visual_config", &serde_json::to_string(&vc).unwrap_or_default());
            let _ = db::save_setting(&conn, "ai_config", &serde_json::to_string(&ac).unwrap_or_default());
            let _ = db::save_setting(&conn, "app_settings", &serde_json::to_string(&aps).unwrap_or_default());
        }
    });

    // Sync volume to JS global
    use_effect(move || {
        let is_audio = app_settings().sound_enabled;
        let vol = if is_audio { app_settings().ui_volume.parse::<f32>().unwrap_or(50.0) / 100.0 } else { 0.0 };
        let _ = document::eval(&format!("window.uiVolume = {};", vol));
    });

    // Flag atômica para prevenir o "Echo Loop" (re-transmissão de atualizações vindas da rede)
    let is_network_update = use_hook(|| std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)));

    // Receptor assíncrono Dioxus para atualizações de rede local via WebSocket (executado uma única vez)
    let engine_for_recv = engine.clone();
    let net_update_recv = is_network_update.clone();
    use_hook(move || {
        spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                if dragging_card_id.peek().is_none() && !*is_drawing.peek() {
                    if let Some(delta) = engine_for_recv.take_latest_delta() {
                        net_update_recv.store(true, std::sync::atomic::Ordering::SeqCst);
                        match delta {
                            crate::types::OperationDelta::FullSync { folders: inc_f, notes: inc_n } => {
                                folders.set(inc_f);
                                notes.set(inc_n);
                            }
                            crate::types::OperationDelta::MoveCard { note_id, card_id, x, y } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                                            card.x = x;
                                            card.y = y;
                                        }
                                    }
                                });
                            }
                            crate::types::OperationDelta::ResizeCard { note_id, card_id, width, height } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                                            card.width = width;
                                            card.height = height;
                                        }
                                    }
                                });
                            }
                            crate::types::OperationDelta::AddCard { note_id, card } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        if !note.cards.iter().any(|c| c.id == card.id) {
                                            note.cards.push(card);
                                        }
                                    }
                                });
                            }
                            crate::types::OperationDelta::DeleteCard { note_id, card_id } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        note.cards.retain(|c| c.id != card_id);
                                    }
                                });
                            }
                            crate::types::OperationDelta::AddStroke { note_id, stroke } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        note.strokes.push(stroke);
                                    }
                                });
                            }
                            crate::types::OperationDelta::ClearStrokes { note_id } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        note.strokes.clear();
                                    }
                                });
                            }
                            crate::types::OperationDelta::UpdateCardText { note_id, card_id, content } => {
                                notes.with_mut(|n_list| {
                                    if let Some(note) = n_list.iter_mut().find(|n| n.id == note_id) {
                                        if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                                            card.content = content;
                                        }
                                    }
                                });
                            }
                            _ => {}
                        }
                    }
                }
            }
        });
    });

    // 2. NAVEGAÇÃO REATIVA POR ABAS (TAB BAR)
    let mut open_tab_ids = use_signal(|| vec![1usize, 2usize]);
    let mut active_tab_id = use_signal(|| Some(1usize));

    // Forçar foco, restauração e verificar abertura por clique duplo no Windows (cli args)
    use_effect(move || {
        let window = dioxus::desktop::window();
        window.set_minimized(false);
        window.set_always_on_top(true);
        window.set_focus();
        window.set_always_on_top(false);

        if let Some(arg) = std::env::args().nth(1) {
            let path = std::path::Path::new(&arg);
            if path.exists() && path.extension().map_or(false, |ext| ext == "cncanvas") {
                if let Ok(opened_note) = vault_sync::load_note_from_file(path) {
                    let open_id = opened_note.id;
                    notes.with_mut(|n_list| {
                        if !n_list.iter().any(|n| n.id == open_id) {
                            n_list.push(opened_note);
                        }
                    });
                    open_tab_ids.with_mut(|tabs| {
                        if !tabs.contains(&open_id) {
                            tabs.push(open_id);
                        }
                    });
                    active_tab_id.set(Some(open_id));
                }
            }
        }
    });

    // Salvamento automático e broadcast P2P (protegido contra Echo Loop)
    let discovery_for_save = discovery.clone();
    let engine_for_save = engine.clone();
    let net_update_save = is_network_update.clone();
    use_effect(move || {
        let current_folders = folders();
        let current_notes = notes();
        let is_dragging = dragging_card_id().is_some();
        let is_currently_drawing = is_drawing();
        let discovery_clone = discovery_for_save.clone();
        let engine_clone = engine_for_save.clone();
        let was_net_update = net_update_save.swap(false, std::sync::atomic::Ordering::SeqCst);

        static SAVE_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
        std::thread::spawn(move || {
            if let Ok(_guard) = SAVE_LOCK.lock() {
                if let Ok(mut conn) = db::init_db("vault.db") {
                    let _ = db::save_all(&mut conn, &current_folders, &current_notes);
                }
                let _ = vault_sync::sync_vault_to_disk(&current_folders, &current_notes);
                
                // Transmite apenas se for uma alteração LOCAL do usuário
                if !was_net_update && !is_dragging && !is_currently_drawing {
                    let peers = discovery_clone.get_active_peers();
                    engine_clone.broadcast_to_peers(&peers, &current_folders, &current_notes);
                }
            }
        });
    });

    // 3. OMNIBAR DE BUSCA (CTRL + K OU CAMPO NA SIDEBAR)
    let mut omnibar_open = use_signal(|| false);
    let mut search_query = use_signal(|| String::new());

    // 4. ESTADOS DE INTERFACE, DROPDOWNS E MODOS DE PAPEL
    let mut sidebar_open = use_signal(|| true);
    let mut tool_mode = use_signal(|| "select".to_string());
    let mut paper_mode = use_signal(|| PaperMode::DotGrid);

    // ISOLAMENTO INDEPENDENTE DE CORES E ESPESSURAS ENTRE CANETA E MARCA-TEXTO
    let mut pen_color = use_signal(|| "#00e1ff".to_string());
    let mut pen_thickness = use_signal(|| 3.0f64);
    let mut hl_color = use_signal(|| "#22c55e".to_string());
    let mut hl_thickness = use_signal(|| 8.0f64);

    // ESTADOS DOS MENUS EXPANSÍVEIS E MODAIS DE AUTENTICAÇÃO/PAREAMENTO
    let mut is_note_type_menu_open = use_signal(|| false);
    let mut is_paper_menu_open = use_signal(|| false);
    let mut is_add_card_menu_open = use_signal(|| false);
    let mut pairing_modal_open = use_signal(|| false);
    let mut profile_modal_open = use_signal(|| false);
    let mut settings_modal_open = use_signal(|| false);

    let initial_profile = use_hook(|| {
        if let Ok(conn) = db::init_db("vault.db") {
            if let Ok(p) = db::load_user_profile(&conn) {
                return p;
            }
        }
        None
    });
    let mut user_profile = use_signal(|| initial_profile);

    let pairing_pin = use_signal(|| {
        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(123456);
        let pin_str = format!("{:03}-{:03}", (ts % 899 + 100), ((ts / 100) % 899 + 100));
        engine.set_pin(pin_str.clone());
        pin_str
    });
    let peer_count = discovery.get_active_peers().len();
    let mut pending_card_type = use_signal(|| Option::<String>::None);
    let mut subnote_parent_target = use_signal(|| Option::<usize>::None);
    let mut folder_target_for_new_note = use_signal(|| Option::<usize>::None);
    let mut editing_folder_id = use_signal(|| Option::<usize>::None);
    let mut editing_note_id = use_signal(|| Option::<usize>::None);
    let mut editing_title_card_id = use_signal(|| Option::<usize>::None);

    // DRAG AND DROP NA SIDEBAR (MOUSE-BASED REORDERING)
    let mut dragged_sidebar_note_id = use_signal(|| Option::<usize>::None);
    let mut sidebar_drag_target_id = use_signal(|| Option::<usize>::None);

    // 5. ESTADOS DO CANVAS INFINITO (RESTRIÇÃO ESTRITA AO 4º QUADRANTE COM ELASTIC BOUNCE ANIMAÇÃO)
    let mut pan_x = use_signal(|| 0.0f64);
    let mut pan_y = use_signal(|| 0.0f64);
    let mut zoom = use_signal(|| 1.0f64);
    let mut is_panning = use_signal(|| false);
    let mut pan_start = use_signal(|| (0.0f64, 0.0f64));

    // 6. ESTADOS DE DESENHO VETORIAL E CONECTORES
    let mut current_stroke = use_signal(|| Option::<Stroke>::None);
    let mut is_connecting = use_signal(|| false);
    let mut connecting_from_id = use_signal(|| Option::<usize>::None);
    let mut temp_connector_end = use_signal(|| (0.0f64, 0.0f64));
    let mut drag_offset = use_signal(|| (0.0f64, 0.0f64));

    let mut resizing_card_id = use_signal(|| Option::<usize>::None);
    let mut resize_handle = use_signal(|| Option::<String>::None);
    let mut resize_start_mouse = use_signal(|| (0.0f64, 0.0f64));
    let mut resize_start_card = use_signal(|| (0.0f64, 0.0f64, 0.0f64, 0.0f64));

    // 7. SELEÇÃO DE CONECTORES E ALINHAMENTO
    let mut selected_connector_id = use_signal(|| Option::<usize>::None);
    let mut selected_connector_pos = use_signal(|| Option::<(f64, f64)>::None);
    let mut snap_guides = use_signal(|| (Option::<f64>::None, Option::<f64>::None));

    // ESTADOS DE COPIAR/COLAR E ÁREA DE SELEÇÃO POR ARRASTE
    let mut copied_cards = use_signal(|| Vec::<NoteCard>::new());
    let mut is_box_selecting = use_signal(|| false);
    let mut box_select_start = use_signal(|| (0.0f64, 0.0f64));
    let mut box_select_rect = use_signal(|| Option::<(f64, f64, f64, f64)>::None);

    // ESTADOS DA INTEGRAÇÃO DE INTELIGÊNCIA ARTIFICIAL (IA)
    let mut ai_modal_open = use_signal(|| false);
    let mut ai_context_text = use_signal(|| String::new());
    let mut ai_selected_card_id = use_signal(|| Option::<usize>::None);

    let mut open_ai_modal_for_context = move |(ctx, card_id): (String, Option<usize>)| {
        ai_context_text.set(ctx);
        ai_selected_card_id.set(card_id);
        ai_modal_open.set(true);
    };

    // TRACKING MOUSE POSITION FOR DRAG FOLLOWER
    let mut mouse_x = use_signal(|| 0.0f64);
    let mut mouse_y = use_signal(|| 0.0f64);

    let mut handle_start_resize = move |(card_id, handle_id, start_w, start_h, start_x, start_y): (usize, String, f64, f64, f64, f64)| {
        if let Some(aid) = active_tab_id() {
            let is_locked = notes().iter().find(|n| n.id == aid).and_then(|n| n.cards.iter().find(|c| c.id == card_id)).map(|c| c.locked).unwrap_or(false);
            if is_locked {
                return;
            }
        }
        resizing_card_id.set(Some(card_id));
        resize_handle.set(Some(handle_id));
        resize_start_mouse.set((mouse_x(), mouse_y()));
        resize_start_card.set((start_x, start_y, start_w, start_h));
    };

    // FUNÇÕES AUXILIARES DE GERENCIAMENTO DE ABAS E NOTAS
    let mut open_note_in_tab = move |note_id: usize| {
        if !open_tab_ids().contains(&note_id) {
            open_tab_ids.with_mut(|tabs| tabs.push(note_id));
        }
        active_tab_id.set(Some(note_id));
    };

    let mut close_tab = move |note_id: usize| {
        open_tab_ids.with_mut(|tabs| {
            tabs.retain(|&id| id != note_id);
        });
        if active_tab_id() == Some(note_id) {
            active_tab_id.set(open_tab_ids().last().copied());
        }
    };

    let mut create_new_note_with_type =
        move |card_type: String, parent_id: Option<usize>, folder_id: Option<usize>| {
            let max_id = notes().iter().map(|n| n.id).max().unwrap_or(0);
            let new_id = max_id + 1;
            let note_title = match card_type.as_str() {
                "canvas" => format!("Novo Canvas {}", new_id),
                "text" => format!("Documento de Texto {}", new_id),
                "pdf" => format!("Documento PDF {}", new_id),
                "code" => format!("Documento Código {}", new_id),
                _ => format!("Nova Nota {}", new_id),
            };
            let icon = card_type.clone();

            let target_folder = folder_id.or(folder_target_for_new_note());

            let new_note = NoteItem {
                id: new_id,
                title: note_title,
                note_type: Some(card_type),
                parent_id,
                folder_id: target_folder,
                icon,
                tags: vec!["#geral".to_string()],
                cards: vec![NoteCard {
                    id: new_id * 1000 + 1,
                    number: "1".to_string(),
                    title: "Minha Anotação".to_string(),
                    content: "Escreva suas anotações aqui...".to_string(),
                    card_type: "text".to_string(),
                    x: 350.0,
                    y: 180.0,
                    width: 320.0,
                    height: 200.0,
                    selected: true,
                    collapsed: false,
                    locked: false,
                    accent_color: None,
                }],
                connectors: vec![],
                strokes: vec![],
                paper_mode: Some(PaperMode::DotGrid),
            };
            notes.with_mut(|n_list| n_list.push(new_note));
            open_note_in_tab(new_id);
            editing_note_id.set(Some(new_id));
            is_note_type_menu_open.set(false);
            subnote_parent_target.set(None);
            folder_target_for_new_note.set(None);
        };

    let mut add_folder_directly = move |parent_id: Option<usize>| {
        let max_id = folders().iter().map(|f| f.id).max().unwrap_or(9000);
        let next_id = max_id + 1;
        folders.with_mut(|f_list| {
            f_list.push(FolderItem {
                id: next_id,
                name: "Nova Pasta".to_string(),
                expanded: true,
                parent_id,
            });
        });
        editing_folder_id.set(Some(next_id));
        is_note_type_menu_open.set(false);
        subnote_parent_target.set(None);
        folder_target_for_new_note.set(None);
    };

    let mut set_paper_mode_for_active_note = move |pm: PaperMode| {
        paper_mode.set(pm);
        if let Some(act_id) = active_tab_id() {
            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                    note.paper_mode = Some(pm);
                }
            });
        }
        is_paper_menu_open.set(false);
    };

    use_effect(move || {
        if let Some(act_id) = active_tab_id() {
            if let Some(note) = notes().iter().find(|n| n.id == act_id) {
                if let Some(pm) = note.paper_mode {
                    paper_mode.set(pm);
                } else {
                    paper_mode.set(PaperMode::DotGrid);
                }
            }
        }
    });

    let mut add_card_to_active_note = move |card_type: String| {
        pending_card_type.set(Some(card_type));
        is_add_card_menu_open.set(false);
    };

    let mut update_card_title = move |card_id: usize, new_title: String| {
        if let Some(act_id) = active_tab_id() {
            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                    if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                        card.title = new_title;
                    }
                }
            });
        }
    };

    let mut update_card_content = move |card_id: usize, new_content: String| {
        if let Some(act_id) = active_tab_id() {
            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                    if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                        card.content = new_content;
                    }
                }
            });
        }
    };

    // DRAG AND DROP DA SIDEBAR FOR REORDERING & NESTING
    let mut handle_sidebar_drop =
        move |target_note_id: Option<usize>, target_folder_id: Option<usize>| {
            if let Some(src_id) = dragged_sidebar_note_id() {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == src_id) {
                        note.folder_id = target_folder_id;
                        note.parent_id = target_note_id;
                    }
                });
            }
            dragged_sidebar_note_id.set(None);
            sidebar_drag_target_id.set(None);
        };

    // LISTENER GLOBAL DE PASTE NO CANVAS VIA JAVASCRIPT
    use_effect(move || {
        let mut eval = document::eval(
            r#"
            window.addEventListener('paste', async (event) => {
                if (document.activeElement && (['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName) || document.activeElement.isContentEditable)) {
                    return;
                }
                const items = event.clipboardData && event.clipboardData.items;
                if (!items) return;
                for (let i = 0; i < items.length; i++) {
                    const item = items[i];
                    if (item.type.indexOf('image') !== -1) {
                        const blob = item.getAsFile();
                        if (blob) {
                            const reader = new FileReader();
                            reader.onload = (e) => {
                                dioxus.send(e.target.result);
                            };
                            reader.readAsDataURL(blob);
                        }
                    }
                }
            });
            "#
        );
        spawn(async move {
            while let Ok(img_data) = eval.recv::<String>().await {
                if !img_data.is_empty() {
                    if let Some(act_id) = active_tab_id() {
                        let cur_mouse_x = mouse_x();
                        let cur_mouse_y = mouse_y();
                        let canvas_x = ((cur_mouse_x - pan_x()) / zoom()).max(0.0);
                        let canvas_y = ((cur_mouse_y - pan_y()) / zoom()).max(0.0);
                        notes.with_mut(|n_list| {
                            if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                let count = note.cards.len();
                                let next_card_id = act_id * 100 + count + 1;
                                let (w, h) = (340.0, 260.0);
                                note.cards.push(NoteCard {
                                    id: next_card_id,
                                    number: (count + 1).to_string(),
                                    card_type: "image".to_string(),
                                    title: "Imagem".to_string(),
                                    content: img_data,
                                    x: (canvas_x - w / 2.0).max(0.0),
                                    y: (canvas_y - h / 2.0).max(0.0),
                                    width: w,
                                    height: h,
                                    selected: true,
                                    collapsed: false,
                                    locked: false,
                                    accent_color: None,
                                });
                            }
                        });
                    }
                }
            }
        });
    });

    // GERENCIADOR DE COLAGEM (PASTE) GLOBAL NO CANVAS VIA CTRL+V OU ONPASTE
    let perform_canvas_paste = move || {
        let eval_runner = document::eval(
            r#"
            (async () => {
                try {
                    const items = await navigator.clipboard.read();
                    for (const item of items) {
                        for (const type of item.types) {
                            if (type.startsWith('image/')) {
                                const blob = await item.getType(type);
                                const reader = new FileReader();
                                return new Promise((resolve) => {
                                    reader.onload = () => resolve(reader.result);
                                    reader.readAsDataURL(blob);
                                });
                            }
                        }
                    }
                } catch (err) {}
                try {
                    const text = await navigator.clipboard.readText();
                    if (text) return text;
                } catch (err) {}
                return "";
            })()
            "#,
        );
        spawn(async move {
            if let Ok(res) = eval_runner.await {
                if let Some(content_str) = res.as_str() {
                    if !content_str.is_empty() {
                        if let Some(act_id) = active_tab_id() {
                            let cur_mouse_x = mouse_x();
                            let cur_mouse_y = mouse_y();
                            let canvas_x = ((cur_mouse_x - pan_x()) / zoom()).max(0.0);
                            let canvas_y = ((cur_mouse_y - pan_y()) / zoom()).max(0.0);
                            notes.with_mut(|n_list| {
                                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                    let count = note.cards.len();
                                    let next_card_id = act_id * 100 + count + 1;
                                    let is_image = content_str.starts_with("data:image/");
                                    let card_type = if is_image { "image" } else { "text" };
                                    let title = if is_image { "Imagem" } else { "Nota Colada" };
                                    let (w, h) = if is_image { (340.0, 260.0) } else { (320.0, 200.0) };
                                    note.cards.push(NoteCard {
                                        id: next_card_id,
                                        number: (count + 1).to_string(),
                                        card_type: card_type.to_string(),
                                        title: title.to_string(),
                                        content: content_str.to_string(),
                                        x: (canvas_x - w / 2.0).max(0.0),
                                        y: (canvas_y - h / 2.0).max(0.0),
                                        width: w,
                                        height: h,
                                        selected: true,
                                        collapsed: false,
                                        locked: false,
                                        accent_color: None,
                                    });
                                }
                            });
                        }
                    }
                }
            }
        });
    };

    // HANDLER GLOBAL DE TECLADO
    let mut handle_keydown = move |evt: KeyboardEvent| {
        let is_ctrl = evt.modifiers().ctrl() || evt.modifiers().meta();
        let key_str = match evt.key() {
            Key::Character(ref c) => c.to_uppercase(),
            Key::Delete => "Delete".to_string(),
            Key::Backspace => "Backspace".to_string(),
            Key::Escape => "Escape".to_string(),
            _ => evt.key().to_string(),
        };
        let key_lower = key_str.to_lowercase();
        
        let mut shortcut_parts = Vec::new();
        if is_ctrl { shortcut_parts.push("Ctrl".to_string()); }
        if evt.modifiers().shift() { shortcut_parts.push("Shift".to_string()); }
        if evt.modifiers().alt() { shortcut_parts.push("Alt".to_string()); }
        shortcut_parts.push(key_str);
        
        let shortcut_str = shortcut_parts.join("+");
        let action = app_settings().shortcuts.get(&shortcut_str).cloned().unwrap_or_else(|| {
            if is_ctrl && key_lower == "k" { "omnibar".to_string() }
            else if is_ctrl && key_lower == "d" { "duplicate".to_string() }
            else if is_ctrl && key_lower == "c" { "copy".to_string() }
            else if is_ctrl && key_lower == "v" { "paste".to_string() }
            else if is_ctrl && key_lower == "n" { "new_note".to_string() }
            else if key_lower == "delete" || key_lower == "backspace" { "delete_card".to_string() }
            else if key_lower == "escape" { "escape".to_string() }
            else { "".to_string() }
        });

        if action == "omnibar" {
            omnibar_open.toggle();
            search_query.set(String::new());
        } else if action == "duplicate" {
            let mut is_typing_eval = document::eval(
                r#"
                const el = document.activeElement;
                const isTyping = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
                dioxus.send(Boolean(isTyping));
                "#
            );
            spawn(async move {
                let typing = match is_typing_eval.recv::<bool>().await {
                    Ok(val) => val,
                    Err(_) => false,
                };
                if !typing {
                    if let Some(act_id) = active_tab_id() {
                        notes.with_mut(|n_list| {
                            if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                let selected: Vec<_> = note.cards.iter().filter(|c| c.selected).cloned().collect();
                                if !selected.is_empty() {
                                    for c in note.cards.iter_mut() {
                                        c.selected = false;
                                    }
                                    let max_id = note.cards.iter().map(|c| c.id).max().unwrap_or(0);
                                    for (idx, orig) in selected.into_iter().enumerate() {
                                        let new_id = max_id + 1 + idx;
                                        let mut new_card = orig;
                                        new_card.id = new_id;
                                        new_card.x += 30.0;
                                        new_card.y += 30.0;
                                        new_card.number = format!("{:04}", new_id);
                                        new_card.selected = true;
                                        note.cards.push(new_card);
                                    }
                                }
                            }
                        });
                    }
                }
            });
        } else if action == "copy" {
            let mut is_typing_eval = document::eval(
                r#"
                const el = document.activeElement;
                const isTyping = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
                dioxus.send(Boolean(isTyping));
                "#
            );
            spawn(async move {
                let typing = match is_typing_eval.recv::<bool>().await {
                    Ok(val) => val,
                    Err(_) => false,
                };
                if !typing {
                    if let Some(act_id) = active_tab_id() {
                        if let Some(note) = notes().iter().find(|n| n.id == act_id) {
                            let selected: Vec<_> = note.cards.iter().filter(|c| c.selected).cloned().collect();
                            if !selected.is_empty() {
                                copied_cards.set(selected);
                            }
                        }
                    }
                }
            });
        } else if action == "paste" {
            // Global Ctrl+V canvas paste trigger (ou cole de cards copiados)
            let mut is_typing_eval = document::eval(
                r#"
                dioxus.send(
                    Boolean(
                        document.activeElement && (
                            ['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName) ||
                            document.activeElement.isContentEditable ||
                            document.activeElement.closest('input, textarea, [contenteditable="true"]') !== null
                        )
                    )
                );
                "#
            );
            spawn(async move {
                let typing = match is_typing_eval.recv::<bool>().await {
                    Ok(val) => val,
                    Err(_) => false,
                };
                if !typing {
                    let to_paste = copied_cards();
                    if !to_paste.is_empty() {
                        if let Some(act_id) = active_tab_id() {
                            notes.with_mut(|n_list| {
                                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                    for c in note.cards.iter_mut() {
                                        c.selected = false;
                                    }
                                    let max_id = note.cards.iter().map(|c| c.id).max().unwrap_or(0);
                                    for (idx, orig) in to_paste.into_iter().enumerate() {
                                        let new_id = max_id + 1 + idx;
                                        let mut new_card = orig;
                                        new_card.id = new_id;
                                        new_card.x += 30.0;
                                        new_card.y += 30.0;
                                        new_card.number = format!("{:04}", new_id);
                                        new_card.selected = true;
                                        note.cards.push(new_card);
                                    }
                                }
                            });
                        }
                    } else {
                        perform_canvas_paste();
                    }
                }
            });
        } else if action == "escape" && omnibar_open() {
            omnibar_open.set(false);
        } else if action == "delete_card" {
            // Check if key press was initiated in an input or textarea
            let mut is_typing_eval = document::eval(
                r#"
                const el = document.activeElement;
                const isTyping = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
                dioxus.send(Boolean(isTyping));
                "#
            );
            spawn(async move {
                let typing = match is_typing_eval.recv::<bool>().await {
                    Ok(val) => val,
                    Err(_) => false,
                };
                if !typing {
                    if let Some(act_id) = active_tab_id() {
                        if let Some(conn_id) = selected_connector_id() {
                            notes.with_mut(|n_list| {
                                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                    note.connectors.retain(|c| c.id != conn_id);
                                }
                            });
                            selected_connector_id.set(None);
                            selected_connector_pos.set(None);
                        } else {
                            notes.with_mut(|n_list| {
                                if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                    note.cards.retain(|c| !c.selected);
                                }
                            });
                        }
                    }
                }
            });
        }
    };

    // MOUSE & WHEEL HANDLERS (COM RESTRIÇÃO AO 4º QUADRANTE E ELASTIC BOUNCE ANIMAÇÃO)
    let mut handle_wheel = move |evt: WheelEvent| {
        let delta = evt.delta().strip_units();
        let is_ctrl = evt.modifiers().ctrl() || evt.modifiers().meta();
        let is_shift = evt.modifiers().shift();

        if is_ctrl {
            let new_zoom = (zoom() - delta.y * 0.0012).clamp(0.3, 2.5);
            zoom.set(new_zoom);
        } else if is_shift {
            let amount = if delta.x != 0.0 { delta.x } else { delta.y };
            let raw_x = pan_x() - amount * 1.5;
            let clamped_x = if raw_x > 0.0 { raw_x * 0.25 } else { raw_x };
            pan_x.set(clamped_x);
        } else {
            let raw_y = pan_y() - delta.y * 1.5;
            let clamped_y = if raw_y > 0.0 { raw_y * 0.25 } else { raw_y };
            pan_y.set(clamped_y);
        }
    };

    let mut handle_mouse_down = move |evt: MouseEvent| {
        let active_id = active_tab_id();
        if active_id.is_none() {
            return;
        }
        let raw_coords = evt.client_coordinates();
        let is_middle_click = evt.trigger_button()
            == Some(dioxus::html::input_data::MouseButton::Auxiliary)
            || evt
                .held_buttons()
                .contains(dioxus::html::input_data::MouseButton::Auxiliary);

        // PAN ATIVADO EXCLUSIVAMENTE PELO BOTÃO DO MEIO DO MOUSE
        if is_middle_click {
            is_panning.set(true);
            pan_start.set((raw_coords.x - pan_x(), raw_coords.y - pan_y()));
            return;
        }

        let x = ((raw_coords.x - pan_x()) / zoom()).max(0.0);
        let y = ((raw_coords.y - pan_y()) / zoom()).max(0.0);

        // SE HOUVER UM CARD PENDENTE PARA INSERÇÃO, CRIA ELE NO LOCAL CLICADO
        if let Some(card_type) = pending_card_type() {
            if let Some(act_id) = active_id {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                        let count = note.cards.len();
                        let next_card_id = act_id * 100 + count + 1;
                        let (w, h) = match card_type.as_str() {
                            "plot" | "plot3d" => (360.0, 300.0),
                            "table" => (380.0, 240.0),
                            "image" => (340.0, 260.0),
                            _ => (320.0, 220.0),
                        };
                        let title = match card_type.as_str() {
                            "math" => "Fórmula Matemática".to_string(),
                            "plot" => "Gráfico f(x)".to_string(),
                            "plot3d" => "Gráfico f(x,y)".to_string(),
                            "table" => "Tabela de Dados".to_string(),
                            "image" => "Imagem".to_string(),
                            "flashcard" => "Flashcard 3D".to_string(),
                            _ => "Anotação".to_string(),
                        };
                        note.cards.push(NoteCard {
                            id: next_card_id,
                            number: (count + 1).to_string(),
                            card_type,
                            title,
                            content: String::new(),
                            x: (x - w / 2.0).max(0.0),
                            y: (y - h / 2.0).max(0.0),
                            width: w,
                            height: h,
                            selected: true,
                            collapsed: false,
                            locked: false,
                            accent_color: None,
                        });
                    }
                });
            }
            pending_card_type.set(None);
            return;
        }

        let active_cards = notes()
            .iter()
            .find(|n| Some(n.id) == active_id)
            .map(|n| n.cards.clone())
            .unwrap_or_default();

        let mut clicked_handle = None;
        let mut clicked_card = None;

        for card in active_cards.iter().rev() {
            let inside =
                x >= card.x && x <= card.x + card.width && y >= card.y && y <= card.y + card.height;
            let border_margin = 16.0;
            let near_border = (x - card.x).abs() <= border_margin
                || (x - (card.x + card.width)).abs() <= border_margin
                || (y - card.y).abs() <= border_margin
                || (y - (card.y + card.height)).abs() <= border_margin;

            if (near_border
                && (inside
                    || (x >= card.x - border_margin
                        && x <= card.x + card.width + border_margin
                        && y >= card.y - border_margin
                        && y <= card.y + card.height + border_margin)))
                || tool_mode() == "link"
            {
                clicked_handle = Some(card.id);
                break;
            } else if inside {
                clicked_card = Some(card.id);
                break;
            }
        }

        if let Some(card_id) = clicked_handle {
            is_connecting.set(true);
            connecting_from_id.set(Some(card_id));
            temp_connector_end.set((x, y));
            return;
        }

        if let Some(card_id) = clicked_card {
            selected_connector_id.set(None);
            selected_connector_pos.set(None);
            if let Some(aid) = active_id {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                        for c in note.cards.iter_mut() {
                            c.selected = c.id == card_id;
                        }
                    }
                });
            }
            if tool_mode() == "select" {
                if let Some(card) = active_cards.iter().find(|c| c.id == card_id) {
                    if !card.locked {
                        dragging_card_id.set(Some(card_id));
                        drag_offset.set((x - card.x, y - card.y));
                    }
                }
            }
            return;
        }

        selected_connector_id.set(None);
        selected_connector_pos.set(None);
        if let Some(aid) = active_id {
            notes.with_mut(|n_list| {
                if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                    for c in note.cards.iter_mut() {
                        c.selected = false;
                    }
                }
            });
        }

        if tool_mode() == "select" {
            is_box_selecting.set(true);
            box_select_start.set((x, y));
            box_select_rect.set(Some((x, y, 0.0, 0.0)));
            return;
        }

        if tool_mode() == "pen" || tool_mode() == "highlighter" {
            is_drawing.set(true);
            let is_hl = tool_mode() == "highlighter";
            let color = if is_hl { hl_color() } else { pen_color() };
            let thickness = if is_hl {
                hl_thickness()
            } else {
                pen_thickness()
            };

            current_stroke.set(Some(Stroke {
                points: vec![Point { x, y }],
                color,
                thickness,
                is_highlighter: is_hl,
            }));
        } else if tool_mode() == "eraser" {
            if let Some(aid) = active_id {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                        note.strokes.retain(|stroke| {
                            !stroke
                                .points
                                .iter()
                                .any(|p| (p.x - x).hypot(p.y - y) < 25.0 / zoom())
                        });
                    }
                });
            }
        }
    };

    let mut handle_mouse_move = move |evt: MouseEvent| {
        let raw_coords = evt.client_coordinates();
        mouse_x.set(raw_coords.x);
        mouse_y.set(raw_coords.y);

        if is_panning() {
            let raw_x = raw_coords.x - pan_start().0;
            let raw_y = raw_coords.y - pan_start().1;

            // ELASTIC BOUNCE: RESISTÊNCIA DE MOLA SE TENTAR PUXAR ALÉM DE X=0 OU Y=0
            let px = if raw_x > 0.0 { raw_x * 0.25 } else { raw_x };
            let py = if raw_y > 0.0 { raw_y * 0.25 } else { raw_y };

            pan_x.set(px);
            pan_y.set(py);
            return;
        }

        let x = ((raw_coords.x - pan_x()) / zoom()).max(0.0);
        let y = ((raw_coords.y - pan_y()) / zoom()).max(0.0);

        if is_box_selecting() {
            let (sx, sy) = box_select_start();
            let bx = sx.min(x);
            let by = sy.min(y);
            let bw = (x - sx).abs();
            let bh = (y - sy).abs();
            box_select_rect.set(Some((bx, by, bw, bh)));

            if let Some(act_id) = active_tab_id() {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                        for card in note.cards.iter_mut() {
                            let overlap = card.x < bx + bw
                                && card.x + card.width > bx
                                && card.y < by + bh
                                && card.y + card.height > by;
                            card.selected = overlap;
                        }
                    }
                });
            }
            return;
        }

        if is_connecting() {
            temp_connector_end.set((x, y));
            return;
        }

        if let Some(card_id) = resizing_card_id() {
            let (start_mx, start_my) = resize_start_mouse();
            let (start_x, _start_y, start_w, start_h) = resize_start_card();
            let dx = (raw_coords.x - start_mx) / zoom();
            let dy = (raw_coords.y - start_my) / zoom();
            
            let handle = resize_handle().unwrap_or_default();
            
            let mut new_x = start_x;
            let mut new_w = start_w;
            let mut new_h = start_h;
            
            match handle.as_str() {
                "se" => {
                    new_w = (start_w + dx).max(220.0);
                    new_h = (start_h + dy).max(120.0);
                }
                "e" => {
                    new_w = (start_w + dx).max(220.0);
                }
                "s" => {
                    new_h = (start_h + dy).max(120.0);
                }
                "sw" => {
                    new_w = (start_w - dx).max(220.0);
                    new_x = (start_x + dx).min(start_x + start_w - 220.0);
                    new_h = (start_h + dy).max(120.0);
                }
                _ => {}
            }
            
            if let Some(active_id) = active_tab_id() {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == active_id) {
                        if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                            card.x = new_x;
                            card.width = new_w;
                            card.height = new_h;
                        }
                    }
                });
            }
            return;
        }

        if let Some(card_id) = dragging_card_id() {
            let (off_x, off_y) = drag_offset();
            let mut new_x = (x - off_x).max(0.0);
            let mut new_y = (y - off_y).max(0.0);
            let mut sn_x = None;
            let mut sn_y = None;
            
            let vc = visual_config();

            // 1. Grid Snap
            let snap_val = match vc.smart_snap.as_str() {
                "10px" => Some(10.0),
                "20px" => Some(20.0),
                "50px" => Some(50.0),
                _ => None,
            };
            
            if let Some(sv) = snap_val {
                new_x = (new_x / sv).round() * sv;
                new_y = (new_y / sv).round() * sv;
            }

            // 2. Smart Guides (Snap to cards)
            if vc.smart_guides {
                if let Some(active_id) = active_tab_id() {
                    let mut other_cards = vec![];
                    notes.with(|n_list| {
                        if let Some(note) = n_list.iter().find(|n| n.id == active_id) {
                            for c in &note.cards {
                                if c.id != card_id {
                                    other_cards.push(c.clone());
                                }
                            }
                        }
                    });
                    
                    for oc in other_cards {
                        if (new_x - oc.x).abs() < 10.0 {
                            new_x = oc.x;
                            sn_x = Some(oc.x);
                        }
                        if (new_y - oc.y).abs() < 10.0 {
                            new_y = oc.y;
                            sn_y = Some(oc.y);
                        }
                    }
                }
            }
            snap_guides.set((sn_x, sn_y));

            if let Some(active_id) = active_tab_id() {
                notes.with_mut(|n_list| {
                    if let Some(note) = n_list.iter_mut().find(|n| n.id == active_id) {
                        if let Some(card) = note.cards.iter_mut().find(|c| c.id == card_id) {
                            card.x = new_x;
                            card.y = new_y;
                        }
                    }
                });
            }
            return;
        }

        if is_drawing() {
            if let Some(mut stroke) = current_stroke() {
                stroke.points.push(Point { x, y });
                current_stroke.set(Some(stroke));
            }
        }
    };

    let mut handle_mouse_up = move |evt: MouseEvent| {
        if is_box_selecting() {
            is_box_selecting.set(false);
            box_select_rect.set(None);
        }

        if is_panning() {
            is_panning.set(false);
            // BOUNCE ELASTICO BACK TO BOUNDS 0.0 IF OVERBOUND
            if pan_x() > 0.0 {
                pan_x.set(0.0);
            }
            if pan_y() > 0.0 {
                pan_y.set(0.0);
            }
        }

        resizing_card_id.set(None);

        if is_connecting() {
            let raw_coords = evt.client_coordinates();
            let x = ((raw_coords.x - pan_x()) / zoom()).max(0.0);
            let y = ((raw_coords.y - pan_y()) / zoom()).max(0.0);

            if let Some(from_id) = connecting_from_id() {
                let active_id = active_tab_id();
                let active_cards = notes()
                    .iter()
                    .find(|n| Some(n.id) == active_id)
                    .map(|n| n.cards.clone())
                    .unwrap_or_default();
                if let Some(target_card) = active_cards.iter().find(|c| {
                    c.id != from_id
                        && x >= c.x
                        && x <= c.x + c.width
                        && y >= c.y
                        && y <= c.y + c.height
                }) {
                    if let Some(aid) = active_id {
                        notes.with_mut(|n_list| {
                            if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                                if !note.connectors.iter().any(|conn| {
                                    (conn.from_id == from_id && conn.to_id == target_card.id)
                                        || (conn.from_id == target_card.id && conn.to_id == from_id)
                                }) {
                                    note.connectors.push(Connector {
                                        id: note.connectors.len() + 500,
                                        from_id,
                                        to_id: target_card.id,
                                        color: if tool_mode() == "highlighter" {
                                            hl_color()
                                        } else {
                                            pen_color()
                                        },
                                        label: None,
                                        line_style: None,
                                    });
                                    let is_audio = app_settings().sound_enabled;
                                    let vol = app_settings().ui_volume.parse::<f32>().unwrap_or(50.0) / 100.0;
                                    if is_audio && vol > 0.0 {
                                        let _ = document::eval(&format!("window.playSynthSound('connect', {})", vol));
                                    }
                                }
                            }
                        });
                    }
                }
            }
            is_connecting.set(false);
            connecting_from_id.set(None);
        }

        if is_drawing() {
            if let Some(stroke) = current_stroke() {
                if stroke.points.len() > 1 {
                    if let Some(active_id) = active_tab_id() {
                        notes.with_mut(|n_list| {
                            if let Some(note) = n_list.iter_mut().find(|n| n.id == active_id) {
                                note.strokes.push(stroke);
                            }
                        });
                    }
                }
            }
            current_stroke.set(None);
            is_drawing.set(false);
        }

        dragging_card_id.set(None);
        snap_guides.set((None, None));
    };

    let render_stroke_path = |stroke: &Stroke| {
        if stroke.points.is_empty() {
            return String::new();
        }
        let mut d = format!("M {} {}", stroke.points[0].x, stroke.points[0].y);
        for p in stroke.points.iter().skip(1) {
            d.push_str(&format!(" L {} {}", p.x, p.y));
        }
        d
    };

    let get_connector_path = |c1: &NoteCard, c2: &NoteCard| {
        let start_x = c1.x + c1.width / 2.0;
        let start_y = c1.y + c1.height / 2.0;
        let end_x = c2.x + c2.width / 2.0;
        let end_y = c2.y + c2.height / 2.0;

        let ctrl_x1 = start_x + (end_x - start_x) / 2.0;
        let ctrl_y1 = start_y;
        let ctrl_x2 = start_x + (end_x - start_x) / 2.0;
        let ctrl_y2 = end_y;

        format!(
            "M {} {} C {} {}, {} {}, {} {}",
            start_x, start_y, ctrl_x1, ctrl_y1, ctrl_x2, ctrl_y2, end_x, end_y
        )
    };

    // PEGA DADOS DA NOTA ATIVA PARA O CANVAS
    let current_note = notes()
        .iter()
        .find(|n| Some(n.id) == active_tab_id())
        .cloned();
    let current_cards = current_note
        .as_ref()
        .map(|n| n.cards.clone())
        .unwrap_or_default();
    let current_connectors = current_note
        .as_ref()
        .map(|n| n.connectors.clone())
        .unwrap_or_default();
    let current_strokes = current_note
        .as_ref()
        .map(|n| n.strokes.clone())
        .unwrap_or_default();

    // FILTRAGEM PARA OMNIBAR DE BUSCA
    let q = search_query().to_lowercase();
    let search_results = notes()
        .into_iter()
        .filter(|n| {
            if q.is_empty() {
                return false;
            }
            n.title.to_lowercase().contains(&q)
                || n.tags.iter().any(|t| t.to_lowercase().contains(&q))
                || n.cards.iter().any(|c| {
                    c.title.to_lowercase().contains(&q) || c.content.to_lowercase().contains(&q)
                })
        })
        .collect::<Vec<_>>();

    let paper_grid_element = {
        let px = 0.0;
        let py = 0.0;
        let zm: f64 = 1.0;
        match paper_mode() {
            PaperMode::DotGrid => {
                let size = 32.0 * zm;
                let r = (1.5 * zm).max(1.0);
                let size_str = format!("{size}");
                let r_str = format!("{r}");
                let half_size_str = format!("{}", size / 2.0);
                let px_str = format!("{px}");
                let py_str = format!("{py}");
                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-dot",
                                width: "{size_str}",
                                height: "{size_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                circle { cx: "{half_size_str}", cy: "{half_size_str}", r: "{r_str}", fill: "rgba(255, 255, 255, 0.08)" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-dot)" }
                    }
                    svg {
                        class: "canvas-grid-svg canvas-spotlight-overlay",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 2;",
                        defs {
                            pattern {
                                id: "paper-grid-dot-spotlight",
                                width: "{size_str}",
                                height: "{size_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                circle { cx: "{half_size_str}", cy: "{half_size_str}", r: "{r_str}", fill: "rgba(113, 104, 246, 0.9)" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-dot-spotlight)" }
                    }
                }
            }
            PaperMode::Grid => {
                let size = 32.0 * zm;
                let size_str = format!("{size}");
                let path_d = format!("M {} 0 L 0 0 0 {}", size, size);
                let px_str = format!("{px}");
                let py_str = format!("{py}");
                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-line",
                                width: "{size_str}",
                                height: "{size_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                path { d: "{path_d}", fill: "none", stroke: "rgba(255, 255, 255, 0.22)", stroke_width: "1" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-line)" }
                    }
                }
            }
            PaperMode::Lined => {
                let size = 32.0 * zm;
                let margin_x = 56.0 * zm + px;
                let size_str = format!("{size}");
                let py_str = format!("{py}");
                let margin_path = format!("M {} 0 L {} 4000", margin_x, margin_x);
                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-lined",
                                width: "4000",
                                height: "{size_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "0",
                                y: "{py_str}",
                                path { d: "M 0 0 L 4000 0", stroke: "rgba(255, 255, 255, 0.32)", stroke_width: "1.2" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-lined)" }
                        // MARGEM LATERAL ESQUERDA VERMELHA DA NOTA (ESTILO CADERNO)
                        path {
                            d: "{margin_path}",
                            stroke: "rgba(239, 68, 68, 0.75)",
                            stroke_width: "2"
                        }
                    }
                }
            }
            PaperMode::Isometric => {
                let h = 32.0 * zm;
                let w = h * 1.732050807568877;
                let half_h = h / 2.0;
                let w_str = format!("{w}");
                let h_str = format!("{h}");
                let path_d = format!(
                    "M 0 0 L {} {} M 0 {} L {} 0 M 0 {} L {} {}",
                    w, h, h, w, half_h, w, half_h
                );
                let px_str = format!("{px}");
                let py_str = format!("{py}");
                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-iso",
                                width: "{w_str}",
                                height: "{h_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                path { d: "{path_d}", fill: "none", stroke: "rgba(255, 255, 255, 0.22)", stroke_width: "1" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-iso)" }
                    }
                }
            }
            PaperMode::Hexagonal => {
                let s = 24.0 * zm;
                let w = 3.0 * s;
                let h = 1.732050807568877 * s;

                let w_str = format!("{w}");
                let h_str = format!("{h}");
                let px_str = format!("{px}");
                let py_str = format!("{py}");

                let half_s = 0.5 * s;
                let one_half_s = 1.5 * s;
                let two_s = 2.0 * s;
                let two_half_s = 2.5 * s;
                let three_s = 3.0 * s;
                let half_h = 0.5 * h;

                let path_d = format!(
                    "M {} 0 L {} 0 L {} {} L {} {} L {} {} L 0 {} Z M {} {} L {} 0 L {} 0 M {} {} L {} {} L {} {}",
                    half_s,
                    one_half_s,
                    two_s,
                    half_h,
                    one_half_s,
                    h,
                    half_s,
                    h,
                    half_h,
                    two_s,
                    half_h,
                    two_half_s,
                    three_s,
                    two_s,
                    half_h,
                    two_half_s,
                    h,
                    three_s,
                    h
                );

                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-hex",
                                width: "{w_str}",
                                height: "{h_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                path { d: "{path_d}", fill: "none", stroke: "rgba(255, 255, 255, 0.28)", stroke_width: "1.2" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-hex)" }
                    }
                }
            }
            PaperMode::IsometricDots => {
                let size = 32.0 * zm;
                let r = (1.5 * zm).max(1.0);
                let width_val = size * 1.732;
                let half_w = size * 0.866;
                let half_h = size / 2.0;

                let width_str = format!("{width_val}");
                let size_str = format!("{size}");
                let r_str = format!("{r}");
                let half_w_str = format!("{half_w}");
                let half_h_str = format!("{half_h}");
                let px_str = format!("{px}");
                let py_str = format!("{py}");
                rsx! {
                    svg {
                        class: "canvas-grid-svg",
                        style: "position: absolute; top: 0; left: 0; width: 10000px; height: 10000px; pointer-events: none; z-index: 1;",
                        defs {
                            pattern {
                                id: "paper-grid-isodots",
                                width: "{width_str}",
                                height: "{size_str}",
                                pattern_units: "userSpaceOnUse",
                                x: "{px_str}",
                                y: "{py_str}",
                                circle { cx: "0", cy: "0", r: "{r_str}", fill: "rgba(0, 255, 170, 0.45)" }
                                circle { cx: "{half_w_str}", cy: "{half_h_str}", r: "{r_str}", fill: "rgba(0, 255, 170, 0.45)" }
                                circle { cx: "{width_str}", cy: "0", r: "{r_str}", fill: "rgba(0, 255, 170, 0.45)" }
                            }
                        }
                        rect { width: "10000", height: "10000", fill: "url(#paper-grid-isodots)" }
                    }
                }
            }
            PaperMode::Blank => rsx! {},
        }
    };

    let temp_connector_path_element = if is_connecting() {
        if let Some(from_id) = connecting_from_id() {
            if let Some(c1) = current_cards.iter().find(|c| c.id == from_id) {
                let c1_center_x = c1.x + c1.width / 2.0;
                let c1_center_y = c1.y + c1.height / 2.0;
                let temp_end = temp_connector_end();
                let temp_end_x = temp_end.0;
                let temp_end_y = temp_end.1;
                let path_d = format!(
                    "M {} {} L {} {}",
                    c1_center_x, c1_center_y, temp_end_x, temp_end_y
                );
                let conn_color = if tool_mode() == "highlighter" {
                    hl_color()
                } else {
                    pen_color()
                };
                rsx! {
                    path {
                        d: "{path_d}",
                        fill: "none",
                        stroke: "{conn_color}",
                        stroke_width: "3",
                        stroke_dasharray: "4 4"
                    }
                }
            } else {
                rsx! {}
            }
        } else {
            rsx! {}
        }
    } else {
        rsx! {}
    };
    let all_notes = notes();

    let sidebar_class = if sidebar_open() {
        "moscaro sidebar"
    } else {
        "moscaro sidebar collapsed"
    };
    let top_tab_class = if sidebar_open() {
        "moscaro top-tab-capsule sidebar-open"
    } else {
        "moscaro top-tab-capsule sidebar-closed"
    };

    let get_card_class = |c_sel: bool, c_id: usize| -> &'static str {
        if c_sel || connecting_from_id() == Some(c_id) {
            "moscaro canvas-card selected stitch-aurora-glow stitch-generating"
        } else {
            "moscaro canvas-card"
        }
    };

    let _get_note_item_class = |id: usize| -> &'static str {
        if sidebar_drag_target_id() == Some(id) {
            "note-item active drag-over"
        } else if active_tab_id() == Some(id) {
            "note-item active"
        } else {
            "note-item"
        }
    };

    let _get_folder_class = |f_id: usize| -> &'static str {
        if sidebar_drag_target_id() == Some(9000 + f_id) {
            "folder-group drag-over"
        } else {
            "folder-group"
        }
    };

    let get_tab_pill_class = |id: usize| -> &'static str {
        if active_tab_id() == Some(id) {
            "tab-pill active"
        } else {
            "tab-pill"
        }
    };

    let is_active_color = |target: &str| -> &'static str {
        let current = if tool_mode() == "highlighter" {
            hl_color()
        } else {
            pen_color()
        };
        if current == target {
            "color-dot active"
        } else {
            "color-dot"
        }
    };

    let get_paper_btn_class = |mode: PaperMode| -> &'static str {
        if paper_mode() == mode {
            "paper-symbol-btn active"
        } else {
            "paper-symbol-btn"
        }
    };

    let get_tb_btn_class = |mode: &str| -> &'static str {
        if tool_mode() == mode {
            "tb-btn active"
        } else {
            "tb-btn"
        }
    };

    let vc = visual_config();
    let mut root_classes = vec!["aurora-container".to_string(), "moscaro".to_string()];
    if pending_card_type().is_some() {
        root_classes.push("card-insertion-active".to_string());
    }
    root_classes.push(format!("preset-{}", vc.performance_preset));
    let aurora_container_class = root_classes.join(" ");

    let custom_styles = format!(
        "--bg-obsidian: {}; --glass-bg: color-mix(in srgb, {} 15%, transparent); --accent-cyan: {}; --accent-emerald: {}; --text-primary: {}; font-family: {}; font-size: {}; line-height: {}; letter-spacing: {};",
        vc.color_bg,
        vc.color_details,
        vc.color_accent,
        vc.color_neon,
        vc.color_text,
        vc.typography_font,
        vc.font_size,
        vc.line_height,
        vc.letter_spacing
    );


    let is_settings_active = notes().iter().find(|n| Some(n.id) == active_tab_id()).map_or(false, |n| n.note_type.as_deref() == Some("settings"));
    let handle_canvas_paste = move |_e: ClipboardEvent| {
        perform_canvas_paste();
    };

    rsx! {
        div {
            class: "{aurora_container_class}",
            style: "{custom_styles}",
            onkeydown: move |evt: KeyboardEvent| handle_keydown(evt),
            onwheel: move |evt: WheelEvent| handle_wheel(evt),
            onmousedown: move |evt: MouseEvent| handle_mouse_down(evt),
            onmousemove: move |evt: MouseEvent| handle_mouse_move(evt),
            onmouseup: move |evt: MouseEvent| handle_mouse_up(evt),
            onpaste: handle_canvas_paste,

            div { class: "aurora-glow-1" }
            div { class: "aurora-glow-2" }
            div { class: "aurora-glow-3" }
            div { class: "aurora-glow-sidebar" }

            // BACKDROPS DE FECHAMENTO AO CLICAR FORA
            if is_note_type_menu_open() || is_add_card_menu_open() || is_paper_menu_open() {
                div {
                    class: "popover-backdrop",
                    style: "position: fixed; inset: 0; z-index: 999;",
                    onclick: move |_: MouseEvent| {
                        is_note_type_menu_open.set(false);
                        is_add_card_menu_open.set(false);
                        is_paper_menu_open.set(false);
                    }
                }
            }

            if sidebar_open() {
                div {
                    class: "sidebar-backdrop",
                    style: "position: fixed; inset: 0; z-index: 14;",
                    onclick: move |_: MouseEvent| {
                        sidebar_open.set(false);
                        is_note_type_menu_open.set(false);
                    }
                }
            }

            {
                if is_settings_active {
                    rsx! {
                        SettingsView {
                            ai_config: ai_config,
                            user_profile: user_profile,
                        }
                    }
                } else {
                    rsx! {
                        div {
                            style: "position: absolute; inset: 0; transform: translate({pan_x()}px, {pan_y()}px) scale({zoom()}); transform-origin: 0 0; width: 100%; height: 100%; transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);",

                            {paper_grid_element}

                            svg {
                                style: "position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 4; overflow: visible;",

                                {temp_connector_path_element}

                    for conn in current_connectors.iter() {
                        if let (Some(c1), Some(c2)) = (current_cards.iter().find(|c| c.id == conn.from_id), current_cards.iter().find(|c| c.id == conn.to_id)) {
                            {
                                let is_selected = selected_connector_id() == Some(conn.id);
                                let stroke_color = if is_selected { "#00ffff" } else { &conn.color };
                                let stroke_w = if is_selected { "4.5" } else { "2.5" };
                                let glow_color = if is_selected { "#00ffff" } else { &conn.color };
                                let conn_id = conn.id;

                                let dash_arr = match conn.line_style.as_deref() {
                                    Some("dashed") => "6,6",
                                    Some("dotted") => "2,4",
                                    _ => "none",
                                };

                                let mx = c1.x + c1.width / 2.0 + (c2.x + c2.width / 2.0 - (c1.x + c1.width / 2.0)) / 2.0;
                                let my = c1.y + c1.height / 2.0 + (c2.y + c2.height / 2.0 - (c1.y + c1.height / 2.0)) / 2.0;

                                rsx! {
                                    path {
                                        key: "{conn.id}",
                                        d: "{get_connector_path(c1, c2)}",
                                        fill: "none",
                                        stroke: "{stroke_color}",
                                        stroke_width: "{stroke_w}",
                                        stroke_dasharray: "{dash_arr}",
                                        style: "pointer-events: stroke; cursor: pointer; filter: drop-shadow(0 0 12px {glow_color});",
                                        onclick: move |evt: MouseEvent| {
                                            evt.stop_propagation();
                                            let raw_c = evt.client_coordinates();
                                            let click_x = ((raw_c.x - pan_x()) / zoom()).max(0.0);
                                            let click_y = ((raw_c.y - pan_y()) / zoom()).max(0.0);
                                            selected_connector_id.set(Some(conn_id));
                                            selected_connector_pos.set(Some((click_x, click_y)));
                                        }
                                    }
                                    if let Some(lbl) = &conn.label {
                                        if !lbl.is_empty() {
                                            text {
                                                x: "{mx}",
                                                y: "{my}",
                                                fill: "#ffffff",
                                                text_anchor: "middle",
                                                dominant_baseline: "middle",
                                                font_weight: "bold",
                                                style: "pointer-events: none; filter: drop-shadow(0 0 6px {glow_color});",
                                                "{lbl}"
                                            }
                                        }
                                    }
                                    if is_selected {
                                        {
                                            let (menu_x, menu_y) = selected_connector_pos().unwrap_or((mx, my));
                                            rsx! {
                                                foreignObject {
                                                    x: "{menu_x - 60.0}",
                                                    y: "{menu_y - 30.0}",
                                                    width: "120",
                                                    height: "60",
                                                    style: "overflow: visible;",
                                                    div {
                                                        style: "display: flex; flex-direction: column; gap: 4px; background: rgba(0,0,0,0.8); padding: 4px; border-radius: 4px; border: 1px solid #00ffff;",
                                                        input {
                                                            value: "{conn.label.as_deref().unwrap_or(\"\")}",
                                                            placeholder: "Label...",
                                                            style: "background: transparent; color: white; border: none; outline: none; width: 100%; font-size: 12px; text-align: center;",
                                                            oninput: move |e: FormEvent| {
                                                                if let Some(aid) = active_tab_id() {
                                                                    notes.with_mut(|n_list| {
                                                                        if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                                                                            if let Some(c) = note.connectors.iter_mut().find(|c| c.id == conn_id) {
                                                                                c.label = Some(e.value());
                                                                            }
                                                                        }
                                                                    });
                                                                }
                                                            }
                                                        }
                                                        select {
                                                            style: "background: #222; color: white; border: 1px solid #444; border-radius: 2px; font-size: 11px; outline: none;",
                                                            onchange: move |e: FormEvent| {
                                                                if let Some(aid) = active_tab_id() {
                                                                    notes.with_mut(|n_list| {
                                                                        if let Some(note) = n_list.iter_mut().find(|n| n.id == aid) {
                                                                            if let Some(c) = note.connectors.iter_mut().find(|c| c.id == conn_id) {
                                                                                c.line_style = Some(e.value());
                                                                            }
                                                                        }
                                                                    });
                                                                }
                                                            },
                                                            option { value: "solid", selected: conn.line_style.as_deref() == Some("solid") || conn.line_style.is_none(), "Sólida" }
                                                            option { value: "dashed", selected: conn.line_style.as_deref() == Some("dashed"), "Tracejada" }
                                                            option { value: "dotted", selected: conn.line_style.as_deref() == Some("dotted"), "Pontilhada" }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    for stroke in current_strokes.iter() {
                        path {
                            d: "{render_stroke_path(stroke)}",
                            fill: "none",
                            stroke: "{stroke.color}",
                            stroke_width: "{stroke.thickness}",
                            stroke_linecap: "round",
                            stroke_linejoin: "round",
                            opacity: if stroke.is_highlighter { "0.45" } else { "1.0" },
                            style: if !stroke.is_highlighter { "filter: drop-shadow(0 0 4px {stroke.color});" } else { "" }
                        }
                    }

                    if let Some(ref stroke) = current_stroke() {
                        path {
                            d: "{render_stroke_path(stroke)}",
                            fill: "none",
                            stroke: "{stroke.color}",
                            stroke_width: "{stroke.thickness}",
                            stroke_linecap: "round",
                            stroke_linejoin: "round",
                            opacity: if stroke.is_highlighter { "0.45" } else { "1.0" }
                        }
                    }
                                if let Some((bx, by, bw, bh)) = box_select_rect() {
                                    rect {
                                        x: "{bx}",
                                        y: "{by}",
                                        width: "{bw}",
                                        height: "{bh}",
                                        fill: "rgba(0, 225, 255, 0.12)",
                                        stroke: "#00e1ff",
                                        stroke_width: "1.5",
                                        stroke_dasharray: "4 4",
                                        style: "pointer-events: none;"
                                    }
                                }

                                if let Some(sx) = snap_guides().0 {
                                    line {
                                        x1: "{sx}",
                                        y1: "-10000",
                                        x2: "{sx}",
                                        y2: "10000",
                                        stroke: "var(--accent-cyan)",
                                        stroke_width: "2",
                                        stroke_dasharray: "6,6",
                                        opacity: "0.9",
                                        filter: "drop-shadow(0px 0px 5px var(--accent-cyan))"
                                    }
                                }
                                if let Some(sy) = snap_guides().1 {
                                    line {
                                        x1: "-10000",
                                        y1: "{sy}",
                                        x2: "10000",
                                        y2: "{sy}",
                                        stroke: "var(--accent-cyan)",
                                        stroke_width: "2",
                                        stroke_dasharray: "6,6",
                                        opacity: "0.9",
                                        filter: "drop-shadow(0px 0px 5px var(--accent-cyan))"
                                    }
                                }
                            }

                            for card in current_cards.iter() {
                                {
                                    let card_id = card.id;
                                    let card_clone = card.clone();
                                    rsx! {
                                        CardContainer {
                                            card: card_clone,
                                            card_class: get_card_class(card.selected, card.id).to_string(),
                                            is_editing_title: editing_title_card_id() == Some(card_id),
                                            on_start_edit_title: move |_| editing_title_card_id.set(Some(card_id)),
                                            on_finish_edit_title: move |_| editing_title_card_id.set(None),
                                            on_update_title: move |t| update_card_title(card_id, t),
                                            on_update_content: move |c| update_card_content(card_id, c),
                                            on_card_update: move |updated_card: NoteCard| {
                                                if let Some(act_id) = active_tab_id() {
                                                    notes.with_mut(|n_list| {
                                                        if let Some(note) = n_list.iter_mut().find(|n| n.id == act_id) {
                                                            if let Some(c) = note.cards.iter_mut().find(|c| c.id == updated_card.id) {
                                                                *c = updated_card;
                                                            }
                                                        }
                                                    });
                                                }
                                            },
                                            on_start_resize: move |args| handle_start_resize(args),
                                            on_ai_click: move |c| open_ai_modal_for_context((c, Some(card_id))),
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 1. SIDEBAR HIERÁRQUICA COM CAMPO DE BUSCA NO TOPO, DROPDOWN NOVA NOTA E DRAG & DROP
            div {
                class: "{sidebar_class}",
                onclick: move |e: MouseEvent| {
                    e.stop_propagation();
                    is_note_type_menu_open.set(false);
                },
                div { class: "sidebar-header", style: "display: flex; align-items: center; gap: 8px;",
                    IconLogo {}
                    h1 { class: "sidebar-title", style: "font-weight: bold; font-size: 16px; background: linear-gradient(90deg, #00e1ff, #a855f7); -webkit-background-clip: text; -webkit-text-fill-color: transparent;", "conNotes" }
                }

                // CAMPO DE BUSCA NO TOPO DA SIDEBAR (ESTILO MOSCARO)
                div { class: "sidebar-search-box", style: "border-radius: 999px; backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); padding: 6px 12px; display: flex; align-items: center; gap: 8px; margin: 12px;",
                    IconSearch {}
                    input {
                        class: "sidebar-search-input",
                        style: "background: transparent; border: none; outline: none; color: white; width: 100%;",
                        placeholder: "Buscar notas...",
                        value: "{search_query}",
                        oninput: move |e: FormEvent| search_query.set(e.value())
                    }
                    span {
                        class: "sidebar-search-btn",
                        onclick: move |_: MouseEvent| omnibar_open.set(true),
                        "Ctrl+K"
                    }
                }

                // BOTÃO ÚNICO DE CRIAÇÃO ("NOVO +") COM MENU DROPDOWN UNIFICADO
                div { class: "sidebar-action-bar",
                    button {
                        class: "single-new-btn-unified",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            subnote_parent_target.set(None);
                            folder_target_for_new_note.set(None);
                            is_note_type_menu_open.toggle();
                        },
                        IconPlus {}
                        span { "Novo" }
                    }

                    if is_note_type_menu_open() {
                        div {
                            class: "moscaro note-type-popover",
                            style: "position: absolute; z-index: 99999;",
                            onclick: move |e: MouseEvent| e.stop_propagation(),
                            div {
                                class: "note-type-option",
                                onclick: move |e: MouseEvent| {
                                    e.stop_propagation();
                                    add_folder_directly(None);
                                },
                                span { style: "display: inline-flex;", IconFolderPlus {} }
                                span { "Nova Pasta" }
                            }
                            div {
                                class: "note-type-option",
                                onclick: move |e: MouseEvent| {
                                    e.stop_propagation();
                                    create_new_note_with_type("canvas".to_string(), subnote_parent_target(), folder_target_for_new_note());
                                },
                                span { style: "display: inline-flex;", IconNote { card_type: "canvas".to_string() } }
                                span { "Canvas Infinito (.cncanvas)" }
                            }
                            div {
                                class: "note-type-option",
                                onclick: move |e: MouseEvent| {
                                    e.stop_propagation();
                                    create_new_note_with_type("text".to_string(), subnote_parent_target(), folder_target_for_new_note());
                                },
                                span { style: "display: inline-flex;", IconNote { card_type: "text".to_string() } }
                                span { "Documento de Texto" }
                            }
                            div {
                                class: "note-type-option",
                                onclick: move |e: MouseEvent| {
                                    e.stop_propagation();
                                    create_new_note_with_type("pdf".to_string(), subnote_parent_target(), folder_target_for_new_note());
                                },
                                span { style: "display: inline-flex;", IconNote { card_type: "pdf".to_string() } }
                                span { "Documento PDF" }
                            }
                            div {
                                class: "note-type-option",
                                onclick: move |e: MouseEvent| {
                                    e.stop_propagation();
                                    create_new_note_with_type("code".to_string(), subnote_parent_target(), folder_target_for_new_note());
                                },
                                span { style: "display: inline-flex;", IconNote { card_type: "code".to_string() } }
                                span { "Documento de Código" }
                            }
                        }
                    }
                }

                // ÁRVORE DE NOTAS E PASTAS COM DRAG & DROP RECURSIVO INFINITO (ONENOTE-STYLE VECTORS)
                div {
                    class: "sidebar-tree",
                    onmouseleave: move |_: MouseEvent| {
                        dragged_sidebar_note_id.set(None);
                        sidebar_drag_target_id.set(None);
                    },
                    onmouseup: move |e: MouseEvent| {
                        if dragged_sidebar_note_id().is_some() {
                            e.stop_propagation();
                            handle_sidebar_drop(None, None);
                        }
                    },

                    // Renderiza pastas no nível raiz (parent_id == None)
                    for folder in folders().iter().filter(|f| f.parent_id.is_none()).cloned() {
                        {sidebar::render_folder_node(
                            folder,
                            folders,
                            notes,
                            active_tab_id,
                            open_tab_ids,
                            dragged_sidebar_note_id,
                            sidebar_drag_target_id,
                            is_note_type_menu_open,
                            subnote_parent_target,
                            folder_target_for_new_note,
                            editing_folder_id,
                            editing_note_id,
                            0,
                        )}
                    }

                    // Renderiza notas avulsas no nível raiz (folder_id == None && parent_id == None)
                    div { class: "nav-section-title", "Notas Avulsas" }
                    for note in notes().iter().filter(|n| n.folder_id.is_none() && n.parent_id.is_none() && n.note_type.as_deref() != Some("settings") && n.id != 9999).cloned() {
                        {sidebar::render_note_node(
                            note,
                            folders,
                            notes,
                            active_tab_id,
                            open_tab_ids,
                            dragged_sidebar_note_id,
                            sidebar_drag_target_id,
                            is_note_type_menu_open,
                            subnote_parent_target,
                            folder_target_for_new_note,
                            editing_folder_id,
                            editing_note_id,
                            0,
                        )}
                    }
                }
            }

            // 2. BARRA DE ABAS REATIVA (TOP TAB BAR EM FORMATO PÍLULA 999px SEM SOBREPOSIÇÃO)
            div {
                class: "{top_tab_class}",
                style: "display: flex; align-items: center; padding: 6px; margin: 12px; gap: 8px;",
                div {
                    class: "sidebar-toggle-btn",
                    style: "cursor: pointer; padding: 4px; border-radius: 999px; transition: 0.2s;",
                    onclick: move |_: MouseEvent| {
                        sidebar_open.toggle();
                        is_note_type_menu_open.set(false);
                    },
                    svg { view_box: "0 0 24 24", style: "width: 18px; height: 18px;",
                        path { d: "M4 6h16M4 12h16M4 18h16", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round" }
                    }
                }

                div { class: "tab-bar-scroll",
                    for tab_id in open_tab_ids() {
                        if let Some(note) = all_notes.iter().find(|n| n.id == tab_id).cloned() {
                            div {
                                key: "{note.id}",
                                class: "{get_tab_pill_class(note.id)}",
                                onclick: move |_: MouseEvent| active_tab_id.set(Some(note.id)),
                                span { class: "tab-icon",
                                    IconNote { card_type: get_note_card_type_from_icon(&note.icon) }
                                }
                                span { class: "tab-label", "{note.title}" }
                                span {
                                    class: "tab-close-btn",
                                    onclick: move |e: MouseEvent| {
                                        e.stop_propagation();
                                        close_tab(note.id);
                                    },
                                    "×"
                                }
                            }
                        }
                    }
                }

                div {
                    class: "new-tab-btn",
                    title: "Configurações",
                    style: "margin-left: 4px; background: rgba(255,255,255,0.06); color: #a5b4fc;",
                    onclick: move |_: MouseEvent| {
                        let settings_id = 999999usize;
                        notes.with_mut(|n_list| {
                            if !n_list.iter().any(|n| n.id == settings_id) {
                                n_list.push(NoteItem {
                                    id: settings_id,
                                    title: "Configurações".to_string(),
                                    parent_id: None,
                                    folder_id: None,
                                    icon: "settings".to_string(),
                                    cards: vec![],
                                    connectors: vec![],
                                    strokes: vec![],
                                    tags: vec![],
                                    paper_mode: None,
                                    note_type: Some("settings".to_string()),
                                });
                            }
                        });
                        open_tab_ids.with_mut(|tabs| {
                            if !tabs.contains(&settings_id) {
                                tabs.push(settings_id);
                            }
                        });
                        active_tab_id.set(Some(settings_id));
                    },
                    IconSettings {}
                }

                div {
                    class: "new-tab-btn",
                    title: "Nova Nota",
                    onclick: move |_: MouseEvent| create_new_note_with_type("text".to_string(), None, None),
                    svg {
                        view_box: "0 0 24 24",
                        style: "width: 15px; height: 15px;",
                        path { d: "M12 5v14M5 12h14", stroke: "currentColor", stroke_width: "2.5", stroke_linecap: "round" }
                    }
                }
            }

            // 3. TOOLBAR INFERIOR DE FERRAMENTAS E ZOOM (PÍLULAS 999px COM BLUR)
            div { class: "toolbar-wrapper", style: "display: flex; gap: 16px; align-items: center; justify-content: center;",
                // SUB-TOOLBAR DE CORES (VISÍVEL APENAS PARA CANETA OU MARCA-TEXTO)
                if tool_mode() == "pen" || tool_mode() == "highlighter" {
                    div { class: "moscaro sub-toolbar-pill", style: "border-radius: 999px; backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); background: rgba(15, 20, 25, 0.65); border: 1px solid rgba(255,255,255,0.1); padding: 4px 12px; display: flex; align-items: center; gap: 8px;",
                        div {
                            class: "sub-tb-icon",
                            onclick: move |_: MouseEvent| {
                                if tool_mode() == "highlighter" {
                                    hl_thickness.set(if hl_thickness() == 8.0 { 16.0 } else { 8.0 });
                                } else {
                                    pen_thickness.set(if pen_thickness() == 3.0 { 6.0 } else { 3.0 });
                                }
                            },
                            svg { view_box: "0 0 24 24",
                                circle { cx: "12", cy: "12", r: "8", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_dasharray: "3 3" }
                            }
                        }
                        div {
                            class: "{is_active_color(\"#ef4444\")}",
                            style: "background: #ef4444;",
                            onclick: move |_: MouseEvent| {
                                if tool_mode() == "highlighter" { hl_color.set("#ef4444".to_string()); } else { pen_color.set("#ef4444".to_string()); }
                            }
                        }
                        div {
                            class: "{is_active_color(\"#22c55e\")}",
                            style: "background: #22c55e;",
                            onclick: move |_: MouseEvent| {
                                if tool_mode() == "highlighter" { hl_color.set("#22c55e".to_string()); } else { pen_color.set("#22c55e".to_string()); }
                            }
                        }
                        div {
                            class: "{is_active_color(\"#00e1ff\")}",
                            style: "background: #00e1ff;",
                            onclick: move |_: MouseEvent| {
                                if tool_mode() == "highlighter" { hl_color.set("#00e1ff".to_string()); } else { pen_color.set("#00e1ff".to_string()); }
                            }
                        }
                        div {
                            class: "{is_active_color(\"#ffffff\")}",
                            style: "background: #ffffff;",
                            onclick: move |_: MouseEvent| {
                                if tool_mode() == "highlighter" { hl_color.set("#ffffff".to_string()); } else { pen_color.set("#ffffff".to_string()); }
                            }
                        }
                    }
                }

                // POPOVER DE ADICIONAR CARDS (FORA DA PILL PARA EVITAR CLIP DO MOSCARO)
                if is_add_card_menu_open() {
                    div {
                        class: "moscaro add-card-popover",
                        onclick: move |e: MouseEvent| e.stop_propagation(),
                        div {
                            class: "add-card-option",
                            onclick: move |_: MouseEvent| add_card_to_active_note("text".to_string()),
                            span { style: "display: inline-flex;", IconNote { card_type: "text".to_string() } }
                            span { "Texto Rico / LaTeX" }
                        }
                        div {
                            class: "add-card-option",
                            onclick: move |_: MouseEvent| add_card_to_active_note("plot".to_string()),
                            span { style: "display: inline-flex;", IconNote { card_type: "plot".to_string() } }
                            span { "Gráfico 2D/3D" }
                        }
                        div {
                            class: "add-card-option",
                            onclick: move |_: MouseEvent| add_card_to_active_note("table".to_string()),
                            span { style: "display: inline-flex;", IconNote { card_type: "table".to_string() } }
                            span { "Tabela de Dados" }
                        }
                        div {
                            class: "add-card-option",
                            onclick: move |_: MouseEvent| add_card_to_active_note("image".to_string()),
                            span { style: "display: inline-flex;", IconNote { card_type: "image".to_string() } }
                            span { "Imagem / Mídia" }
                        }
                        div {
                            class: "add-card-option",
                            onclick: move |_: MouseEvent| add_card_to_active_note("flashcard".to_string()),
                            span { style: "display: inline-flex;", IconNote { card_type: "flashcard".to_string() } }
                            span { "Flashcard 3D" }
                        }
                    }
                }

                // POPOVER DE MODO DE PAPEL E TOOLBAR (EXIBIDOS APENAS EM NOTAS CANVAS OU COMUNS, NÃO EM CONFIGURAÇÕES)
                if !is_settings_active {
                    if is_paper_menu_open() {
                        div { class: "moscaro paper-mode-popover",
                            onclick: move |e: MouseEvent| e.stop_propagation(),
                            div {
                                class: "{get_paper_btn_class(PaperMode::DotGrid)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::DotGrid),
                                title: "Pontilhado (Dot Grid)",
                                "⠶"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::Grid)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::Grid),
                                title: "Quadriculado (Grid)",
                                "▦"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::Lined)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::Lined),
                                title: "Pautado (Linhas)",
                                "≡"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::Isometric)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::Isometric),
                                title: "Isométrico (Linhas 3D)",
                                "⟁"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::Hexagonal)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::Hexagonal),
                                title: "Hexagonal Honeycomb (Moléculas Orgânicas)",
                                "⬢"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::IsometricDots)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::IsometricDots),
                                title: "Pontos Isométricos",
                                "⋮"
                            }
                            div {
                                class: "{get_paper_btn_class(PaperMode::Blank)}",
                                onclick: move |_: MouseEvent| set_paper_mode_for_active_note(PaperMode::Blank),
                                title: "Liso (Branco)",
                                "□"
                            }
                        }
                    }

                    // MAIN TOOLBAR PILL (BOTÕES DENTRO DA PILL MOSCARO, POPOVERS FORA)
                    div { class: "moscaro main-toolbar-pill", style: "display: flex; align-items: center; padding: 6px 12px; gap: 12px;",
                        // BOTÃO EXPANSÍVEL + QUE GIRA AO ABRIR O MENU DE CARDS
                        div {
                            class: if is_add_card_menu_open() { "tb-btn tb-btn-add-card is-open active" } else { "tb-btn tb-btn-add-card" },
                            style: "color: var(--accent-cyan); border: 1px solid rgba(0, 225, 255, 0.45); background: rgba(0, 225, 255, 0.12);",
                            onclick: move |e: MouseEvent| {
                                e.stop_propagation();
                                is_paper_menu_open.set(false);
                                is_add_card_menu_open.toggle();
                            },
                            title: "Adicionar Card (Escolha o tipo e clique no canvas)",
                            IconPlus {}
                        }

                        // BOTÃO DE MODO DE PAPEL EXPANSÍVEL
                        div {
                            class: "{get_tb_btn_class(\"paper\")}",
                            onclick: move |e: MouseEvent| {
                                e.stop_propagation();
                                is_add_card_menu_open.set(false);
                                is_paper_menu_open.toggle();
                            },
                            title: "Escolher Fundo do Canvas",
                            span { style: "font-size: 16px;", "{paper_mode().icon()}" }
                        }

                        // BOTÃO SELEÇÃO / MOVER BLOCOS
                        div {
                            class: "{get_tb_btn_class(\"select\")}",
                            onclick: move |_: MouseEvent| tool_mode.set("select".to_string()),
                            title: "Seleção / Mover",
                            svg { view_box: "0 0 24 24", path { d: "M5 4l6 16 3-7 7-3-16-6z", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linejoin: "round" } }
                        }

                        // BOTÃO CANETA
                        div {
                            class: "{get_tb_btn_class(\"pen\")}",
                            onclick: move |_: MouseEvent| tool_mode.set("pen".to_string()),
                            title: "Caneta Vetorial",
                            svg { view_box: "0 0 24 24", path { d: "M12 19l7-7 3 3-7 7-3-3z", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linejoin: "round" } }
                        }

                        // BOTÃO MARCA TEXTO
                        div {
                            class: "{get_tb_btn_class(\"highlighter\")}",
                            onclick: move |_: MouseEvent| tool_mode.set("highlighter".to_string()),
                            title: "Marca Texto",
                            svg { view_box: "0 0 24 24", path { d: "M18.5 2.5l3 3L8 19l-5 1 1-5L18.5 2.5z", fill: "none", stroke: "currentColor", stroke_width: "2" } }
                        }

                        // BOTÃO BORRACHA
                        div {
                            class: "{get_tb_btn_class(\"eraser\")}",
                            onclick: move |_: MouseEvent| tool_mode.set("eraser".to_string()),
                            title: "Borracha",
                            svg { view_box: "0 0 24 24", path { d: "M2.5 8.5l9 9L21.5 8l-9-9-10 9.5z", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linejoin: "round" } }
                        }

                        // BOTÃO ASSISTENTE DE IA
                        div {
                            class: "tb-btn tb-btn-ai",
                            style: "background: linear-gradient(135deg, rgba(0, 225, 255, 0.22), rgba(168, 85, 247, 0.22)); color: #00e1ff; border: 1px solid rgba(0, 225, 255, 0.45);",
                            onclick: move |e: MouseEvent| {
                                e.stop_propagation();
                                let mut ctx = String::new();
                                let mut sel_card_id = None;
                                if let Some(aid) = active_tab_id() {
                                    if let Some(note) = notes().iter().find(|n| n.id == aid) {
                                        if let Some(scard) = note.cards.iter().find(|c| c.selected) {
                                            ctx = scard.content.clone();
                                            sel_card_id = Some(scard.id);
                                        } else if let Some(fcard) = note.cards.first() {
                                            ctx = fcard.content.clone();
                                        }
                                    }
                                }
                                open_ai_modal_for_context((ctx, sel_card_id));
                            },
                            title: "Abrir Assistente de IA (Resumo, Math to LaTeX, Mermaid, Flashcards)",
                            IconSparkles {}
                        }

                        // BOTÃO PERFIL / CONTA LOCAL
                        button {
                            class: "tb-btn-sync-status",
                            style: "height: 26px; font-size: 11px; padding: 0 10px; color: #a855f7; background: rgba(168, 85, 247, 0.12); border: 1px solid rgba(168, 85, 247, 0.3); border-radius: 9999px; display: flex; align-items: center; gap: 6px; white-space: nowrap; font-family: monospace; font-weight: bold; cursor: pointer;",
                            onclick: move |_| profile_modal_open.set(true),
                            title: "Gerenciar Conta Local e Nome do Dispositivo",
                            IconUser {}
                            span {
                                if let Some(prof) = user_profile() {
                                    "{prof.user_id}"
                                } else {
                                    "Perfil Local"
                                }
                            }
                        }

                        // INDICADOR DE STATUS DA SINCRONIZAÇÃO WI-FI P2P LOCAL
                        button {
                            class: "tb-btn-sync-status",
                            style: "height: 26px; font-size: 11px; padding: 0 10px; color: #00ffaa; background: rgba(0, 255, 170, 0.12); border: 1px solid rgba(0, 255, 170, 0.3); border-radius: 9999px; display: flex; align-items: center; gap: 6px; white-space: nowrap; font-family: monospace; font-weight: bold; cursor: pointer;",
                            onclick: move |_| pairing_modal_open.set(true),
                            title: "Clique para abrir o Modal de Pareamento por PIN (100% P2P Local)",
                            span { style: "font-size: 8px; color: #00ffaa; animation: pulse 1.5s infinite;", "🟢" }
                            span {
                                if peer_count > 0 {
                                    "{peer_count} P2P connected"
                                } else {
                                    "Wi-Fi Sync"
                                }
                            }
                        }
                    }
                }
                

            }

            // 4. MODAL OMNIBAR DE BUSCA RÁPIDA (CTRL + K) ESTILO MOSCARO CLARO
            if omnibar_open() {
                div {
                    class: "omnibar-backdrop",
                    onclick: move |_: MouseEvent| omnibar_open.set(false),
                    div {
                        class: "moscaro omnibar-card",
                        onclick: move |e: MouseEvent| e.stop_propagation(),

                        div { class: "omnibar-header",
                            IconSearch {}
                            input {
                                class: "omnibar-input",
                                placeholder: "Buscar notas, fórmulas, código ou tags... (Esc para fechar)",
                                value: "{search_query}",
                                oninput: move |e: FormEvent| search_query.set(e.value())
                            }
                            span { class: "esc-badge", "ESC" }
                        }

                        div { class: "omnibar-results",
                            if search_results.is_empty() {
                                div { class: "no-results", "Nenhuma nota ou conteúdo encontrado." }
                            } else {
                                for note in search_results {
                                    div {
                                        key: "{note.id}",
                                        class: "omnibar-item",
                                        onclick: move |_: MouseEvent| {
                                            open_note_in_tab(note.id);
                                            omnibar_open.set(false);
                                        },
                                        span { class: "item-icon", "{note.icon}" }
                                        div { class: "item-details",
                                            div { class: "item-title", "{note.title}" }
                                            div { class: "item-subtitle",
                                                "{note.tags.join(\" \")}"
                                            }
                                        }
                                        span { class: "item-badge", "Nota" }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let Some(src_id) = dragged_sidebar_note_id() {
                if let Some(note) = notes().iter().find(|n| n.id == src_id).cloned() {
                    div {
                        class: "sidebar-drag-follower",
                        style: "left: {mouse_x() + 12.0}px; top: {mouse_y() + 12.0}px;",
                        span { class: "note-icon",
                            IconNote { card_type: get_note_card_type_from_icon(&note.icon) }
                        }
                        span { class: "note-title", "{note.title}" }
                    }
                }
            }

            // 5. MODAL ASSISTENTE DE INTELIGÊNCIA ARTIFICIAL (IA)
            AiAssistantModal {
                is_open: ai_modal_open,
                ai_config: ai_config,
                context_text: ai_context_text,
                selected_card_id: ai_selected_card_id,
                active_note_id: active_tab_id,
                notes: notes,
            }

            // 6. MODAL DE PAREAMENTO POR PIN / DISPOSITIVOS LOCAIS
            PairingModal {
                is_open: pairing_modal_open,
                generated_pin: pairing_pin,
                engine: engine.clone(),
                discovery: discovery.clone(),
            }

            // 7. MODAL DE CRIAÇÃO E GERENCIAMENTO DE CONTA E PERFIL LOCAL
            ProfileModal {
                is_open: profile_modal_open,
                user_profile: user_profile,
            }
        }
    }
}
