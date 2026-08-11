use crate::components::cards::flashcard::Flashcard;
use crate::components::cards::image_card::ImageCard;
use crate::components::cards::plot_card::PlotCard;
use crate::components::cards::table_card::TableCard;
use crate::components::cards::text_card::TextCard;
use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;

#[component]
pub fn CardContainer(
    card: NoteCard,
    card_class: String,
    is_editing_title: bool,
    on_start_edit_title: EventHandler<()>,
    on_finish_edit_title: EventHandler<()>,
    on_update_title: EventHandler<String>,
    on_update_content: EventHandler<String>,
    #[props(default)] on_card_update: EventHandler<NoteCard>,
    #[props(default)] on_start_resize: EventHandler<(usize, String, f64, f64, f64, f64)>,
    #[props(default)] on_ai_click: EventHandler<String>,
) -> Element {
    let type_icon = rsx! { IconNote { card_type: card.card_type.clone() } };

    let body_elem = if !card.collapsed {
        let card_c = card.clone();
        match card.card_type.as_str() {
            "plot" | "plot3d" => rsx! { PlotCard { card: card_c, on_update_content: move |c| on_update_content.call(c), on_update_title: move |t| on_update_title.call(t), on_ai_click: move |c| on_ai_click.call(c) } },
            "table" => rsx! { TableCard { card: card_c } },
            "image" => rsx! { ImageCard { card: card_c, on_update_content: move |c| on_update_content.call(c) } },
            "flashcard" => rsx! { Flashcard { card: card_c } },
            _ => rsx! { TextCard { card: card_c, on_update_content: move |c| on_update_content.call(c), on_ai_click: move |c| on_ai_click.call(c) } },
        }
    } else {
        rsx! { div {} }
    };

    let card_for_down = card.clone();
    let card_for_lock = card.clone();
    let card_for_collapse = card.clone();
    let card_for_resize = card.clone();

    let height_style = if card.collapsed {
        "height: auto;".to_string()
    } else {
        format!("height: {}px;", card.height)
    };
    let accent_style = card.accent_color.as_ref().map(|c| format!("box-shadow: 0 0 12px {}; border-color: {};", c, c)).unwrap_or_default();
    let container_style = format!("top: {}px; left: {}px; width: {}px; {}; display: flex; flex-direction: column; box-sizing: border-box; cursor: grab; {}", card.y, card.x, card.width, height_style, accent_style);

    rsx! {
        div {
            key: "{card.id}",
            class: "{card_class}",
            style: "{container_style}",
            onmousedown: move |e| {
                let _ = document::eval("if (document.activeElement && document.activeElement.tagName !== 'BODY') document.activeElement.blur();");
                if card_for_down.locked {
                    e.stop_propagation();
                }
            },

            div { class: "card-connector-handle handle-top" }
            div { class: "card-connector-handle handle-bottom" }
            div { class: "card-connector-handle handle-left" }
            div { class: "card-connector-handle handle-right" }

            // CABEÇALHO DO CARD COM NÚMERO BADGE E TÍTULO EDITÁVEL COM DUPLO CLIQUE
            div { class: "card-header",
                div { class: "card-title-wrapper",
                    span { class: "card-type-icon", {type_icon} }
                    if is_editing_title {
                        input {
                            class: "card-title-input",
                            value: "{card.title}",
                            autofocus: true,
                            onmousedown: move |e| e.stop_propagation(),
                            ondoubleclick: move |e| {
                                e.stop_propagation();
                                let _ = document::eval("if (document.activeElement && document.activeElement.select) document.activeElement.select();");
                            },
                            oninput: move |e| on_update_title.call(e.value()),
                            onkeydown: move |e| {
                                if e.key() == Key::Enter || e.key() == Key::Escape {
                                    on_finish_edit_title.call(());
                                }
                            },
                            onblur: move |_| on_finish_edit_title.call(())
                        }
                    } else {
                        span {
                            class: "card-title-text",
                            title: "Clique duas vezes para renomear este card",
                            ondoubleclick: move |e| {
                                e.stop_propagation();
                                on_start_edit_title.call(());
                            },
                            "{card.title}"
                        }
                    }
                }
                span { class: "card-badge-number", "#{card.number}" }

                div { class: "card-header-controls",
                    span {
                        class: "card-control-btn ai-sparkle-btn",
                        title: "Abrir Assistente de IA para este Card",
                        onclick: move |e| {
                            e.stop_propagation();
                            on_ai_click.call(card.content.clone());
                        },
                        IconSparkles {}
                    }
                    span {
                        class: "card-control-btn",
                        title: if card.locked { "Desbloquear Posição" } else { "Bloquear Posição" },
                        onclick: move |e| {
                            e.stop_propagation();
                            let mut card_c = card_for_lock.clone();
                            card_c.locked = !card_c.locked;
                            on_card_update.call(card_c);
                        },
                        if card.locked { IconLock {} } else { IconUnlock {} }
                    }
                    span {
                        class: "card-control-btn",
                        title: if card.collapsed { "Expandir" } else { "Recolher" },
                        onclick: move |e| {
                            e.stop_propagation();
                            let mut card_c = card_for_collapse.clone();
                            card_c.collapsed = !card_c.collapsed;
                            on_card_update.call(card_c);
                        },
                        if card.collapsed { IconChevronDown {} } else { IconChevronUp {} }
                    }
                }
            }

            // SELEÇÃO MODULAR DO COMPONENTE DO CORPO DO CARD
            div {
                style: "flex: 1; width: 100%; height: 100%; min-height: 0; display: flex; flex-direction: column;",
                {body_elem}
            }

            if !card.collapsed && !card.locked && card.selected {
                div {
                    class: "resize-handle resize-se",
                    style: "position: absolute; right: 0; bottom: 0; width: 12px; height: 12px; cursor: se-resize; z-index: 10;",
                    onmousedown: move |e| {
                        e.stop_propagation();
                        on_start_resize.call((card_for_resize.id, "se".to_string(), card_for_resize.width, card_for_resize.height, card_for_resize.x, card_for_resize.y));
                    }
                }
                div {
                    class: "resize-handle resize-e",
                    style: "position: absolute; right: 0; top: 0; bottom: 12px; width: 6px; cursor: e-resize; z-index: 10;",
                    onmousedown: move |e| {
                        e.stop_propagation();
                        on_start_resize.call((card_for_resize.id, "e".to_string(), card_for_resize.width, card_for_resize.height, card_for_resize.x, card_for_resize.y));
                    }
                }
                div {
                    class: "resize-handle resize-s",
                    style: "position: absolute; left: 0; right: 12px; bottom: 0; height: 6px; cursor: s-resize; z-index: 10;",
                    onmousedown: move |e| {
                        e.stop_propagation();
                        on_start_resize.call((card_for_resize.id, "s".to_string(), card_for_resize.width, card_for_resize.height, card_for_resize.x, card_for_resize.y));
                    }
                }
                div {
                    class: "resize-handle resize-sw",
                    style: "position: absolute; left: 0; bottom: 0; width: 12px; height: 12px; cursor: sw-resize; z-index: 10;",
                    onmousedown: move |e| {
                        e.stop_propagation();
                        on_start_resize.call((card_for_resize.id, "sw".to_string(), card_for_resize.width, card_for_resize.height, card_for_resize.x, card_for_resize.y));
                    }
                }
            }
        }
    }
}
