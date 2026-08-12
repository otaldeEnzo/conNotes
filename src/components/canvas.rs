use crate::types::*;
use dioxus::prelude::*;

pub fn render_text_card(card: &NoteCard) -> Element {
    let mut is_editing = use_signal(|| false);
    let mut content = use_signal(|| card.content.clone());

    rsx! {
        div { class: "card-content-text", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px;",
            div { class: "card-header", style: "display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255, 255, 255, 0.1); padding-bottom: 6px;",
                span { style: "font-weight: 600; font-size: 13px; color: var(--text-primary, #fff);", "{card.title}" }
                button {
                    style: "background: transparent; border: none; color: var(--accent-emerald, #10b981); font-size: 12px; cursor: pointer;",
                    onclick: move |_| is_editing.toggle(),
                    if is_editing() { "Done" } else { "Edit" }
                }
            }
            if is_editing() {
                textarea {
                    style: "width: 100%; min-height: 100px; background: rgba(0, 0, 0, 0.2); color: #fff; border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 6px; padding: 8px; font-family: inherit; resize: vertical;",
                    value: "{content}",
                    oninput: move |e: FormEvent| content.set(e.value())
                }
            } else {
                div {
                    style: "font-size: 14px; color: #ffffff; line-height: 1.5; white-space: pre-wrap;",
                    "{content}"
                }
            }
        }
    }
}

pub fn render_math_card(card: &NoteCard) -> Element {
    let mut formula = use_signal(|| card.content.clone());

    let mut insert_symbol = move |sym: &'static str| {
        formula.with_mut(|f| f.push_str(sym));
    };

    rsx! {
        div { class: "card-content-math", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px;",
            div { class: "math-omnibar", style: "display: flex; gap: 4px; background: rgba(255, 255, 255, 0.05); padding: 4px; border-radius: 6px;",
                button { style: "background: rgba(255,255,255,0.1); border: none; color: #00e1ff; border-radius: 4px; padding: 2px 8px; cursor: pointer;", onclick: move |_| insert_symbol("∫"), "∫" }
                button { style: "background: rgba(255,255,255,0.1); border: none; color: #00e1ff; border-radius: 4px; padding: 2px 8px; cursor: pointer;", onclick: move |_| insert_symbol("∑"), "∑" }
                button { style: "background: rgba(255,255,255,0.1); border: none; color: #00e1ff; border-radius: 4px; padding: 2px 8px; cursor: pointer;", onclick: move |_| insert_symbol("√"), "√" }
                button { style: "background: rgba(255,255,255,0.1); border: none; color: #00e1ff; border-radius: 4px; padding: 2px 8px; cursor: pointer;", onclick: move |_| insert_symbol("π"), "π" }
                button { style: "background: rgba(255,255,255,0.1); border: none; color: #00e1ff; border-radius: 4px; padding: 2px 8px; cursor: pointer;", onclick: move |_| insert_symbol("θ"), "θ" }
            }
            input {
                style: "width: 100%; background: rgba(0, 0, 0, 0.3); border: 1px solid rgba(0, 225, 255, 0.3); border-radius: 6px; padding: 6px 10px; color: #00e1ff; font-family: monospace;",
                value: "{formula}",
                oninput: move |e: FormEvent| formula.set(e.value())
            }
            div { style: "font-family: serif; font-size: 18px; color: #ffffff; line-height: 1.8; padding: 6px; background: rgba(0,0,0,0.15); border-radius: 6px; text-align: center;",
                "{formula}"
            }
            div { style: "font-size: 11px; color: var(--accent-cyan, #00e1ff); margin-top: 4px;",
                "⚛️ {card.title}"
            }
        }
    }
}

