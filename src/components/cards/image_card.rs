use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;

fn simple_base64_encode(data: &[u8]) -> String {
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    let mut i = 0;
    while i < data.len() {
        let b0 = data[i];
        let b1 = if i + 1 < data.len() { data[i + 1] } else { 0 };
        let b2 = if i + 2 < data.len() { data[i + 2] } else { 0 };
        
        let c0 = (b0 >> 2) & 0x3F;
        let c1 = ((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F);
        let c2 = ((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03);
        let c3 = b2 & 0x3F;

        out.push(CHARSET[c0 as usize] as char);
        out.push(CHARSET[c1 as usize] as char);
        if i + 1 < data.len() {
            out.push(CHARSET[c2 as usize] as char);
        } else {
            out.push('=');
        }
        if i + 2 < data.len() {
            out.push(CHARSET[c3 as usize] as char);
        } else {
            out.push('=');
        }
        i += 3;
    }
    out
}

#[component]
pub fn ImageCard(
    card: NoteCard,
    on_update_content: EventHandler<String>,
) -> Element {
    let mut url_input = use_signal(|| card.content.clone());

    let handle_file_change = move |e: Event<FormData>| {
        if let Some(file_engine) = e.files() {
            let files = file_engine.files();
            if let Some(file_name) = files.first() {
                let file_name_cloned = file_name.clone();
                let on_update = on_update_content.clone();
                let file_engine_cloned = file_engine.clone();
                spawn(async move {
                    if let Some(bytes) = file_engine_cloned.read_file(&file_name_cloned).await {
                        let mime = if file_name_cloned.ends_with(".png") {
                            "image/png"
                        } else if file_name_cloned.ends_with(".gif") {
                            "image/gif"
                        } else if file_name_cloned.ends_with(".webp") {
                            "image/webp"
                        } else if file_name_cloned.ends_with(".svg") {
                            "image/svg+xml"
                        } else {
                            "image/jpeg"
                        };
                        let b64 = simple_base64_encode(&bytes);
                        let data_uri = format!("data:{};base64,{}", mime, b64);
                        url_input.set(data_uri.clone());
                        on_update.call(data_uri);
                    }
                });
            }
        }
    };

    let handle_paste = move |_e: ClipboardEvent| {};

    let image_present = !url_input().is_empty();

    rsx! {
        div {
            class: "card-content-image",
            style: "width: 100%; height: 100%; display: flex; flex-direction: column; position: relative;",
            onpaste: handle_paste,

            if !image_present {
                div {
                    style: "display: flex; flex-direction: column; gap: 8px; width: 100%; height: 100%; flex: 1; align-items: center; justify-content: center; padding: 12px; border: 1px dashed var(--accent-cyan); border-radius: 8px; background: var(--glass-bg); box-sizing: border-box;",
                    IconNote { card_type: "image".to_string() }
                    span { style: "font-size: 12px; color: rgba(255,255,255,0.7); text-align: center;", "Cole a URL da imagem ou escolha um arquivo" }

                    input {
                        style: "width: 100%; background: rgba(0, 0, 0, 0.3); border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 6px; color: #fff; padding: 4px 8px; font-size: 12px; outline: none;",
                        placeholder: "Cole a URL ou pressione Ctrl+V...",
                        value: "{url_input}",
                        oninput: move |e: FormEvent| {
                            let val = e.value();
                            url_input.set(val.clone());
                            on_update_content.call(val);
                        },
                        onpaste: handle_paste
                    }

                    label {
                        style: "display: inline-flex; align-items: center; gap: 6px; background: var(--glass-bg); border: 1px solid var(--accent-cyan); color: var(--accent-cyan, #00e1ff); padding: 4px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.2s ease;",
                        input {
                            r#type: "file",
                            accept: "image/*",
                            style: "display: none;",
                            onchange: handle_file_change,
                        }
                        IconFolder { expanded: false }
                        " Escolher Imagem"
                    }
                }
            } else {
                div {
                    style: "width: 100%; height: 100%; border-radius: 8px; overflow: hidden; border: 1px solid rgba(255, 255, 255, 0.15); background: rgba(0, 0, 0, 0.3); display: flex; align-items: center; justify-content: center; position: relative;",
                    img {
                        src: "{url_input}",
                        style: "max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 6px;"
                    }
                    button {
                        style: "position: absolute; top: 6px; right: 6px; background: var(--glass-bg); border: 1px solid var(--accent-cyan); color: #fff; border-radius: 4px; padding: 2px 6px; font-size: 10px; cursor: pointer; backdrop-filter: blur(4px); display: flex; align-items: center; gap: 4px;",
                        title: "Trocar Imagem",
                        onclick: move |_| {
                            url_input.set(String::new());
                            on_update_content.call(String::new());
                        },
                        IconBrush {}
                        " Trocar"
                    }
                }
            }
        }
    }
}