pub fn render_plot_card(card: &NoteCard) -> Element {
    let mut func_type = use_signal(|| "sin".to_string());

    let path_d = match func_type().as_str() {
        "cos" => "M 0 40 Q 85 180 170 40 T 340 40",
        "x^2" => "M 70 20 Q 170 200 270 20",
        _ => "M 0 110 Q 85 20 170 110 T 340 110", // sin(x)
    };

    rsx! {
        div { class: "card-content-plot", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 6px;",
            div { style: "display: flex; justify-content: space-between; align-items: center;",
                div { style: "font-family: serif; font-size: 16px; color: var(--accent-emerald, #10b981);", "{card.title}" }
                select {
                    
                    value: "{func_type}",
                    onchange: move |e: Event<FormData>| func_type.set(e.value()),
                    option { value: "sin", "sin(x)" }
                    option { value: "cos", "cos(x)" }
                    option { value: "x^2", "x²" }
                }
            }
            svg {
                width: "100%",
                height: "200",
                view_box: "0 0 340 220",
                style: "background: rgba(6, 10, 18, 0.75); border-radius: 12px;",
                // Eixo X e Y
                path { d: "M 0 110 L 340 110", stroke: "rgba(168, 85, 247, 0.4)", stroke_width: "1" }
                path { d: "M 170 0 L 170 220", stroke: "rgba(168, 85, 247, 0.4)", stroke_width: "1" }
                // Ticks Eixo X
                line { x1: "85", y1: "105", x2: "85", y2: "115", stroke: "rgba(255,255,255,0.4)", stroke_width: "1" }
                line { x1: "255", y1: "105", x2: "255", y2: "115", stroke: "rgba(255,255,255,0.4)", stroke_width: "1" }
                // Ticks Eixo Y
                line { x1: "165", y1: "55", x2: "175", y2: "55", stroke: "rgba(255,255,255,0.4)", stroke_width: "1" }
                line { x1: "165", y1: "165", x2: "175", y2: "165", stroke: "rgba(255,255,255,0.4)", stroke_width: "1" }
                // Curva do gráfico
                path {
                    d: "{path_d}",
                    fill: "none",
                    stroke: "#00e1ff",
                    stroke_width: "3"
                }
            }
        }
    }
}

pub fn render_code_card(card: &NoteCard) -> Element {
    let mut code = use_signal(|| card.content.clone());
    let mut copied = use_signal(|| false);

    let copy_to_clipboard = move |_| {
        copied.set(true);
        // Reset feedback após 2s se necessário
    };

    rsx! {
        div { class: "card-content-code", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 6px;",
            div { style: "display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 4px;",
                span { style: "font-family: monospace; font-size: 12px; color: var(--accent-purple, #a855f7);", "{card.title}" }
                button {
                    onclick: copy_to_clipboard,
                    if copied() { "Copiado!" } else { "Copiar" }
                }
            }
            textarea {
                style: "width: 100%; min-height: 120px; background: rgba(10, 10, 16, 0.8); color: #a855f7; font-family: monospace; font-size: 13px; border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 6px; padding: 8px; resize: vertical;",
                value: "{code}",
                oninput: move |e: FormEvent| code.set(e.value())
            }
        }
    }
}

pub fn render_table_card(card: &NoteCard) -> Element {
    let mut rows = use_signal(|| vec![
        vec!["Item".to_string(), "Valor".to_string(), "Status".to_string()],
        vec!["Projeto A".to_string(), "100".to_string(), "Concluído".to_string()],
        vec!["Projeto B".to_string(), "250".to_string(), "Em andamento".to_string()],
    ]);

    let add_row = move |_| {
        rows.with_mut(|r| {
            let col_count = if let Some(first) = r.first() { first.len() } else { 1 };
            r.push(vec!["-".to_string(); col_count]);
        });
    };

    let add_col = move |_| {
        rows.with_mut(|r| {
            for row in r.iter_mut() {
                row.push("-".to_string());
            }
        });
    };

    rsx! {
        div { class: "card-content-table", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px;",
            div { style: "display: flex; justify-content: space-between; align-items: center;",
                span { style: "font-weight: 600; font-size: 13px; color: #fff;", "{card.title}" }
                div { style: "display: flex; gap: 4px;",
                    button { style: "background: rgba(255,255,255,0.1); border: none; color: #fff; border-radius: 4px; padding: 2px 6px; font-size: 11px; cursor: pointer;", onclick: add_row, "+ Linha" }
                    button { style: "background: rgba(255,255,255,0.1); border: none; color: #fff; border-radius: 4px; padding: 2px 6px; font-size: 11px; cursor: pointer;", onclick: add_col, "+ Coluna" }
                }
            }
            div { style: "overflow-x: auto;",
                table { style: "width: 100%; border-collapse: collapse; font-size: 12px; color: #fff;",
                    tbody {
                        for (r_idx, row) in rows().iter().enumerate() {
                            tr { key: "{r_idx}", style: "border-bottom: 1px solid rgba(255,255,255,0.1);",
                                for (c_idx, cell) in row.iter().enumerate() {
                                    td { key: "{c_idx}", style: "padding: 6px; border-right: 1px solid rgba(255,255,255,0.05);",
                                        input {
                                            style: "background: transparent; border: none; color: #fff; width: 100%; font-size: 12px;",
                                            value: "{cell}",
                                            oninput: move |e: FormEvent| {
                                                let val = e.value();
                                                rows.with_mut(|r| {
                                                    if let Some(r_row) = r.get_mut(r_idx) {
                                                        if let Some(r_cell) = r_row.get_mut(c_idx) {
                                                            *r_cell = val;
                                                        }
                                                    }
                                                });
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
    }
}

pub fn render_flashcard(card: &NoteCard) -> Element {
    let mut is_flipped = use_signal(|| false);

    rsx! {
        div { class: "card-content-flashcard", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px; perspective: 1000px;",
            div { style: "display: flex; justify-content: space-between; align-items: center;",
                span { style: "font-weight: 600; font-size: 13px; color: var(--accent-cyan, #00e1ff);", "{card.title}" }
                button {
                    onclick: move |_| is_flipped.toggle(),
                    "Virar Card 🔄"
                }
            }
            div {
                style: format!(
                    "width: 100%; min-height: 120px; border-radius: 8px; padding: 12px; display: flex; align-items: center; justify-content: center; text-align: center; transition: transform 0.6s; transform-style: preserve-3d; background: {}; border: 1px solid rgba(255,255,255,0.15);",
                    if is_flipped() { "rgba(16, 185, 129, 0.15)" } else { "rgba(0, 225, 255, 0.15)" }
                ),
                if is_flipped() {
                    div { style: "color: #10b981; font-weight: 500; font-size: 15px;",
                        "Verso: {card.content}"
                    }
                } else {
                    div { style: "color: #00e1ff; font-weight: 500; font-size: 15px;",
                        "Frente: Pergunta / Conceito Principal"
                    }
                }
            }
        }
    }
}

pub fn render_image_card(card: &NoteCard) -> Element {
    let img_src = if card.content.starts_with("http") || card.content.starts_with("data:") {
        card.content.clone()
    } else {
        "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&auto=format&fit=crop".to_string()
    };

    rsx! {
        div { class: "card-content-image", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 6px; position: relative;",
            div { style: "font-weight: 600; font-size: 12px; color: #fff;", "{card.title}" }
            div { style: "width: 100%; height: 100%; overflow: hidden; border-radius: 6px; border: 1px solid rgba(255,255,255,0.1); position: relative;",
                img {
                    src: "{img_src}",
                    style: "width: 100%; height: 100%; object-fit: cover;"
                }
                div {
                    style: "position: absolute; bottom: 4px; right: 4px; width: 12px; height: 12px; background: rgba(255,255,255,0.5); cursor: se-resize; border-radius: 2px;",
                    title: "Redimensionar"
                }
            }
        }
    }
}

pub fn render_embed_card(card: &NoteCard) -> Element {
    let url = if card.content.starts_with("http") {
        card.content.clone()
    } else {
        "https://www.youtube.com/embed/dQw4w9WgXcQ".to_string()
    };

    rsx! {
        div { class: "card-content-embed", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 6px;",
            div { style: "font-weight: 600; font-size: 12px; color: #fff;", "{card.title}" }
            iframe {
                src: "{url}",
                style: "width: 100%; min-height: 180px; border: none; border-radius: 6px; background: #000;"
            }
        }
    }
}

pub fn render_sketch_card(card: &NoteCard) -> Element {
    rsx! {
        div { class: "card-content-sketch", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 6px;",
            div { style: "display: flex; justify-content: space-between; align-items: center;",
                span { style: "font-weight: 600; font-size: 12px; color: #fff;", "{card.title}" }
                span { style: "font-size: 11px; color: rgba(255,255,255,0.5);", "Mini Canvas" }
            }
            svg {
                width: "100%",
                height: "160",
                style: "background: rgba(0,0,0,0.3); border-radius: 6px; border: 1px dashed rgba(255,255,255,0.2);",
                path {
                    d: "M 20 80 Q 80 20 140 80 T 260 80",
                    fill: "none",
                    stroke: "#22c55e",
                    stroke_width: "2"
                }
            }
        }
    }
}

pub fn render_canvas_card(card: &NoteCard) -> Element {
    match card.card_type.as_str() {
        "math" => render_math_card(card),
        "plot" => render_plot_card(card),
        "code" => render_code_card(card),
        "table" => render_table_card(card),
        "flashcard" => render_flashcard(card),
        "image" => render_image_card(card),
        "embed" => render_embed_card(card),
        "sketch" => render_sketch_card(card),
        _ => render_text_card(card),
    }
}
